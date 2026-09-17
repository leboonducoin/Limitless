# Agent instructions — Limitless

## Product and scope

Limitless is a public, MIT-licensed native macOS menu-bar utility by Arthur Barreau.
It manages explicit keep-awake sessions, including lid-closed operation where macOS
and the hardware permit it. Read `docs/requirements.md` and the relevant canonical
document before changing behavior. Preserve the full requested scope and distinguish
implemented, automatically tested, physically verified, and publication-ready work.

The user requires a working GitHub/Homebrew distribution without paid Apple
Developer membership. Developer ID/notarization is an optional later channel.
Read the no-account decision in `docs/distribution.md` before changing trust or
installation. Preserve native admin consent and reciprocal XPC authentication;
never replace certificate validation with a bundle ID/UID-only check.

## Mandatory terminal discipline

- Prefix **every terminal command** with `rtk`. Use `rtk proxy <command>` when RTK
  has no dedicated wrapper or when exact output matters. Consult the user's global
  RTK instructions when available. If RTK is unavailable, report it explicitly.
- Start with `rtk git status`; preserve existing edits and untracked files.
- Search with `rtk proxy rg` before opening targeted sections. Avoid broad dumps.
- Never print secrets, signing keys, credentials, environment files, or private data.
- Never import code, assets, secrets, or application data from another project.

## Architecture and security boundaries

- All authored executable code is Swift: app, CLI, helper, adapters, build and
  maintenance tools. Markdown, assets, plist/JSON/YAML and Homebrew DSL are allowed.
- No Node/Python runtime in the delivered product. Prefer Apple frameworks and the
  standard library. Add dependencies only for a demonstrated need.
- Keep policy and session decisions in the common core; do not duplicate them in UI
  or CLI. Model mutually exclusive states with enums. Use Swift 6 concurrency checks.
- Use public Apple APIs. Isolate undocumented `pmset disablesleep` behavior in its
  backend. Treat it as global, never as independent battery/AC settings.
- The privileged helper must authenticate clients, validate every request, enforce
  user limits, and accept no arbitrary executable, command line, or filesystem path.
- Run user commands without elevation. No shell interpolation in privileged work,
  no stored administrator password, no passwordless sudoers grant.
- Distinguish desired state, observed state, errors, and physical compatibility.
  Missing telemetry is not a successful observation. Never report an unverified stop.
- Restore only state owned by Limitless. Stop, expiry, battery protection, and loss
  of ownership outrank recovery. Bound retries. Never resurrect sessions at login
  or reboot. Document residual risks of a global, undocumented setting.
- Do not change system power settings, install a helper, change login items, or
  exercise privileged integration without explicit authorization for that test.
- Never bypass Gatekeeper, SIP, TCC, notarization, or an installation security block.

## Mandatory installed skill routing

Discover installed skills by name and read their `SKILL.md` before first use. Use
the user's global installation; do not vendor skills into this repository.

- `ponytail` in **full** mode for implementation and architecture. Understand the
  complete call flow first; prefer deletion, reuse, standard library and native APIs.
- `ponytail-review` for complexity review at each substantive checkpoint. It does
  not replace correctness, security, or accessibility review.
- `write-swift` for Swift implementation, concurrency, testing and review. Verify
  availability against the actual compiler/SDK; do not assume future APIs exist.
- `graphify` for mapping and impact analysis once there are multiple Swift modules.
  If `graphify-out/graph.json` exists, use scoped query/path/explain before broad
  exploration. Keep structural data current after code changes. Prefer local
  code-only extraction; do not transmit private material or require an LLM key.
- `emil-design-eng`, `apple-design`, and `ui-ux-pro-max` for UI and motion work.
  Native macOS conventions and accessibility take precedence over web/mobile
  examples. Do not import Expo, React Native, CSS or JavaScript dependencies.
- `review-animations` for animation-specific reviews; `find-animation-opportunities`
  for proposal-only motion audits. Read their instructions before invoking them.

If a named skill is unavailable, state it and use an explicitly described fallback.
Never invent tool commands or force an installation rejected by security controls.

## Validation and documentation

- Add the smallest meaningful regression coverage for behavior changes. Test policy
  with simulated power, clock and backend state; ordinary CI must not change host
  power settings or install privileged services.
- Run the repository's complete local check command, when available, after a
  substantive change. Also run checks specific to a changed security/build boundary.
  Do not claim a workflow passed unless its actual execution was observed.
- Current Swift checks: `rtk proxy swift Tools/ProjectTool.swift check`, plus
  `asan` and `tsan` for instrumented runs. See `docs/testing.md` for a separate
  scratch path on a synced Desktop and the local security-tool evidence.
- Build a local ad-hoc app with `rtk proxy swift Tools/ProjectTool.swift bundle`.
  It refuses an existing output directory and never registers a helper or login item.
  See `docs/distribution.md`; a development bundle is not a releasable artifact.
- `check` also validates release inputs and the Homebrew DSL. Each development
  bundle must fail Developer ID and community release checks. `community-bundle`
  builds the ad-hoc SMJobBless layout and verifies embedded metadata without any
  installation. `community-sign`, `community-verify` and `community-package` use
  an actual certificate fingerprint without requiring an Apple Team ID; they do
  not qualify Gatekeeper acceptance. `sign`, `notarize`, `verify`
  and `package` use the same Swift tool; see distribution docs before using them.
  Signature creation and Apple uploads need explicit authorization. Never invent
  a release digest, upload result, available download URL or successful CI run.
- With explicit signing authorization, `rtk proxy swift Tests/SignedXPC/Run.swift
  CERT_SHA1 NEW_OUTPUT_DIRECTORY` checks five non-root signed XPC cases using the
  production identity source. Ordinary `check` only typechecks these files; CodeQL
  compiles them without signing or executing. This probe does not qualify helper
  installation, power changes or Gatekeeper acceptance. See `docs/testing.md`.
- Validate workflow edits with actionlint and zizmor; scan staged changes and Git
  history with Gitleaks. Never silently skip an unavailable security gate.
- Keep `docs/testing.md` accurate about executable commands, results, unavailable
  tools, and separate Mac-only/manual gates. No invented coverage percentages.
- UI work requires native visual inspection, keyboard and accessibility checks and
  local runtime-log review. If the required app or tool is unavailable, report the
  gap. A screenshot or a simulated test does not prove lid-closed operation.
- Read `docs/design.md` before UI changes. Use native materials, system typography,
  original assets, semantic colors, reduced-motion/transparency support, and subtle
  purposeful animation. No Unicode emoji as built-in controls or decorative icons.
- Update the closest canonical documentation with behavior, architecture, CLI,
  installation, security, timing, compatibility, or testing changes.
- Every release must pass the full CI/security gates and the hardware acceptance
  matrix in `docs/requirements.md`. Signatures and notarization are distinct from
  source provenance. No publication before explicit user authorization.

## Git workflow

- Make frequent, small, logical **local** Conventional Commits after relevant checks.
- Check the active branch immediately before staging/committing. Stage explicit
  intended paths. Never discard unrelated work or silently amend another commit.
- Keep the existing Git identity; never change user.name/user.email and never add
  Co-authored-by or automated-agent attribution.
- Use `feature/` for new branches unless the user specifies another name.
- Do not push, publish, merge to main, or create a release without explicit approval.

## Maintenance of these instructions

Keep commands and file pointers consistent with the repository. Record tool and
validation changes here when they affect future contributors. Do not carry over
another product's runtime, infrastructure, business rules, or credentials.
