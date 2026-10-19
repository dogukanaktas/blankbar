# blankbar

Turn the MacBook Pro Touch Bar off, and keep it off.

```sh
brew install dogukanaktas/tap/blankbar
blankbar install
```

macOS has no setting for this. It matters when the Touch Bar's panel fails: it
flickers, flashes or shows lines, and the only real fix is a hardware repair. With the
bar dark, the fault is invisible.

- **No sudo.** Everything stays in your user account.
- **No System Integrity Protection changes**, unlike older tools that disable the bar.
- **No network access**, no telemetry, no dependencies. A few hundred lines of Swift you can read in one sitting.
- **Survives sleep and login.** A small background agent switches the bar off again
  within milliseconds whenever macOS lights it.
- **Fully reversible** with one command.

## Is it a hardware fault?

While the fault is visible, take a picture of what macOS is drawing to the bar:

```sh
screencapture -b ~/Desktop/touchbar.png
```

- **The picture is clean:** the fault is in the panel, its cable or the display
  controller. Software cannot repair it; blankbar hides it.
- **The picture shows the glitch:** macOS is drawing it. Restart and update macOS first.

## Install

### Homebrew

```sh
brew install dogukanaktas/tap/blankbar
blankbar install
```

Homebrew installs a prebuilt package on Apple Silicon Macs with macOS 14 or later and
Intel Macs with macOS 15 or later. On other versions it compiles blankbar, which takes
about a minute and needs the Command Line Tools (`xcode-select --install`).

### From source

Needs Xcode's Command Line Tools 14 or later (`xcode-select --install`), so macOS 12.5
or later.

```sh
git clone https://github.com/dogukanaktas/blankbar.git
cd blankbar
make install        # installs to ~/.local/bin; PREFIX=/some/dir to change
blankbar install
```

`blankbar install` switches the bar off and adds a launch agent,
`~/Library/LaunchAgents/io.github.dogukanaktas.blankbar.plist`, that keeps it off.
macOS shows a "Background Items Added" notification for it; that is expected.

## Use

| Command | What it does |
| --- | --- |
| `blankbar install` | Turn the bar off now and keep it off after sleep and login |
| `blankbar on` | Turn the bar on. It stays on, even after a restart, until `blankbar off` |
| `blankbar off` | Turn the bar off again (and resume keeping it off) |
| `blankbar status` | Show whether the bar is on and whether the agent is running |
| `blankbar uninstall` | Turn the bar on and remove the agent |

Without `install`, `blankbar off` and `blankbar on` work once, until the next sleep or
restart.

Exit codes follow sysexits(3): `0` success, `64` usage error, `69` unsupported Mac or
macOS, `70` the Touch Bar refused the request, `1` anything else.

## Uninstall

Run `blankbar uninstall` **before** removing the command, so the agent goes with it:

```sh
blankbar uninstall
brew uninstall blankbar     # or: make uninstall, in the source folder
```

If the command was removed first, delete the agent by hand:

```sh
launchctl bootout gui/$(id -u)/io.github.dogukanaktas.blankbar
launchctl enable gui/$(id -u)/io.github.dogukanaktas.blankbar
rm ~/Library/LaunchAgents/io.github.dogukanaktas.blankbar.plist
```

Then restart the Mac to light the Touch Bar again.

## Compatibility

| Mac | macOS | Status |
| --- | --- | --- |
| 13-inch MacBook Pro, M1, 2020 (MacBookPro17,1) | 26.5 | Tested |
| 13-inch MacBook Pro, M1, 2020 (MacBookPro17,1) | 15.5 | Tested by [touchbar-off](https://github.com/gbili/touchbar-off) |
| 13-inch MacBook Pro, M2, 2022 (Mac14,7) | — | Untested |
| Intel MacBook Pro with Touch Bar, 2016–2020 | — | Untested |

blankbar refuses to run on a Mac without a Touch Bar, on a macOS that lacks the
interfaces it needs, and as root, with a clear error instead of misbehaving. It also
refuses to install the agent if another user could replace the blankbar binary. If you try it on an
untested Mac, please [open a compatibility report](https://github.com/dogukanaktas/blankbar/issues/new?template=compatibility.yml),
whether it worked or not.

## Limits

- **Private frameworks.** macOS has no public API for this, so blankbar uses the ones
  macOS itself uses. A macOS update can break it; it can never be in the App Store.
- **Only after login.** The bar is lit at the login screen, and may flash briefly at
  wake before the agent reacts.
- **No Touch Bar keys while it is dark.** Brightness, volume and media controls are in
  Control Center. Whether a dark bar still registers touches (including Escape on
  models where it is part of the Touch Bar) is untested; you can map Caps Lock to
  Escape under System Settings > Keyboard > Keyboard Shortcuts > Modifier Keys.
- **Not a medical safeguard.** If a flickering bar is a health risk for you (for
  example photosensitive epilepsy), do not rely on software alone: cover the bar or
  have it repaired.

## How it works

- **`DFRBrightness.framework`** has a class `DFRBrightnessClient` with `turnOff` and
  `turnOn`, the same class macOS's `TouchBarServer` uses for idle dimming.
- **`DFRFoundation.framework`** exports `DFRGetStatus()`, a bit mask where bit `0x4`
  means the panel is dark, and `DFRRegisterStatusChangeCallback()`, which reports every
  change. The agent uses it to switch the bar off the moment something lights it.

The agent ignores changes while another user's session is on screen (fast user
switching), and stops fighting the system if the bar is relit more than 10 times a
minute, so a future macOS change cannot turn it into a busy loop. It logs to the
unified log:

```sh
log show --info --last 1h --predicate 'subsystem == "io.github.dogukanaktas.blankbar"'
```

## Credits

The approach, using `DFRBrightnessClient` and the DFRFoundation status callback, comes
from [gbili/touchbar-off](https://github.com/gbili/touchbar-off) by Guillermo Pages
(MIT). blankbar reworks it as a command-line tool with Homebrew distribution, a
persistent on/off state, a status command, hardware checks and tests.

## License

MIT. See [LICENSE](LICENSE).
