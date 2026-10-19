# Security

## What blankbar does on your Mac

- Runs as your user. It never asks for or uses `sudo`.
- Writes one file, `~/Library/LaunchAgents/io.github.dogukanaktas.blankbar.plist`, and
  registers it with `launchctl` in your own GUI session.
- Loads two of Apple's private frameworks from `/System/Library/PrivateFrameworks`
  (`DFRBrightness`, `DFRFoundation`) and calls them to read and switch the Touch Bar.
- Makes no network connections and collects no data.

`blankbar uninstall` removes the launch agent and clears the launchd override that
`blankbar on` sets. Remove the binary with `brew uninstall blankbar` or `make uninstall`.
macOS may keep an entry in its Login Items list until the next restart.

`blankbar install` refuses to register a binary that another local user could replace
(a world- or group-writable folder, one owned by another non-admin user, or a temporary
folder), since the agent runs it at every login. The check reads Unix permissions; it
does not inspect ACLs, so do not install into a folder you have shared with others.

## Reporting a vulnerability

Please report security issues privately through
[GitHub's private vulnerability reporting](https://github.com/dogukanaktas/blankbar/security/advisories/new)
rather than in a public issue. You can expect a first reply within a week.

## Supported versions

Only the latest release receives fixes.
