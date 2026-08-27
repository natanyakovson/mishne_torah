import SwiftUI

final class AppearanceController: ObservableObject {
    @Published var theme: ReaderTheme = .system

    var colorScheme: ColorScheme? {
        switch theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
