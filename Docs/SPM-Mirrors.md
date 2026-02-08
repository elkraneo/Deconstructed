# SwiftPM Mirrors (Local Dev vs CI)

Goal: keep the repo **CI-safe** by committing only remote dependencies (`.package(url: ...)`), while allowing **local development** against private/source checkouts without committing `.package(path: ...)` or `XCLocalSwiftPackageReference`.

## How It Works

SwiftPM supports per-user "mirrors" stored under `~/.swiftpm/configuration`.

When a mirror is set, SwiftPM will fetch the mirrored URL instead of the original URL, even though the manifest still contains `.package(url: ...)`.

This means:

- CI uses remote URLs (no mirrors configured)
- Your machine can route specific packages to `file://...` URLs

Important limitation:

- Mirrors only work when the mirror points at the *same package content* (same tags/versions/commit history), just hosted at a different location. They cannot be used to swap a versioned binaries wrapper package to an unrelated source repo with different tags.

## Use The Repo Scripts

Install mirrors:

```sh
./Scripts/spm-mirrors/install.sh
```

Check mirror status:

```sh
./Scripts/spm-mirrors/status.sh
```

Remove mirrors:

```sh
./Scripts/spm-mirrors/uninstall.sh
```

## Notes

- Mirrors are **not** committed to git.
- Pre-push checks will block commits containing:
  - `.package(path: ...)`
  - `XCLocalSwiftPackageReference` in `.pbxproj`

## Local USDInteropAdvanced Source

To develop against local `USDInteropAdvanced` source instead of `USDInteropAdvanced-binaries`, use:

```sh
./Scripts/usdinteropadvanced-local/enable.sh
```

and then switch back before pushing:

```sh
./Scripts/usdinteropadvanced-local/disable.sh 0.2.15
```

These scripts are intentionally local-dev only and must not be committed.
