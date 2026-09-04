import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appearance: AppearanceController
    @Query private var settings: [MTReaderSettings]
    @State private var isImportingFont = false
    @State private var fontImportMessage: String?
    @State private var navigationResetID = UUID()

    private static let fontContentTypes: [UTType] = [
        UTType(filenameExtension: "ttf"),
        UTType(filenameExtension: "otf")
    ].compactMap { $0 }

    private var activeSettings: MTReaderSettings {
        if let settings = settings.first {
            return settings
        }
        let created = MTReaderSettings()
        modelContext.insert(created)
        return created
    }

    private var activeFont: ReaderFont {
        ReaderFont(rawValue: activeSettings.readerFontRawValue ?? "") ?? .times
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Текст") {
                    Picker("Язык чтения", selection: Binding(
                        get: { ReaderLanguage(rawValue: activeSettings.readerLanguageRawValue) ?? .russian },
                        set: { language in
                            activeSettings.readerLanguageRawValue = language.rawValue
                            try? modelContext.save()
                        }
                    )) {
                        ForEach(ReaderLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Шрифт", selection: Binding(
                        get: { activeFont },
                        set: { font in
                            activeSettings.readerFontRawValue = font.rawValue
                            try? modelContext.save()
                        }
                    )) {
                        ForEach(ReaderFont.allCases) { font in
                            Text(title(for: font)).tag(font)
                        }
                    }

                    Button {
                        isImportingFont = true
                    } label: {
                        Label("Загрузить свой шрифт", systemImage: "textformat")
                            .foregroundStyle(SefariaStyle.green)
                    }

                    if let fontImportMessage {
                        Text(fontImportMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: Binding(
                        get: { activeSettings.textSize },
                        set: {
                            activeSettings.textSize = $0
                            try? modelContext.save()
                        }
                    ), in: 16...36, step: 1)

                    Text("Основа основ и столп мудростей")
                        .font(activeFont.font(size: activeSettings.textSize, customName: activeSettings.customFontName))
                        .padding(.vertical, 10)
                        .foregroundStyle(SefariaStyle.deepGreen)
                }

                Section("Тема") {
                    Picker("Оформление", selection: Binding(
                        get: { ReaderTheme(rawValue: activeSettings.themeRawValue) ?? .system },
                        set: { theme in
                            activeSettings.themeRawValue = theme.rawValue
                            appearance.theme = theme
                            try? modelContext.save()
                        }
                    )) {
                        ForEach(ReaderTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Цикл чтения") {
                    Picker("Рамбам", selection: Binding(
                        get: { ReadingCycle(rawValue: activeSettings.readingCycleRawValue ?? "") ?? .none },
                        set: { cycle in
                            activeSettings.readingCycleRawValue = cycle.rawValue
                            try? modelContext.save()
                        }
                    )) {
                        ForEach(ReadingCycle.selectableCases) { cycle in
                            Text(cycle.title).tag(cycle)
                        }
                    }
                }

                Section("Текстовая база") {
                    Text("В приложении загружен локальный офлайн-корпус «Мишне Тора» на русском и иврите. Источник текста: m770.org.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Link("Открыть источник m770.org", destination: URL(string: "https://m770.org/maimonid.php")!)
                        .foregroundStyle(SefariaStyle.linkBlue)
                }
            }
            .scrollContentBackground(.hidden)
            .background(SefariaStyle.background(for: colorScheme))
            .navigationTitle("Настройки")
            .homeNavigationButton()
            .onAppear {
                FontInstallService.registerStoredFont(fileName: activeSettings.customFontFileName)
            }
            .fileImporter(isPresented: $isImportingFont, allowedContentTypes: Self.fontContentTypes) { result in
                importFont(result)
            }
        }
        .id(navigationResetID)
        .onReceive(NotificationCenter.default.publisher(for: .returnToLibraryRoot)) { _ in
            navigationResetID = UUID()
        }
    }

    private func title(for font: ReaderFont) -> String {
        if font == .custom, let displayName = activeSettings.customFontDisplayName, !displayName.isEmpty {
            return displayName
        }
        return font.title
    }

    private func importFont(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let installed = try FontInstallService.installFont(from: url)
            activeSettings.customFontName = installed.postScriptName
            activeSettings.customFontDisplayName = installed.displayName
            activeSettings.customFontFileName = installed.fileName
            activeSettings.readerFontRawValue = ReaderFont.custom.rawValue
            try? modelContext.save()
            fontImportMessage = "Шрифт выбран: \(installed.displayName)"
        } catch {
            fontImportMessage = "Не удалось загрузить шрифт: \(error.localizedDescription)"
        }
    }
}
