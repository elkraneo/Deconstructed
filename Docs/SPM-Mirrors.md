# SwiftPM Mirrors (Local Dev vs CI)

Goal: keep the repo **CI-safe** by committing only remote dependencies (`.package(url: ...)`), while allowing **local development** against private/source checkouts without committing `.package(path: ...)` or `XCLocalSwiftPackageReference`.

## How It Works

SwiftPM supports per-user "mirrors" stored under `~/.swiftpm/configuration`.

When a mirror is set, SwiftPM will fetch the mirrored URL instead of the original URL, even though the manifest still contains `.package(url: ...)`.

This means:

- CI uses remote URLs (no mirrors configured)
- Your machine can route specific packages to `file://...` URLs

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

