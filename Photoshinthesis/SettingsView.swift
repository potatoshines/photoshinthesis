//
//  SettingsView.swift
//  Photoshinthesis
//
//  Reached via the gear icon on Home. One screen, per your instruction to
//  keep this simple for the draft — theme, animations, plant type, and the
//  global default daily goal all live here.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var defaultGoal: Double = 20
    @State private var animationsEnabled: Bool = true
    @State private var theme: String = "system"
    @State private var plantType: String = "classic"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Current default is \(Int(defaultGoal)) points")
                        .foregroundStyle(.secondary)
                    Stepper(value: $defaultGoal, in: 1...200, step: 1) {
                        Text("New default: \(Int(defaultGoal)) points")
                    }
                    Text("This sets the goal for today and future days. It doesn't affect goals already set for specific days, ranges, or months.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Daily Goal")
                }

                Section("Appearance") {
                    Picker("Theme", selection: $theme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    Toggle("Animations", isOn: $animationsEnabled)
                }

                Section("Plant") {
                    Picker("Plant Type", selection: $plantType) {
                        Text("Classic").tag("classic")
                    }
                    .disabled(true)
                    Text("More plant types coming soon.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        let settings = SettingsStore(context: context).fetchOrCreateSettings()
        defaultGoal = settings.defaultDailyGoal
        animationsEnabled = settings.animationsEnabled
        theme = settings.theme
        plantType = settings.plantType
    }

    private func save() {
        let store = SettingsStore(context: context)
        let settings = store.fetchOrCreateSettings()
        settings.animationsEnabled = animationsEnabled
        settings.theme = theme
        settings.plantType = plantType
        store.save()

        GoalResolver(context: context).setGlobalDefault(defaultGoal)
        dismiss()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Activity.self, Event.self, DailyGoal.self, AppSettings.self], inMemory: true)
}
