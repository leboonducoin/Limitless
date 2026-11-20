# Design

One 340-point menu. Native material, system typography, short labels and no
separate preferences window. Content sets the height; long lists scroll.

- 21-point title. Battery and remaining time share the callout size.
- The status item stays the same width in all three styles. The default rounds remaining time
  up to a whole minute. It stacks the hours above two-digit minutes, including `00h` above
  `59` for 59 minutes. Local end times also use two lines. Timed styles have a small orange
  loop at the lower right.
  Icon-only and unlimited sessions use the full orange loop during active protection.
- macOS restores the menu-bar position after the user moves the item with Command-drag.
- Command-click starts the configured favorite while idle and adds 15 minutes to an owned active timer. Command-Return starts from the open panel, Command-Plus extends, and Command-Period stops.
  The shortcut requires a press and release over Limitless's item and cancels on a drag.
- Small footer: version, blue author link, MIT and GitHub.
- Immediate settings, one Stop button, outside-click dismissal.
- The full **Options** row toggles a scroll area up to 250 points high. The session controls
  stay above it, and closing the panel collapses Options. Group controls under Session, Power,
  Closed lid, Network, Terminal & agents, Administration and App.
- Small circular + button to the right of Stop for owned manual sessions. Each click adds
  15 minutes to a timer or date; rapid clicks accumulate without disabling the button.
  No extension for unlimited/process sessions. Stop discards queued additions.
- Right-click Check for Updates/Quit/Uninstall follows the app's light/dark appearance; red destructive confirmation.
- The visible panel counts down in seconds. The menu-bar text changes at minute granularity,
  and the panel opens without a transition.
- No selected control on opening; Tab keeps its native focus indicator.
- Copy diagnostic is last in the App settings.
- Opaque backgrounds for Reduce Transparency/increased contrast.
- Text and symbols accompany color. Controls have accessibility labels.

Hide unavailable controls before helper approval. Enable launch at login if the helper is
approved during the same onboarding run, then respect the user's choice.
Login never starts a keep-awake session.
Hide power controls on desktops and the battery limit in adapter mode. Zero warns.
Keep the power-source selector first in Power, with its label above the segmented control.
Battery limit accepts digits only, with the one-percent arrows beside the field.
Values above 80 become 80. Return or leaving the field applies it.
Explain a blocked start or battery cutoff beside the session controls, with a red warning symbol.
Only process mode shows the session ceiling; wait for all selected PIDs.

Changing CLI opt-in keeps the manual session. A helper restart requires new
CLI approval. Updates start enabled
after helper approval and install only while idle; background check failures do not add text to the menu.
Manual checks distinguish an up-to-date app, an active cooldown and a network failure.
Uninstall shows progress and keeps a retryable error if cleanup fails.

Touch ID for sudo appears on supported Macs after helper approval. Confirm its
Mac-wide scope before enabling or disabling a setting configured elsewhere.
Show Touch ID errors directly below its toggle, with a red warning symbol.
Permission refusals name the sudo helper's entry and include an orange Full Disk
Access button. It opens only System Settings.
Keep the observed toggle state and the helper connection.

Native previews are menu-bar only and simulate timer changes in memory. Check light/dark appearance, keyboard, VoiceOver,
contrast and reduced motion for each release. [Testing](testing.md).

Keep the translucent native material on macOS 14 and later. Use Liquid Glass
controls on macOS 26+, with standard controls on older versions. Accessibility
settings take precedence over transparency.
