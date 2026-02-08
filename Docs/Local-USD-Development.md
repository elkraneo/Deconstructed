# Local Development with USD Dependencies

## How It Works

The `Deconstructed.xcworkspace` includes local checkouts of:
- `/Volumes/Plutonian/_Developer/USDInteropAdvanced`
- `/Volumes/Plutonian/_Developer/USDInterop`

**Xcode automatically prefers local packages over remote dependencies with the same name.**

This means:
- `Package.swift` stays CI-safe (always points to remote URLs)
- Local edits are compiled immediately
- No scripts or configuration needed

## Requirements

- Local checkouts must exist at the paths above
- Open `Deconstructed.xcworkspace` (not `.xcodeproj`)

## Archived Scripts

Legacy scripts for CLI-based workflows are in `Scripts/_archived/` but are not needed for normal Xcode development.
