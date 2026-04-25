import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "ClipFlowLogo" asset catalog image resource.
    static let clipFlowLogo = DeveloperToolsSupport.ImageResource(name: "ClipFlowLogo", bundle: resourceBundle)

    /// The "ClipFlowLogoDark" asset catalog image resource.
    static let clipFlowLogoDark = DeveloperToolsSupport.ImageResource(name: "ClipFlowLogoDark", bundle: resourceBundle)

    /// The "ClipFlowLogoLight" asset catalog image resource.
    static let clipFlowLogoLight = DeveloperToolsSupport.ImageResource(name: "ClipFlowLogoLight", bundle: resourceBundle)

}

