# Native interface contract

Limitless is a quiet macOS utility. Its main surface is a compact MenuBarExtra
window, with a separate native settings window. The panel leads with the actual
observed state, offers one manual session control, and shows independent task
activity. Closing the panel never ends a session. Quit releases the app's manual
session; independently authorized CLI tasks can continue.

## Visual language

- System typography, semantic foreground/background colors, an eight-point spacing
  rhythm and a compact desktop density. No web UI, downloaded fonts or UI dependency.
- One native material surface. Liquid Glass is reserved for native controls;
  do not stack translucent cards or blur readable content.
- An original drawn loop mark, with an indigo app-icon field and a monochrome
  template menu-bar version. Use SF Symbols for standard actions and power status.
- A 360-point panel with grouped controls, short labels and enough height for
  wrapped error text. Settings can grow and scroll; avoid clipped fixed-height forms.
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

Manual stop conditions include all core presets, a positive custom duration,
date/time, process completion and unlimited time. CLI commands provide command
completion. PID tracking uses the same unprivileged identity adapter as the CLI.
Policy edits are explicit and validated before application; the helper validates
again. The 0–50% battery control moves in single-percent steps and shows an inline
warning at zero. An optional maximum per session is separate from the next manual
session's stop condition.

Automation authorization is an independent control, not a consequence of opening
the app or starting a manual session. Launch at login uses SMAppService.mainApp
and never creates a demand. No active state or automation consent is restored from
preferences. Saved power/battery/duration preferences may be reapplied only through
the user's explicit control action; a live helper policy takes precedence.

Initial helper setup uses the bundle's native installation adapter: SMAppService
for the notarized channel or SMJobBless with Authorization Services for the community
channel. macOS owns the consent interface; there is no app password field.
Register only in response to the setup button. Development builds
without a trusted signing identity expose the UI but disable privileged actions.
While the initial identity check is pending, show native preparation feedback and
keep integration controls disabled; do not label that pending state as an untrusted
development build. Signature validation must not block the interface thread.
Setup explanations retain their full vertical size within the panel width, so
administrator approval and password handling information are never truncated.
Debug previews are clearly labeled and cannot call the helper, register services,
change login items or persist power policy.

Removal uses a native confirmation, separate from ordinary Stop. It states that
all sessions end while commands continue. An explicit preference-erasure option is
off by default. The preview may open the confirmation, but cannot execute its
destructive action. Successful preparation leaves clear instructions to quit and
remove the app; a failure keeps retry guidance and never claims removal succeeded.

## Design references and validation

The installed Emil Kowalski and apple-design skills informed feedback, hierarchy,
native materials and restrained motion. ui-ux-pro-max's accessibility search
informed focus, clear errors and loading feedback; its generated marketing-page
layout is unsuitable for this native utility and is not used. Mobile/web examples
do not override macOS conventions.

Verify light/dark, reduced transparency/motion, increased contrast, long errors,
all stop conditions, focus order, native window behavior and runtime logs. A
preview demonstrates presentation only, never actual power state or lid support.

Primary API references: [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra),
[Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views),
[SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice).
