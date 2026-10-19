import AppKit
import CoreText
import SwiftUI

/// Urbanist for everything, Titillium Web for the F1 bits. Both ship inside the
/// app (SIL Open Font License, see Resources/Fonts).
enum FontRegistry {
    /// Registers each bundled font from memory. Going through CoreGraphics
    /// keeps the system font daemon out of it; handing it the files can stall
    /// when they still carry the download quarantine flag.
    static func registerBundledFonts() {
        guard let root = Bundle.main.resourceURL,
              let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return }
        for case let url as URL in files where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
            guard let provider = CGDataProvider(url: url as CFURL), let font = CGFont(provider) else {
                NSLog("Lobby: couldn't read font \(url.lastPathComponent)")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterGraphicsFont(font, &error) {
                let reason = error?.takeRetainedValue().localizedDescription ?? "unknown"
                NSLog("Lobby: couldn't register font \(url.lastPathComponent): \(reason)")
            }
        }
    }
}

extension Font {
    static func urbanist(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .medium: name = "Urbanist-Medium"
        case .semibold: name = "Urbanist-SemiBold"
        case .bold: name = "Urbanist-Bold"
        case .heavy, .black: name = "Urbanist-ExtraBold"
        default: name = "Urbanist-Regular"
        }
        return .custom(name, size: size)
    }

    static func titillium(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        let name: String
        switch weight {
        case .heavy, .black: name = "TitilliumWeb-Black"
        case .semibold: name = "TitilliumWeb-SemiBold"
        default: name = "TitilliumWeb-Bold"
        }
        return .custom(name, size: size)
    }
}
