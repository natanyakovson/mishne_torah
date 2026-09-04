import CoreText
import Foundation

struct InstalledFont {
    let postScriptName: String
    let displayName: String
    let fileName: String
}

enum FontInstallService {
    static func installFont(from sourceURL: URL) throws -> InstalledFont {
        let fontsDirectory = try userFontsDirectory()
        let fileExtension = sourceURL.pathExtension.isEmpty ? "ttf" : sourceURL.pathExtension
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let destinationURL = fontsDirectory.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        let fontNames = try fontNames(from: destinationURL)
        try registerFont(at: destinationURL)

        return InstalledFont(
            postScriptName: fontNames.postScriptName,
            displayName: fontNames.displayName,
            fileName: fileName
        )
    }

    static func registerStoredFont(fileName: String?) {
        guard let fileName, !fileName.isEmpty else { return }
        guard let directory = try? userFontsDirectory() else { return }
        let url = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? registerFont(at: url)
    }

    private static func userFontsDirectory() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent("UserFonts", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func fontNames(from url: URL) throws -> (postScriptName: String, displayName: String) {
        guard let provider = CGDataProvider(url: url as CFURL),
              let font = CGFont(provider),
              let postScriptName = font.postScriptName as String? else {
            throw FontInstallError.unreadableFont
        }

        let fullName = font.fullName as String?
        return (postScriptName, fullName ?? postScriptName)
    }

    private static func registerFont(at url: URL) throws {
        var error: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !registered, let error {
            let nsError = error.takeRetainedValue() as Error
            throw nsError
        }
    }
}

enum FontInstallError: LocalizedError {
    case unreadableFont

    var errorDescription: String? {
        switch self {
        case .unreadableFont:
            "Не удалось прочитать файл шрифта."
        }
    }
}
