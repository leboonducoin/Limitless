import Foundation
import Testing

@testable import LimitlessSystem

@Test func updateResponsesDistinguishMissingReleasesRateLimitsAndServerFailures() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    func response(_ status: Int, headers: [String: String] = [:]) throws -> HTTPURLResponse {
        try #require(
            HTTPURLResponse(
                url: URL(
                    string: "https://api.github.com/repos/leboonducoin/Limitless/releases/latest")!,
                statusCode: status, httpVersion: "HTTP/2", headerFields: headers))
    }
    #expect(try GitHubUpdate.validateResponse(response(200), limit: 100))
    #expect(try !GitHubUpdate.validateResponse(response(404), limit: 100, allowsMissing: true))
    #expect(throws: UpdateError.httpStatus(404)) {
        try GitHubUpdate.validateResponse(response(404), limit: 100)
    }
    for status in [403, 500, 503] {
        #expect(throws: UpdateError.httpStatus(status)) {
            try GitHubUpdate.validateResponse(response(status), limit: 100)
        }
    }
    #expect(throws: UpdateError.rateLimited(until: now.addingTimeInterval(600))) {
        try GitHubUpdate.validateResponse(
            response(
                403, headers: ["X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "1700000600"]),
            limit: 100, now: now)
    }
    #expect(throws: UpdateError.rateLimited(until: now.addingTimeInterval(120))) {
        try GitHubUpdate.validateResponse(
            response(429, headers: ["Retry-After": "120"]), limit: 100, now: now)
    }
    for invalid in ["NaN", "1e300", "-60", "unreadable"] {
        #expect(
            throws: UpdateError.rateLimited(until: now.addingTimeInterval(UpdateSchedule.interval))
        ) {
            try GitHubUpdate.validateResponse(
                response(429, headers: ["Retry-After": invalid]), limit: 100, now: now)
        }
    }
    #expect(throws: UpdateError.rateLimited(until: now.addingTimeInterval(172_800))) {
        try GitHubUpdate.validateResponse(
            response(429, headers: ["Retry-After": "172800"]), limit: 100, now: now)
    }
    #expect(throws: UpdateError.rateLimited(until: now.addingTimeInterval(600))) {
        try GitHubUpdate.validateResponse(
            response(429, headers: ["Retry-After": "Tue, 14 Nov 2023 22:23:20 GMT"]), limit: 100,
            now: now)
    }
    #expect(throws: UpdateError.invalidRelease) {
        try GitHubUpdate.validateResponse(
            response(200, headers: ["Content-Length": "101"]), limit: 100)
    }
}

@Test func updateRequestsStaySpacedAcrossRestartsAndRepeatedFailures() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let interval = UpdateSchedule.interval
    #expect(interval == 28_800)
    var schedule = UpdateSchedule()
    func check(_ date: Date) -> Bool { schedule.beginCheck(at: date) }
    func download(_ date: Date) -> Bool { schedule.beginDownload(at: date) }
    #expect(check(now))
    #expect(download(now))
    schedule = try JSONDecoder().decode(UpdateSchedule.self, from: JSONEncoder().encode(schedule))
    #expect(!check(now.addingTimeInterval(interval - 1)))
    #expect(!download(now.addingTimeInterval(interval - 1)))
    #expect(!check(now.addingTimeInterval(-interval)))
    schedule.failed(download: false, at: now)
    schedule.failed(download: true, at: now)
    #expect(check(now.addingTimeInterval(interval)))
    #expect(download(now.addingTimeInterval(interval)))
    schedule.failed(download: false, at: now.addingTimeInterval(interval))
    schedule.failed(download: true, at: now.addingTimeInterval(interval))
    #expect(schedule.nextCheck == now.addingTimeInterval(3 * interval))
    #expect(schedule.nextDownload == now.addingTimeInterval(3 * interval))
    let reset = now.addingTimeInterval(10 * interval)
    schedule.failed(download: false, retryAfter: reset, at: now)
    schedule.checked()
    #expect(!check(reset.addingTimeInterval(-1)))
    #expect(!download(reset.addingTimeInterval(-1)))
    #expect(check(reset))
    #expect(download(reset))
}

private func releaseData(
    tag: String = "v0.2.0", digest: String? = "sha256:" + String(repeating: "a", count: 64),
    url: String? = nil, size: Int = 100, prerelease: Bool = false
) throws -> Data {
    var asset: [String: Any] = [
        "name": "Limitless-0.2.0-universal.zip", "size": size,
        "browser_download_url": url
            ?? "https://github.com/leboonducoin/Limitless/releases/download/v0.2.0/Limitless-0.2.0-universal.zip",
    ]
    if let digest { asset["digest"] = digest }
    return try JSONSerialization.data(withJSONObject: [
        "tag_name": tag, "draft": false, "prerelease": prerelease, "assets": [asset],
    ])
}

@Test func updatesRequireANewerStableReleaseFromTheExactRepositoryWithADigest() throws {
    let data = try releaseData()
    #expect(try GitHubUpdate.release(from: data, currentVersion: "0.1.0")?.version == "0.2.0")
    #expect(try GitHubUpdate.release(from: data, currentVersion: "0.2.0") == nil)
    #expect(try GitHubUpdate.release(from: data, currentVersion: "0.10.0") == nil)
    #expect(
        try GitHubUpdate.release(from: releaseData(prerelease: true), currentVersion: "0.1.0")
            == nil)
    for invalid in [
        try releaseData(digest: nil), try releaseData(digest: "sha256:wrong"),
        try releaseData(url: "https://github.com/other/Limitless/update.zip"),
        try releaseData(size: GitHubUpdate.maximumArchiveSize + 1),
        try releaseData(size: -1), try releaseData(tag: "v0.2.0-beta"),
    ] {
        #expect(throws: UpdateError.invalidRelease) {
            try GitHubUpdate.release(from: invalid, currentVersion: "0.1.0")
        }
    }
    for value in ["", "1.2", "1.2.3.4", "01.2.3", "-1.2.3", "1.2.9999999999999"] {
        #expect(throws: UpdateError.invalidRelease) { try GitHubUpdate.version(value) }
    }
}

@Test func updateArchiveListingRejectsEscapesLinksOversizeAndAmbiguousEntries() throws {
    let valid = """
        drwxr-xr-x 0 501 0 0 Sep 19 18:42 Limitless.app/
        -rw-r--r-- 0 501 0 12 Sep 19 18:42 Limitless.app/Contents/Info.plist
        -rwxr-xr-x 0 501 0 20 Sep 19 18:42 Limitless.app/Contents/MacOS/LimitlessApp
        """
    try GitHubUpdate.validateListing(valid)
    for entry in [
        "-rw-r--r-- 0 501 0 1 Sep 19 18:42 /tmp/outside",
        "-rw-r--r-- 0 501 0 1 Sep 19 18:42 Limitless.app/../outside",
        "lrwxr-xr-x 0 501 0 1 Sep 19 18:42 Limitless.app/link",
        "-rwsr-xr-x 0 501 0 1 Sep 19 18:42 Limitless.app/root",
        "-rw-r--r-- 0 501 0 999999999999 Sep 19 18:42 Limitless.app/huge",
        "-rw-r--r-- 0 501 0 1 Sep 19 18:42 Limitless.app/Contents/Info.plist",
        "-rw-r--r-- 0 501 0 1 Sep 19 18:42 Limitless.app/name with spaces",
    ] {
        #expect(throws: UpdateError.invalidArchive) {
            try GitHubUpdate.validateListing(valid + "\n" + entry)
        }
    }
}

@Test func nativeArchiveExtractionPreservesBundleLayoutAndRefusesSymlinks() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
        "Limitless-update-test-\(UUID().uuidString)")
    let source = root.appendingPathComponent("Limitless.app")
    let destination = root.appendingPathComponent("extract")
    try FileManager.default.createDirectory(
        at: source.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    try Data("plist".utf8).write(to: source.appendingPathComponent("Contents/Info.plist"))
    try Data("executable".utf8).write(
        to: source.appendingPathComponent("Contents/MacOS/LimitlessApp"))
    func archive(_ name: String) throws -> URL {
        let zip = root.appendingPathComponent(name)
        let command = Process()
        command.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        command.arguments = ["-c", "-k", "--keepParent", source.path, zip.path]
        try command.run()
        command.waitUntilExit()
        #expect(command.terminationStatus == 0)
        return zip
    }
    try await GitHubUpdate.extract(archive("good.zip"), to: destination)
    #expect(
        try Data(
            contentsOf: destination.appendingPathComponent(
                "Limitless.app/Contents/MacOS/LimitlessApp")) == Data("executable".utf8))
    try GitHubUpdate.quarantine(
        destination.appendingPathComponent("Limitless.app"), downloadedFrom: GitHubUpdate.repository
    )
    #expect(
        try destination.appendingPathComponent("Limitless.app").resourceValues(forKeys: [
            .quarantinePropertiesKey
        ]).allValues[.quarantinePropertiesKey] != nil)
    try FileManager.default.createSymbolicLink(
        at: source.appendingPathComponent("escape"), withDestinationURL: root)
    await #expect(throws: UpdateError.invalidArchive) {
        try await GitHubUpdate.extract(archive("bad.zip"), to: destination)
    }
}
