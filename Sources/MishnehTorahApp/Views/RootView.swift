import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case library
    case search
    case saved
    case settings
}

final class AppNavigationState: ObservableObject {
    @Published var selectedTab: AppTab = .library

    func returnToLibraryRoot() {
        selectedTab = .library
        NotificationCenter.default.post(name: .returnToLibraryRoot, object: nil)
    }
}

extension Notification.Name {
    static let returnToLibraryRoot = Notification.Name("returnToLibraryRoot")
}

struct HomeNavigationButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appNavigation: AppNavigationState

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appNavigation.returnToLibraryRoot()
                    dismiss()
                } label: {
                    Image(systemName: "house")
                }
                .accessibilityLabel("На главную")
                .help("На главную")
            }
        }
    }
}

extension View {
    func homeNavigationButton() -> some View {
        modifier(HomeNavigationButtonModifier())
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \MTReaderSettings.textSize) private var settings: [MTReaderSettings]
    @EnvironmentObject private var appearance: AppearanceController
    @StateObject private var navigation = AppNavigationState()
    @State private var didStartPreparingLibrary = false
    @State private var isPreparingLibrary = false
    @State private var preparationError: String?

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            LibraryView()
                .tabItem {
                    Label("Тексты", systemImage: "books.vertical")
                }
                .tag(AppTab.library)

            SearchView()
                .tabItem {
                    Label("Поиск", systemImage: "magnifyingglass")
                }
                .tag(AppTab.search)

            SavedView()
                .tabItem {
                    Label("Сохранённое", systemImage: "bookmark")
                }
                .tag(AppTab.saved)

            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "textformat.size")
                }
                .tag(AppTab.settings)
        }
        .tint(SefariaStyle.green)
        .environmentObject(navigation)
        .overlay {
            if isPreparingLibrary {
                PreparingLibraryView()
            }
        }
        .alert("Не получилось загрузить библиотеку", isPresented: Binding(
            get: { preparationError != nil },
            set: { isPresented in
                if !isPresented {
                    preparationError = nil
                }
            }
        )) {
            Button("ОК") {
                preparationError = nil
            }
        } message: {
            Text(preparationError ?? "")
        }
        .onAppear {
            let activeSettings = settings.first ?? MTReaderSettings()
            if settings.isEmpty {
                modelContext.insert(activeSettings)
                try? modelContext.save()
            }
            appearance.theme = ReaderTheme(rawValue: activeSettings.themeRawValue) ?? .system
        }
        .task {
            guard !didStartPreparingLibrary else { return }
            didStartPreparingLibrary = true
            isPreparingLibrary = true
            do {
                try await SeedDataLoader.seedIfNeeded(context: modelContext)
                isPreparingLibrary = false
                Task { @MainActor in
                    await ContentSyncService.shared.syncNow(context: modelContext)
                }
            } catch {
                preparationError = error.localizedDescription
                isPreparingLibrary = false
            }
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active, didStartPreparingLibrary,
                  !isPreparingLibrary, preparationError == nil else { return }
            Task { @MainActor in
                await ContentSyncService.shared.syncNow(context: modelContext)
            }
        }
    }
}

struct PreparingLibraryView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(SefariaStyle.green)
                Text("Загружаю библиотеку")
                    .font(.headline)
                Text("Первый запуск с полным текстом может занять немного времени.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(22)
            .frame(maxWidth: 320)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

enum SefariaStyle {
    static let green = Color(red: 0.81, green: 0.65, blue: 0.17)
    static let deepGreen = Color(red: 0.16, green: 0.14, blue: 0.11)
    static let linkBlue = Color(red: 0.08, green: 0.35, blue: 0.82)
    static let gold = Color(red: 0.81, green: 0.65, blue: 0.17)
    static let paper = Color(red: 0.969, green: 0.953, blue: 0.914)
    static let panel = Color(red: 1.00, green: 0.992, blue: 0.965)
    static let line = Color(red: 0.82, green: 0.77, blue: 0.65)
    static let muted = Color(red: 0.47, green: 0.44, blue: 0.39)
    static let darkPaper = Color(red: 0.105, green: 0.094, blue: 0.078)
    static let darkPanel = Color(red: 0.155, green: 0.137, blue: 0.113)

    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkPaper : paper
    }

    static func panelBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkPanel : panel
    }

    static func bookmarkedBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? gold.opacity(0.18) : gold.opacity(0.13)
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
