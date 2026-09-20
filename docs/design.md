# Design

Limitless is a compact native menu-bar utility. All essential settings live in its
340-point panel; there is no separate preferences or About window.

## Appearance

- System type, native material, short labels and standard controls.
- A 21-point title; battery and remaining time use the same callout size.
- Monochrome loop in the menu bar. The dark orange active dot sits below and to
  the right, with its own space so it never covers the loop.
- A small footer: version, blue Arthur Barreau link, MIT, and GitHub at the right.
- Content determines height; long content scrolls instead of leaving empty space.
- Native popover opening motion for mouse clicks. Keyboard opening and Reduce
  Motion are immediate. Polling, the icon and countdown never animate.
- Opaque surfaces for Reduce Transparency or increased contrast. State also has
  text and a symbol; color is not its only indication.

## Behavior

Click outside to close. Closing the panel keeps the session running; Quit releases
the app's manual session. Right-click or Control-click the icon for Quit and
Uninstall. The native uninstall confirmation uses a red destructive button.

Settings apply immediately through the shared validated policy. Power source and
battery controls disappear on Macs confirmed to have no internal battery; source
policy becomes Both. Unknown battery telemetry is not treated as absence.
Power adapter hides the battery control without disabling protection against
actual discharge. Zero still shows a warning when the control is visible.

Stop choices: 15/30/45 minutes, 1/2/4/8/12/24 hours, custom duration, date/time,
process completion, or No limit. Session time limit appears only in process mode;
an already configured ceiling remains enforced. Process selection supports a
searchable list and semicolon-separated PIDs. Wait for all selected identities.

The countdown and remaining PIDs update every second. Hide zero tracked tasks
unless process mode is selected. Active CLI/AI tasks remain visible.

Stop ends existing sessions and retains the CLI preference. A task already stopped
cannot reacquire its hold. AI sessions stand down while a manual session exists,
including when the user starts one during agent work.

## Setup and preferences

Before authenticated helper access, show setup, independent Launch at login, and
the footer. No password field. Signature checking runs off the interface thread.
Preview fixtures are inert and explicitly labelled.

Enabling CLI installs its command shortcut. The native app remembers this opt-in
and can reapply it after reconnecting to an idle, fault-free helper; it never
recreates an awake session. A helper fault revokes the opt-in and requires a new
user decision. The adjacent help link opens [AI setup](cli.md#ai-agent-setup).

Automatic updates are opt-in. Otherwise show Update only when a newer GitHub
release exists. Wait for idle sessions before installing; show concrete errors.
Launch at login never starts a keep-awake session.

Uninstall shows progress, confirms restoration, unregisters the helper and login
item, erases preferences/cache, moves the app to Trash, then quits. Failure keeps
a retryable error visible. Debug previews cannot perform removal.

## Validation

Inspect native light/dark appearances, keyboard focus, VoiceOver, increased
contrast, reduced motion/transparency, long errors and runtime logs.
Emil Kowalski, apple-design and ui-ux-pro-max inform polish; macOS accessibility
and native behavior take precedence over web examples. See [tests](testing.md).

[NSPopover](https://developer.apple.com/documentation/appkit/nspopover) ·
[NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem) ·
[Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
