# Local Development with USD Dependencies

## How It Works

The `Deconstructed.xcworkspace` includes local checkouts of:
- `/Volumes/Plutonian/_Developer/SwiftUsdShell` (pure-Swift contract boundary, when enabled in the workspace)
- `/Volumes/Plutonian/_Developer/USDInterop`
- `/Volumes/Plutonian/_Developer/USDTools` (optional for internal/private workflows, not required for the public editor path)

**Xcode automatically prefers local packages over remote dependencies with the same name.**

This means:
- `Package.swift` stays CI-safe (always points to remote URLs)
- Local edits are compiled immediately
- No scripts or configuration needed

## Requirements

- A local `USDInterop` checkout must exist at the path above if you want workspace-local package overrides
- `SwiftUsdShell` is the preferred destination for public USD contracts, but it should not be treated as a runtime implementation package
- `USDTools` is only needed for private/internal work and should not be required to build the public Deconstructed path
- Open `Deconstructed.xcworkspace` (not `.xcodeproj`)

## Archived Scripts

Legacy scripts for CLI-based workflows are in `Scripts/_archived/` but are not needed for normal Xcode development.
