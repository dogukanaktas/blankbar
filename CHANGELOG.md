# Changelog

All notable changes are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-17

### Added

- `blankbar install`, `off`, `on`, `status`, `uninstall`, `help` and `version`.
- A per-user launch agent that switches the Touch Bar off again after sleep, login and
  fast user switching.
- `blankbar on` persists across restarts until `blankbar off`.
- Hardware and macOS checks with clear errors and sysexits(3) exit codes.
- Refuses to run as root, and to install an agent whose binary another user could replace.
- Homebrew formula and `make install`.

[1.0.0]: https://github.com/dogukanaktas/blankbar/releases/tag/v1.0.0
