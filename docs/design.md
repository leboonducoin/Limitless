# Native interface contract

Limitless is a quiet macOS utility. Its main surface is a compact AppKit popover
hosting SwiftUI, including all power, automation and login settings. The panel leads
with the observed state and one manual session control. Empty task counts appear
only when process completion is selected; actual task activity remains visible.
Closing the panel never ends a session. Quit releases the app's manual
session; independently authorized CLI tasks can continue.

## Visual language

- System typography, semantic foreground/background colors, an eight-point spacing
  rhythm and a compact desktop density. No web UI, downloaded fonts or UI dependency.
- One native material surface. Liquid Glass is reserved for native controls;
  do not stack translucent cards or blur readable content.
- An original drawn loop mark, with an indigo app-icon field and a monochrome
  template menu-bar version when idle. The entire menu-bar mark turns dark orange
  during observed active protection, with no separate dot; the accessible status
  label supplies the same information in words.
  Use SF Symbols for standard actions and power status.
- A 360-point panel with grouped controls, short labels and enough height for
  wrapped error text. The body scrolls within the available screen height. Author,
  version and MIT information remain in a small footer, with a GitHub link at the
  right; Arthur Barreau's credit is a semantic blue link to his LinkedIn profile.
  There is no About button.
  Measure content height rather than reserving
  empty space. Clicking another app or outside the popover closes it.
- Native control feedback and popover motion. No decorative loops, countdown
  animation, custom drag physics or delayed keyboard feedback.

Reduced transparency or increased contrast uses opaque surfaces and standard
bordered buttons. Respect Reduce Motion through native controls; any later custom
transition must be disabled or replaced with a short fade. State has text and a
symbol, never color alone. Buttons retain native focus, keyboard and accessibility
semantics. Icon-only actions have explicit labels/help. VoiceOver and keyboard
operation require actual inspection before the UI is considered verified.

## Behavior and information

The state presentation distinguishes active, inactive, suspended, recovering,
restoring, unavailable and action-required states. A global disabled flag without
Limitless ownership is not our active session. Unknown telemetry cannot become
"off". Show the last sample only as stale after a connection error.

Manual stop conditions include 15/30/45 minutes, 1/2/4/8/12/24 hours, a positive
custom duration, date/time, process completion and unlimited time. CLI commands
provide command completion. A searchable scrolling list shows readable processes
owned by the current user; manual semicolon-separated PID entry remains available.
Multiple selection waits for all selected processes to end or become unreadable.
The live task count includes remaining selected processes and CLI task sessions.
While running, a compact scrolling list retains the PIDs still awaited; ended
identities disappear on the next one-second observation.
Selection captures
the start timestamp and is revalidated at Start, preventing PID reuse. Names remain
in memory and command arguments are never read. Tracking uses the same unprivileged
identity adapter as the CLI. Routine explanatory text is omitted; errors and the
zero-battery warning remain visible.
Policy edits apply automatically through a serialized queue; replies cannot overwrite
newer edits. The helper validates again. The 0–50% **Battery reserved limit** moves
in single-percent steps and shows an inline warning at zero. **Session time limit**
appears only in process mode. Its configured user ceiling continues to protect all
sessions; hiding its control never silently relaxes an existing limit. No limit is
only a timing-menu choice. The single Stop button ends all demands and revokes task
authorization; watched-process completion releases only the app's own demand.
Countdown text refreshes each second from the last helper sample and a monotonic clock.

Automation authorization is an independent control, not a consequence of opening
the app or starting a manual session. Its adjacent help link opens the exact
[AI setup section](cli.md#ai-agent-setup). Launch at login uses SMAppService.mainApp
and never creates a demand. No active state or automation consent is restored from
preferences. Saved power/battery/duration preferences may be reapplied only through
the user's explicit control action; a live helper policy takes precedence.

Initial helper setup uses the bundle's native installation adapter: SMAppService
for the notarized channel or SMJobBless with Authorization Services for the community
channel. macOS owns the consent interface; there is no app password field.
Register only in response to the setup button. Until an authenticated helper is
available, show setup/status, Launch at login and the footer; hide session, power,
automation and update controls. Launch at login does not need the helper or admin
approval, but still requires a trusted installed app. Untrusted development builds
show setup guidance; explicit Debug previews expose inert presentation fixtures.
While the initial identity check is pending, show native preparation feedback and
keep integration controls disabled; do not label that pending state as an untrusted
development build. Signature validation must not block the interface thread.
Setup explanations retain their full vertical size within the panel width, so
administrator approval and password handling information are never truncated.
Debug previews are clearly labeled and cannot call the helper, register services,
change login items or persist power policy.

Right-click or Control-click on the status icon opens Quit and Uninstall. Command-Q
and the native application menu remain available for keyboard users. Uninstall uses
a native confirmation, separate from Stop: all sessions end while commands continue.
Successful cleanup always erases preferences and documented cache/window state,
then moves the app to Trash. A failed stage retains clear retry guidance. The preview
can open the confirmation but cannot execute its destructive action.
Cleanup shows progress. App recycling uses NSWorkspace's Finder-style operation;
errors are brought to the foreground. After verified cleanup and recycling, quit
immediately without another confirmation dialog or a second asynchronous stop.

While the app is open with an observed active session, ordinary macOS restart or
shutdown requests are deferred through AppKit. The app refreshes helper status
before deciding; expired sessions or inactive/suspended protection do not defer.
The panel explains a deferred restart and the user can stop Limitless to proceed.
Ordinary Quit, Command-Q, logout and uninstall retain their existing behavior.
This does not change automatic-update settings, block downloads or guarantee
protection from a forced restart or a managed update deadline.

Automatic updates are off by default. Stable GitHub releases are checked at launch
and every six hours after successful checks. Rate limits show GitHub's retry time;
other failures show their actual reason and retry after fifteen minutes.
With automatic updates off, show Update only for a newer release;
with them on, wait for all sessions to end. Download/installation errors are visible.
Preferences and login registration survive updates; automation and power sessions
never resume themselves. macOS owns any new launch/helper approval.

Reuse the cached idle/active status images across polling; change the image and
accessible label only when the observed presentation changes. Activate before
opening the popover and round measured content height to whole points to avoid
fractional layout churn. Countdown updates have no implicit animation.

## Design references and validation

The installed Emil Kowalski and apple-design skills informed feedback, hierarchy,
native materials and restrained motion. ui-ux-pro-max's accessibility search
informed focus, clear errors and loading feedback; its generated marketing-page
layout is unsuitable for this native utility and is not used. Mobile/web examples
do not override macOS conventions.

Verify light/dark, reduced transparency/motion, increased contrast, long errors,
all stop conditions, focus order, native window behavior and runtime logs. A
preview demonstrates presentation only, never actual power state or lid support.

Primary API references: [NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem),
[NSPopover](https://developer.apple.com/documentation/appkit/nspopover),
[Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views),
[SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice).
