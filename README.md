# blankbar

Turn off the MacBook Pro Touch Bar, and keep it off.

If your Touch Bar flickers, flashes or shows lines, the panel is failing. macOS has no
setting to turn it off. blankbar does, with one command.

- No `sudo`, no System Integrity Protection changes
- Stays off after sleep and restart, using a tiny background agent: `blankbar` in
  Activity Monitor, `io.github.dogukanaktas.blankbar` in `~/Library/LaunchAgents`
- No network access, no dependencies
- Undo everything with one command

## Install

```sh
brew install dogukanaktas/tap/blankbar
blankbar install
```

That's it. The Touch Bar goes dark and stays dark.

<details>
<summary>Without Homebrew</summary>

Needs Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/dogukanaktas/blankbar.git
cd blankbar
make install          # installs to ~/.local/bin
blankbar install
```

</details>

## Use

| Command | What it does |
| --- | --- |
| `blankbar install` | Turn the Touch Bar off and keep it off |
| `blankbar on` | Turn it back on (stays on until `blankbar off`) |
| `blankbar off` | Turn it off again |
| `blankbar status` | Show the current state |
| `blankbar uninstall` | Turn it on and remove the background agent |

## Uninstall

```sh
blankbar uninstall
brew uninstall blankbar      # or: make uninstall
```

Run `blankbar uninstall` first, so the background agent is removed too.

## Is it really a hardware fault?

While the bar is glitching, take a screenshot of it:

```sh
screencapture -b ~/Desktop/touchbar.png
```

If the screenshot looks normal, the panel itself is faulty and blankbar will hide it.
If the screenshot shows the glitch, it is a software problem: restart and update macOS.

## Compatibility

| Mac | Status |
| --- | --- |
| 13-inch MacBook Pro M1 (2020), macOS 26 | Tested |
| 13-inch MacBook Pro M2 (2022) | Should work, untested |
| Intel MacBook Pro with Touch Bar (2016–2020) | Untested |

Tried it on another Mac? Please
[report it](https://github.com/dogukanaktas/blankbar/issues/new?template=compatibility.yml),
whether it worked or not.

## Good to know

- **The bar's keys are gone while it is off.** Use Control Center for brightness and
  volume. If your Mac's Escape key is on the Touch Bar, you can map Caps Lock to Escape
  in System Settings > Keyboard > Keyboard Shortcuts > Modifier Keys.
- **It is lit at the login screen**, and may flash for a moment after wake.
- **It uses private macOS frameworks**, because there is no public API for this. A
  future macOS update could break it; blankbar then stops with a clear error.
- **Not a medical safeguard.** If flicker is a health risk for you, cover the bar or
  have it repaired.

## How it works

blankbar calls the same private frameworks macOS uses to dim the Touch Bar
(`DFRBrightness` and `DFRFoundation`). A small background agent, installed in
`~/Library/LaunchAgents`, listens for the bar lighting up (after wake or login) and
turns it off again within milliseconds.

Logs:

```sh
log show --info --last 1h --predicate 'subsystem == "io.github.dogukanaktas.blankbar"'
```

See [SECURITY.md](SECURITY.md) for exactly what it touches on your Mac.

## Credits

Based on the approach in [gbili/touchbar-off](https://github.com/gbili/touchbar-off)
by Guillermo Pages.

## License

MIT
