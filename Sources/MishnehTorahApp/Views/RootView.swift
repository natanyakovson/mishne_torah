import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MTReaderSettings.textSize) private var settings: [MTReaderSettings]
    @EnvironmentObject private var appearance: AppearanceController

    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Тексты", systemImage: "books.vertical")
                }

            SearchView()
                .tabItem {
                    Label("Поиск", systemImage: "magnifyingglass")
                }

            SavedView()
                .tabItem {
                    Label("Сохранённое", systemImage: "bookmark")
                }

            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "textformat.size")
                }
        }
        .tint(SefariaStyle.green)
        .onAppear {
            let activeSettings = settings.first ?? MTReaderSettings()
            if settings.isEmpty {
                modelContext.insert(activeSettings)
                try? modelContext.save()
            }
            appearance.theme = ReaderTheme(rawValue: activeSettings.themeRawValue) ?? .system
        }
    }
}

enum SefariaStyle {
    static let green = Color(red: 0.05, green: 0.43, blue: 0.33)
    static let deepGreen = Color(red: 0.02, green: 0.26, blue: 0.21)
    static let paper = Color(red: 0.985, green: 0.975, blue: 0.945)
    static let panel = Color(red: 0.998, green: 0.993, blue: 0.972)
    static let line = Color(red: 0.83, green: 0.80, blue: 0.72)
    static let muted = Color(red: 0.42, green: 0.40, blue: 0.35)
    static let darkPaper = Color(red: 0.10, green: 0.11, blue: 0.10)
    static let darkPanel = Color(red: 0.14, green: 0.15, blue: 0.14)

    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkPaper : paper
    }

    static func panelBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkPanel : panel
    }
}

struct SefariaSectionTitle: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(SefariaStyle.green)
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .textCase(nil)
    }
}
