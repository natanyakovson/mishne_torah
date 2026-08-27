import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appearance: AppearanceController
    @Query private var settings: [MTReaderSettings]
    @State private var isImporting = false
    @State private var importMessage: String?

    private var activeSettings: MTReaderSettings {
        if let settings = settings.first {
            return settings
        }
        let created = MTReaderSettings()
        modelContext.insert(created)
        return created
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

                    Slider(value: Binding(
                        get: { activeSettings.textSize },
                        set: {
                            activeSettings.textSize = $0
                            try? modelContext.save()
                        }
                    ), in: 16...36, step: 1)

                    Text("Основа основ и столп мудростей")
                        .font(.system(size: activeSettings.textSize, design: .serif))
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

                Section("Текстовая база") {
                    Text("В приложении загружен локальный офлайн-корпус «Мишне Тора» на русском и иврите. Источник текста: m770.org.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Link("Открыть источник m770.org", destination: URL(string: "https://m770.org/maimonid.php")!)

                    Button {
                        isImporting = true
                    } label: {
                        Label("Импортировать другой JSON", systemImage: "square.and.arrow.down")
                            .foregroundStyle(SefariaStyle.green)
                    }

                    if let importMessage {
                        Text(importMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SefariaStyle.background(for: colorScheme))
            .navigationTitle("Настройки")
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    guard url.startAccessingSecurityScopedResource() else {
                        importMessage = "Нет доступа к выбранному файлу."
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }

                    let data = try Data(contentsOf: url)
                    try TextImportService.importBooks(from: data, context: modelContext)
                    importMessage = "Импорт завершён."
                } catch {
                    importMessage = "Ошибка импорта: \(error.localizedDescription)"
                }
            }
        }
    }
}
