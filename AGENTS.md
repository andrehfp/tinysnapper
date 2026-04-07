# AGENTS

This file is for coding agents working inside a local clone of TinySnapper.

If a user asks you to install, run, or smoke-test the app locally, use the commands below.

## Repo summary

- App: **TinySnapper**
- Platform: **macOS only**
- Language: **Swift 6**
- Build system: **Swift Package Manager**
- Installed app path: `/Applications/TinySnapper.app`

## Prerequisites

- macOS 13 or later
- Xcode Command Line Tools or Xcode with Swift 6 support

## Fastest local install

From the repo root:

```sh
./scripts/install-app.sh
```

This will:

1. build the app bundle into `dist/TinySnapper.app`
2. copy it to `/Applications/TinySnapper.app`

## Start, restart, or stop the app

```sh
./scripts/run-tinysnapper.sh start
./scripts/run-tinysnapper.sh restart
./scripts/run-tinysnapper.sh stop
```

Notes:

- `start` installs the app first if needed
- if a login agent is installed, the script manages that too

## Optional: install launch at login

```sh
./scripts/install-login-agent.sh
```

This installs a user LaunchAgent for TinySnapper.

## Basic smoke test flow

After installing:

1. Launch TinySnapper from `/Applications/TinySnapper.app` if it is not already running.
2. Verify the menu bar icon appears.
3. Try `Capture Screenshot`.
4. Try `Capture and Copy Styled`.
5. Try `Open From Clipboard`.
6. Try `Open From File`.
7. If the editor opens, verify you can export a PNG.

## Important macOS permission

TinySnapper needs **Screen Recording** permission to capture screenshots.

Expected behavior:

- macOS prompts the user the first time capture is attempted
- if macOS asks to quit and reopen the app, do that and retry
- this permission cannot be pre-approved by script on another Mac

## Useful commands

```sh
# SwiftPM debug build
swift build

# Build app bundle only
./scripts/build-app.sh

# Install app locally
./scripts/install-app.sh

# Package for another Mac
./scripts/package-for-another-mac.sh
```

## Troubleshooting

### Build fails after repo rename or move

If `swift build` fails with module cache or `SwiftShims` errors:

```sh
rm -rf .build
swift build
```

### App did not launch after install

Try:

```sh
open /Applications/TinySnapper.app
```

Then use:

```sh
./scripts/run-tinysnapper.sh restart
```

## Files agents usually need

- `README.md` — public project docs
- `scripts/build-app.sh` — app bundle build
- `scripts/install-app.sh` — local install to `/Applications`
- `scripts/run-tinysnapper.sh` — start/restart/stop helpers
- `scripts/install-login-agent.sh` — launch agent install
- `Sources/TinySnapper/AppDelegate.swift` — app startup
- `Sources/TinySnapper/Support/AppCoordinator.swift` — menu bar orchestration

## Release note

Do **not** run the production release flow unless the user explicitly asks for it. Production release requires signing and notarization configuration.
