//
//  ActivitiesView.swift
//  Photoshinthesis
//
//  The "Activities" tab — your Page 2 sketch. A grid of reusable templates
//  with Edit/Delete, plus a "+ New" button. The editor sheet (create AND
//  edit share one form) lives at the bottom of this file since it's only
//  ever used from here.
//

import SwiftUI
import SwiftData

struct ActivitiesView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Activity> { !$0.isArchived }, sort: \Activity.name)
    private var activities: [Activity]

    @State private var editingActivity: Activity?
    @State private var showingEditor = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Reusable templates for activities you do")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(activities) { activity in
                            ActivityCard(activity: activity) {
                                editingActivity = activity
                                showingEditor = true
                            } onDelete: {
                                ActivityService(context: context).archiveActivity(activity)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Button {
                        editingActivity = nil
                        showingEditor = true
                    } label: {
                        Label("New", systemImage: "plus.circle.fill")
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
                .padding(.vertical)
            }
            .background(Color(hex: "#FAF9F3"))
            .navigationTitle("Activities")
            .sheet(isPresented: $showingEditor) {
                ActivityEditorView(activity: editingActivity)
            }
        }
    }
}

// MARK: - ActivityCard

private struct ActivityCard: View {
    let activity: Activity
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle().fill(Color(hex: activity.colorHex).opacity(0.15))
                    Image(systemName: activity.iconName)
                        .foregroundStyle(Color(hex: activity.colorHex))
                }
                .frame(width: 36, height: 36)

                Spacer()

                Text("\(activity.defaultPoints, specifier: "%.2g") pts")
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: activity.colorHex).opacity(0.15)))
                    .foregroundStyle(Color(hex: activity.colorHex))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name).font(.body.weight(.semibold))
                Text(activity.category.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil").font(.caption)
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash").font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - ActivityEditorView

private struct ActivityEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// nil means "creating new"; non-nil means "editing this one".
    let activity: Activity?

    @State private var name: String
    @State private var points: Double
    @State private var category: Category
    @State private var colorHex: String
    @State private var aliases: [String]
    @State private var newAlias: String = ""

    private let colorOptions = ["#4CAF50", "#2E7D32", "#1976D2", "#F57C00", "#8E24AA", "#D32F2F", "#00838F", "#5D4037"]

    init(activity: Activity?) {
        self.activity = activity
        _name = State(initialValue: activity?.name ?? "")
        _points = State(initialValue: activity?.defaultPoints ?? 1)
        _category = State(initialValue: activity?.category ?? .other)
        _colorHex = State(initialValue: activity?.colorHex ?? "#4CAF50")
        _aliases = State(initialValue: activity?.aliases ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Gym", text: $name)
                }

                Section("Points") {
                    Stepper(value: $points, in: 0...100, step: 0.5) {
                        Text("\(points, specifier: "%.2g") points")
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases) { Text($0.displayName).tag($0) }
                    }
                }

                Section("Color") {
                    HStack {
                        ForEach(colorOptions, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle().stroke(.primary, lineWidth: colorHex == hex ? 2 : 0)
                                )
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }

                Section("Aliases") {
                    ForEach(aliases, id: \.self) { alias in
                        Text(alias)
                    }
                    .onDelete { indices in aliases.remove(atOffsets: indices) }

                    HStack {
                        TextField("e.g. leg day", text: $newAlias)
                        Button("Add") {
                            let trimmed = newAlias.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            aliases.append(trimmed)
                            newAlias = ""
                        }
                    }
                }
            }
            .navigationTitle(activity == nil ? "New Activity" : "Edit Activity")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let service = ActivityService(context: context)
        if let activity {
            service.updateActivity(
                activity, name: name, defaultPoints: points, category: category,
                iconName: activity.iconName, colorHex: colorHex, aliases: aliases
            )
        } else {
            service.createActivity(
                name: name, defaultPoints: points, category: category,
                colorHex: colorHex, aliases: aliases
            )
        }
        dismiss()
    }
}

#Preview {
    ActivitiesView()
        .modelContainer(for: [Activity.self, Event.self, DailyGoal.self, AppSettings.self], inMemory: true)
}
