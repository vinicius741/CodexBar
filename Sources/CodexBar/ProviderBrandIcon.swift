import AppKit
import CodexBarCore

enum ProviderBrandIcon {
    private final class BundleLocator {}

    private static let size = NSSize(width: 16, height: 16)
    private static let sourceResourcesDirectory: URL? = {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)
        guard FileManager.default.fileExists(atPath: sourceRoot.path) else { return nil }
        return sourceRoot
    }()

    /// Candidate bundles where provider icons can live across app/test/package layouts.
    private static let resourceBundles: [Bundle] = {
        let moduleBundleName = "CodexBar_CodexBar.bundle"
        let locatorBundle = Bundle(for: BundleLocator.self)

        var candidates: [Bundle] = []

        func appendBundle(at url: URL?) {
            guard let url,
                  let bundle = Bundle(url: url)
            else {
                return
            }
            candidates.append(bundle)
        }

        func appendModuleBundleCandidates(from bundle: Bundle) {
            appendBundle(at: bundle.resourceURL?.appendingPathComponent(moduleBundleName))
            appendBundle(at: bundle.bundleURL.appendingPathComponent(moduleBundleName))
            appendBundle(at: bundle.bundleURL.deletingLastPathComponent().appendingPathComponent(moduleBundleName))
        }

        appendModuleBundleCandidates(from: locatorBundle)
        appendModuleBundleCandidates(from: Bundle.main)

        // Also include the owning bundles directly as a fallback.
        candidates.append(locatorBundle)
        candidates.append(Bundle.main)

        var unique: [Bundle] = []
        var seenPaths = Set<String>()
        for bundle in candidates {
            let path = bundle.bundleURL.path
            if seenPaths.insert(path).inserted {
                unique.append(bundle)
            }
        }

        return unique
    }()

    static func image(for provider: UsageProvider) -> NSImage? {
        let baseName = ProviderDescriptorRegistry.descriptor(for: provider).branding.iconResourceName
        guard let bundle = self.resourceBundle else {
            return nil
        }
        guard let url = bundle.url(forResource: baseName, withExtension: "svg"),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        if let sourceResourcesDirectory {
            let sourceURL = sourceResourcesDirectory.appendingPathComponent("\(baseName).svg")
            if let image = NSImage(contentsOf: sourceURL) {
                image.size = self.size
                image.isTemplate = true
                return image
            }
        }

        return nil
    }
}
