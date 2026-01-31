# RCP Thumbnail Hash Investigation - Final Report

**Status**: INCONCLUSIVE - Hash algorithm uses proprietary/composite input

---

## Executive Summary

After exhaustive testing of 50+ hash candidates and binary analysis of Reality Composer Pro (RCP), the exact thumbnail hash algorithm **could not be fully reverse-engineered**. The hash appears to use a composite input that likely combines file content with metadata, processed through a proprietary system.

## Key Findings

### 1. Architecture Discovery

RCP uses a **sophisticated distributed thumbnail system**:

- **Primary Framework**: `RealityToolsShared.framework`
  - Class: `RCThumbnailGenerator`
  - Method: `generateThumbnailFor:with:` (offset 0xd018)
  
- **XPC Service**: `RCThumbnailGenerator.xpc`
  - Handles actual generation in separate process
  - Contains error strings: `"Error creating thumbnail for %s"`

- **Asset Framework**: `CoreAsset.framework`
  - Key method: `cacheHashFromFileContents(tag:)` on URL
  - Protocol: `CacheHashProtocol`

### 2. Hash Candidates Tested (All Ruled Out)

| Category | Candidates | Result |
|----------|-----------|--------|
| **Paths** | Absolute, relative, file:// URLs, file ID URLs, URL.dataRepresentation | ✗ No match |
| **Identifiers** | UUIDs (all formats), intIDs, ProjectID, LibraryItemThumbnail-* prefixes | ✗ No match |
| **File System** | Inode, device+inode, bookmark data, minimal bookmark, volume UUID, fileResourceIdentifier | ✗ No match |
| **Content** | Raw file MD5, tag+content, content+tag, path+content combinations | ✗ No match |
| **Combinations** | Path+UUID, ProjectID+UUID, UUID+path, Path+mtime+size, camera transforms | ✗ No match |
| **Cryptography** | SHA1-16, SHA256-16, HMAC-MD5, double-hash, UUID bytes as raw data | ✗ No match |
| **URL Formats** | absoluteString, path, standardized, resolved symlinks, percent-encoded variants | ✗ No match |

**Total combinations tested**: ~2000+ across 5 controlled test files

### 3. Critical Discovery: `cacheHashFromFileContents`

Binary analysis revealed the smoking gun:

```
CoreAsset.framework:
  - URL.cacheHashFromFileContents(tag:) @ 0x374cc
  - AssetFactoryIdentifier.cacheHash(into:) @ 0x35f60
  - CacheHash.Hasher uses CC_MD5state_st (confirmed MD5)
  - CacheHash conforms to CustomStringConvertible (outputs 32-hex string)
```

Key demangled signatures:
```swift
// The core function that computes the hash
(extension in CoreAsset):Foundation.URL.cacheHashFromFileContents(tag: Swift.String) throws -> CoreAsset.CacheHash

// AssetRef identifier (likely the cache key source)
RealityToolsFoundation.AssetRef.identifier.getter : Swift.String
RealityToolsFoundation.AssetRef.init(fileURL: Foundation.URL) -> RealityToolsFoundation.AssetRef
```

This suggests the hash is **content-based** but uses a proprietary algorithm that likely:
- Extracts specific data from the file (not raw bytes)
- May use canonicalized USD structure (via RealityKit's USD parser)
- Takes a `tag` parameter (possibly "thumbnail" or similar)
- Combines content with metadata (path, modification time, UUID)
- Uses MD5 as the final hash function (confirmed via `CC_MD5state_st`)

### 4. Test Project Results

Created test project with 5 controlled files:
- **Location**: `/tmp/rcp_hash_test/HashTest/Package.realitycomposerpro`
- **Files**: A.usda, B_File.usda, C File With Spaces.usda, D-unicode-日本語.usda, E_special@chars#123.usda
- **RCP Generated**: 11 new thumbnails (timestamps 01:22-01:23)
- **Correlated**: 0/50+ candidates matched

### 5. Sample Hashes Collected

```
925e26234f83d5ca7bb7601a99cdb20f  (Jan 31 00:50 - Base/Scene.usda)
95e605007ca31b39e888bd3d16363626  (Jan 31 00:50 - Base/Scene.usda)
79f968bfd992e3c1d32c22e4ad70de26  (Jan 31 01:23 - HashTest project)
be1ce7c2961ce83b693200f9b336a600  (Jan 31 01:23 - HashTest project)
4e5cac93665f4dda4bd9b33b7563b25d  (Jan 31 01:23 - HashTest project)
```

## Conclusion

The thumbnail hash **cannot be replicated** without:
1. Access to CoreAsset.framework's `cacheHashFromFileContents(tag:)` implementation
2. Understanding of the exact input composition (likely canonicalized USD + metadata)
3. Knowledge of the `tag` parameter value used for thumbnails
4. Reverse-engineering the USD canonicalization algorithm (may involve RealityKit's USD parser)

### Why This Is Likely Intentional

Apple's approach provides:
- **Cache invalidation**: Content changes = new hash (no stale thumbnails)
- **Uniqueness**: Same file at different paths gets different hashes
- **Internal consistency**: Only RCP can populate the cache correctly
- **Version compatibility**: Hash algorithm can change between versions

## Recommendation for Deconstructed

**Implement Independent Thumbnail System**:

```swift
// Recommended approach for Deconstructed
struct ThumbnailCache {
    let cacheURL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("com.deconstructed.thumbnails")
    
    func cacheKey(for fileURL: URL) -> String {
        // Use SHA256 of absolute path - deterministic and replicable
        let pathData = Data(fileURL.absoluteString.utf8)
        let hash = SHA256.hash(data: pathData)
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
    
    func thumbnailPath(for fileURL: URL) -> URL {
        cacheURL.appendingPathComponent(cacheKey(for: fileURL) + ".png")
    }
}
```

This provides:
- ✓ Predictable hash function (SHA256 of path)
- ✓ Deterministic (same input = same output)
- ✓ Independence from RCP internals
- ✓ Easy to invalidate (delete cache directory)
- ✓ No conflicts with RCP's cache

## Files Generated

- Investigation report: `RCP_THUMBNAIL_HASH_INVESTIGATION.md`
- Test project: `/tmp/rcp_hash_test/HashTest/Package.realitycomposerpro`
- Test scripts: `/tmp/rcp_hash_test/test_hashes*.swift`, `/tmp/rcp_hash_test/brute_force*.swift`

## Additional Technical Notes

### RCP Thumbnail Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ RealityToolsShared.framework                                     │
│   LibraryController                                              │
│     └── thumbnailCache: NSCache<Library.Item, Future<NSImage>>  │
│     └── loadThumbnailImage(for: Library.Item) -> Future         │
│     └── quicklookThumbnailGenerator: QuickLookThumbnailGenerator│
│     └── thumbnailGenerationService: RCThumbnailGeneratorProtocol│
├─────────────────────────────────────────────────────────────────┤
│ CoreAsset.framework                                              │
│   URL.cacheHashFromFileContents(tag:) -> CacheHash              │
│   CacheHash.Hasher (uses CC_MD5state_st)                        │
│   CacheHash.description -> String (32-hex MD5)                  │
├─────────────────────────────────────────────────────────────────┤
│ RealityToolsFoundation.framework                                 │
│   AssetRef                                                       │
│     └── identifier: String                                       │
│     └── init(fileURL: URL)                                       │
│   Library.Item                                                   │
│     └── identifier: String                                       │
│     └── id: String                                               │
│     └── asAssetRef() -> AssetRef                                │
└─────────────────────────────────────────────────────────────────┘
```

### Cache Location

```
~/Library/Caches/com.apple.RealityComposerPro/
├── Cache.db          # SQLite (CFURL cache, typically empty)
├── Thumbnails/       # PNG thumbnails with MD5 filenames
│   ├── 925e26234f83d5ca7bb7601a99cdb20f.png
│   └── ...
└── fsCachedData/     # Empty in testing
```

---

**Investigation Date**: January 31, 2026  
**Status**: Complete - Hash algorithm proprietary/non-replicable  
**Next Action**: Implement Deconstructed-specific thumbnail system using SHA256 of file path
