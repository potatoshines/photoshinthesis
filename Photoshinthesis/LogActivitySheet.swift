//
//  LogActivitySheet.swift
//  Photoshinthesis
//
//  Presented from the "+" button on Home. Two modes: pick an existing
//  Activity, or type a new one-time name. Custom entries are logged as
//  standalone Events (see Event's `customName` initializer) and never
//  create an Activity — they stay unique to that day. The only way to
//  create a reusable template is the Activities tab.
//

import SwiftUI
import SwiftData

struct LogActivitySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Activity> { !$0.isArchived }, sort: \Activity.name)
    private var activities: [Activity]

    private enum Mode: String, CaseIterable, Identifiable {
        case existing = "Existing"
        case custom = "Custom"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .existing
    @State private var selectedActivity: Activity?
    @State private var customName: String = ""
    @State private var points: Double = 1
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if mode == .existing {
                    Section("Activity") {
                        if activities.isEmpty {
                            Text("No activities yet — create one in the Activities tab, or switch to Custom.")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Activity", selection: $selectedActivity) {
                                Text("Choose one").tag(Activity?.none)
                                ForEach(activities) { activity in
                                    Text(activity.name).tag(Activity?.some(activity))
                                }
                            }
                            .onChange(of: selectedActivity) { _, newValue in
                                if let newValue { points = newValue.defaultPoints }
                            }
                        }
                    }
                } else {
                    Section("New Activity Name") {
                        TextField("e.g. Piano practice", text: $customName)
                    }
                }

                Section("Points") {
                    HStack {
                        TextField("Points", value: $points, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                        Stepper("", value: $points, in: 0...100, step: 0.5)
                            .labelsHidden()
                    }
                }

                Section("Notes (optional)") {
                    TextField("What did you do?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log Activity")
            .keyboardDismissButton()
            .dismissKeyboardOnOutsideTap()
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        mode == .existing ? selectedActivity != nil : !customName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        let eventService = EventService(context: context)

        switch mode {
        case .existing:
            guard let activity = selectedActivity else { return }
            eventService.logEvent(activity: activity, points: points, notes: notes.isEmpty ? nil : notes)

        case .custom:
            // Deliberately does NOT touch ActivityService — a one-time
            // custom log stays unique to today and never becomes a
            // reusable template. The only way to create a template is
            // the Activities tab.
            eventService.logCustomEvent(name: customName, points: points, notes: notes.isEmpty ? nil : notes)
        }

        dismiss()
    }
}

#Preview {
    LogActivitySheet()
        .modelContainer(for: [Activity.self, Event.self, DailyGoal.self, AppSettings.self], inMemory: true)
}
