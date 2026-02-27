import SwiftUI

struct GeneralSettingsSection: View {

    @ObservedObject var vm: SettingsViewModel
    @ObservedObject var themeManager: ThemeManager

    var body: some View {
        Section("Appearance") {
            Picker("Theme", selection: $vm.theme) {
                ForEach(AppTheme.allCases, id: \.self) { t in Text(t.label).tag(t) }
            }
            .pickerStyle(.segmented)
            .onChange(of: vm.theme) { _, t in
                themeManager.colorScheme = t
            }

            // Accent colors
            VStack(alignment: .leading, spacing: 8) {
                Text("Accent Color")
                    .font(.subheadline)
                HStack(spacing: 12) {
                    ForEach(ACCENT_COLORS) { option in
                        Button {
                            vm.accentColor = option.id
                            themeManager.accentColorId = option.id
                            Haptics.selection()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.accentPreset(option.id))
                                    .frame(width: 30, height: 30)
                                if vm.accentColor == option.id {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Font Size")
                        .font(.subheadline)
                    Spacer()
                    Text(vm.fontSize.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Picker("Font Size", selection: $vm.fontSize) {
                    ForEach(AppFontSize.allCases, id: \.self) { s in Text(s.label).tag(s) }
                }
                .pickerStyle(.segmented)
                .onChange(of: vm.fontSize) { _, s in
                    themeManager.fontSize = s
                }
                Text("Controls the size of text throughout the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle("High Contrast", isOn: $vm.highContrast)
                    .onChange(of: vm.highContrast) { _, v in
                        themeManager.highContrast = v
                    }
                Text("Increases text weight for improved readability.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Section("Behaviour") {
            Picker("AI Persona", selection: $vm.persona) {
                ForEach(PersonaType.allCases, id: \.self) { p in Text(p.label).tag(p) }
            }

            Picker("Chat Memory", selection: $vm.chatMemory) {
                ForEach(ChatMemoryMode.allCases, id: \.self) { m in Text(m.label).tag(m) }
            }

            Picker("Language", selection: $vm.language) {
                ForEach(AppLanguage.allCases, id: \.self) { l in Text(l.label).tag(l.rawValue) }
            }

            Toggle("Auto-extract memories", isOn: $vm.autoExtract)
            Toggle("Show memory indicators", isOn: $vm.showMemoryIndicators)
        }

    }
}
