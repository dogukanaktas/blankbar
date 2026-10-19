# Contributing

Thanks for helping. The most useful contribution right now is a
[compatibility report](https://github.com/dogukanaktas/blankbar/issues/new?template=compatibility.yml)
from a Mac or macOS version that is not yet in the README's table.

## Development

```sh
swift build        # debug build
swift test         # unit tests, run on any Mac
make install       # release build into ~/.local/bin
```

Logic without side effects (argument parsing, plist generation, parsers, the rate
limiter) lives in `Sources/BlankBarCore` and is unit tested. Code that touches the
system (private frameworks, `launchctl`, the file system) lives in `Sources/blankbar`
and has to be tested by hand on a Mac with a Touch Bar:

1. `blankbar install`, then sleep and wake the Mac: the bar must stay dark.
2. `blankbar on`, restart: the bar must stay lit. `blankbar off`: dark again.
3. `blankbar status` in each state.
4. `blankbar uninstall`: the bar is lit and the plist is gone.

## Pull requests

- Keep the dependency count at zero.
- Keep the minimum at macOS 11 and Swift 5.7: CI builds with warnings as errors.
- Add a line to `CHANGELOG.md` under an `Unreleased` heading.
- User-facing messages are in English and tell the user what to do next.

## Releasing (maintainers)

1. Update `BlankBar.version` in `Sources/BlankBarCore/BlankBar.swift` and `CHANGELOG.md`.
2. Commit, then `git tag vX.Y.Z && git push origin main vX.Y.Z`. CI checks the tag
   matches the version and creates the GitHub release.
3. Run `scripts/update-formula.sh X.Y.Z` to write the new formula into a clone of
   [homebrew-tap](https://github.com/dogukanaktas/homebrew-tap), commit it on a branch
   and open a pull request **from your own account** (`gh pr create`). The tap's CI
   builds bottles (prebuilt packages, so users need no compiler) only for pull
   requests; it does not run for pull requests opened by GitHub Actions' own token.
4. When the tap's checks pass, run its "brew pr-pull" workflow with the pull request
   number. It uploads the bottles and pushes the formula to `main`.
