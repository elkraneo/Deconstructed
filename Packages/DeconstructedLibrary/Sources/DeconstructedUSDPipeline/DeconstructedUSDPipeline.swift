import Foundation
import USDInteropAdvancedWorkflows

// Deconstructed-specific USD pipeline helpers.
//
// This is intentionally "surface/business logic": folder conventions, resource rewrites,
// plugin-specific SDF_FORMAT_ARGS usage, etc.

public enum DeconstructedUSDPipeline {
    public static func convertPluginToUsdc(sourceURL: URL, outputUSDC: URL, resourcesURL: URL) throws {
        let client = USDAdvancedClient()
        try client.convertPluginToUsdc(sourceURL: sourceURL, outputUSDC: outputUSDC, resourcesURL: resourcesURL)
    }

    /// Deconstructed convention: rewrite texture asset paths to `../Resources/<filename>`,
    /// copying missing textures into `resourcesDir` from `sourceDir`.
    public static func fixTexturePaths(in usdcURL: URL, resourcesDir: URL, sourceDir: URL) throws {
        let client = USDAdvancedClient()
        try client.fixTexturePaths(in: usdcURL, resourcesDir: resourcesDir, sourceDir: sourceDir)
    }

    /// Fixes texture wiring for known plugin issues.
    public static func fixTextureWiring(in usdcURL: URL) throws {
        let client = USDAdvancedClient()
        try client.fixTextureWiring(in: usdcURL)
    }
}
