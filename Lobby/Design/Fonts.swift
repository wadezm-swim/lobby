import AppKit
import CoreText
import SwiftUI

/// Urbanist for everything, Titillium Web for the F1 bits. Both ship inside the
/// app (SIL Open Font License, see Resources/Fonts).
enum FontRegistry {
    static func registerBundledFonts() {
        guard let root = Bundle.main.resourceURL,
              let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return }
        for case let url as URL in files where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
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
