import CxxStdlib
import Foundation
@_spi(Internal) import OpenUSD

// Deconstructed-specific USD pipeline helpers.
//
// This is intentionally "surface/business logic": folder conventions, resource rewrites,
// plugin-specific SDF_FORMAT_ARGS usage, etc.

public enum DeconstructedUSDPipeline {
    public static func convertPluginToUsdc(sourceURL: URL, outputUSDC: URL, resourcesURL: URL) throws {
        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

        let stagePath = "\(sourceURL.path):SDF_FORMAT_ARGS:assetsPath=\(resourcesURL.path)"
        let stagePtr = pxrInternal_v0_25_8__pxrReserved__.UsdStage.Open(
            std.string(stagePath),
            pxrInternal_v0_25_8__pxrReserved__.UsdStage.InitialLoadSet.LoadAll
        )
        guard stagePtr._isNonnull() else {
            throw NSError(domain: "DeconstructedUSDPipeline", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to open plugin file: \(sourceURL.path)"
            ])
        }
        let stage = OpenUSD.Overlay.Dereference(stagePtr)

        let flattenedLayerPtr = stage.Flatten()
        guard flattenedLayerPtr._isNonnull() else {
            throw NSError(domain: "DeconstructedUSDPipeline", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to flatten stage"
            ])
        }
        let flattenedLayer = OpenUSD.Overlay.Dereference(flattenedLayerPtr)

        let success = flattenedLayer.Export(
            std.string(outputUSDC.path),
            std.string(),
            pxrInternal_v0_25_8__pxrReserved__.SdfLayer.FileFormatArguments()
        )
        guard success else {
            throw NSError(domain: "DeconstructedUSDPipeline", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Failed to export flattened USDC to \(outputUSDC.path)"
            ])
        }
    }

    /// Deconstructed convention: rewrite texture asset paths to `../Resources/<filename>`,
    /// copying missing textures into `resourcesDir` from `sourceDir`.
    public static func fixTexturePaths(in usdcURL: URL, resourcesDir: URL, sourceDir: URL) throws {
        let imageExtensions = Set(["png", "jpg", "jpeg", "tiff", "tif", "exr", "hdr", "bmp"])

        var resourceFiles = Set((try? FileManager.default.contentsOfDirectory(atPath: resourcesDir.path)) ?? [])

        let stagePtr = pxrInternal_v0_25_8__pxrReserved__.UsdStage.Open(
            std.string(usdcURL.path),
            pxrInternal_v0_25_8__pxrReserved__.UsdStage.InitialLoadSet.LoadAll
        )
        guard stagePtr._isNonnull() else { return }
        let stage = OpenUSD.Overlay.Dereference(stagePtr)

        var modified = false

        for prim in stage.Traverse() {
            if prim.IsA(pxrInternal_v0_25_8__pxrReserved__.TfToken("Shader")) {
                let shader = pxrInternal_v0_25_8__pxrReserved__.UsdShadeShader(prim)
                let inputs = shader.GetInputs()

                for i in 0..<inputs.size() {
                    let input = inputs[i]
                    let inputName = String(input.GetBaseName().GetString())
                    if inputName.lowercased().contains("file") || inputName.lowercased().contains("texture") {
                        let attr = input.GetAttr()
                        var val = pxrInternal_v0_25_8__pxrReserved__.VtValue()

                        if attr.IsValid(), attr.Get(&val) {
                            let assetPath = String(describing: val)
                            guard !assetPath.isEmpty else { continue }

                            let cleanPath = assetPath.replacingOccurrences(of: "@", with: "")
                            let filename = URL(fileURLWithPath: cleanPath).lastPathComponent
                            let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
                            guard imageExtensions.contains(ext) else { continue }

                            if !resourceFiles.contains(filename) {
                                let sourcePath = sourceDir.appendingPathComponent(filename)
                                if FileManager.default.fileExists(atPath: sourcePath.path) {
                                    let destPath = resourcesDir.appendingPathComponent(filename)
                                    if !FileManager.default.fileExists(atPath: destPath.path) {
                                        try? FileManager.default.copyItem(at: sourcePath, to: destPath)
                                    }
                                    resourceFiles.insert(filename)
                                }
                            }

                            if resourceFiles.contains(filename) {
                                let newPath = "../Resources/\(filename)"
                                attr.Set(pxrInternal_v0_25_8__pxrReserved__.VtValue(
                                    pxrInternal_v0_25_8__pxrReserved__.SdfAssetPath(std.string(newPath))
                                ))
                                modified = true
                            }
                        }
                    }
                }
            }
        }

        if modified {
            let rootLayer = OpenUSD.Overlay.Dereference(stage.GetRootLayer())
            _ = rootLayer.Save()
        }
    }

    /// Deconstructed convention: fix UsdPreviewSurface input asset paths that look like "@dir/file.png@".
    /// Rewrites them to "../Resources/<filename>".
    public static func fixTextureWiring(in usdcURL: URL) throws {
        let stagePtr = pxrInternal_v0_25_8__pxrReserved__.UsdStage.Open(
            std.string(usdcURL.path),
            pxrInternal_v0_25_8__pxrReserved__.UsdStage.InitialLoadSet.LoadAll
        )
        guard stagePtr._isNonnull() else { return }
        let stage = OpenUSD.Overlay.Dereference(stagePtr)

        var modified = false

        for prim in stage.Traverse() {
            if prim.IsA(pxrInternal_v0_25_8__pxrReserved__.TfToken("Shader")) {
                let shader = pxrInternal_v0_25_8__pxrReserved__.UsdShadeShader(prim)
                var idValue = pxrInternal_v0_25_8__pxrReserved__.VtValue()
                if shader.GetIdAttr().Get(&idValue) {
                    let shaderIdStr = String(describing: idValue)
                    guard shaderIdStr.contains("UsdPreviewSurface") else { continue }

                    let slots = ["diffuseColor", "emissiveColor", "metallic", "roughness", "normal", "opacity"]
                    for slot in slots {
                        let attr = prim.GetAttribute(pxrInternal_v0_25_8__pxrReserved__.TfToken(std.string("inputs:\(slot)")))
                        if attr.IsValid() {
                            var val = pxrInternal_v0_25_8__pxrReserved__.VtValue()
                            if attr.Get(&val) {
                                let raw = String(describing: val)
                                if raw.contains("@") && raw.contains("/") {
                                    let cleanPath = raw.replacingOccurrences(of: "@", with: "")
                                    let filename = URL(fileURLWithPath: cleanPath).lastPathComponent
                                    let correctPath = "../Resources/\(filename)"
                                    attr.Set(pxrInternal_v0_25_8__pxrReserved__.VtValue(
                                        pxrInternal_v0_25_8__pxrReserved__.SdfAssetPath(std.string(correctPath))
                                    ))
                                    modified = true
                                }
                            }
                        }
                    }
                }
            }
        }

        if modified {
            let rootLayer = OpenUSD.Overlay.Dereference(stage.GetRootLayer())
            _ = rootLayer.Save()
        }
    }
}
