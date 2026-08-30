//
//  Services.swift
//  Photoshinthesis
//
//  All business logic lives here — the ONLY code allowed to talk to
//  SwiftData directly. Views and their state call into these; they never
//  touch ModelContext themselves beyond simple @Query reads. Grouped in one
//  file for now since each service is short; split out if one grows large.
//

import Foundation
import SwiftData

// MARK: - ActivityService

@MainActor
final class ActivityService {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func fetchActiveActivities() -> [Activity] {
        let predicate = #Predicate<Activity> { !$0.isArchived }
        let descriptor = FetchDescriptor<Activity>(predicate: predicate, sortBy: [SortDescriptor(\.name)])
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    func createActivity(
        name: String, defaultPoints: Double, category: Category,
        iconName: String? = nil, colorHex: String, aliases: [String] = []
    ) -> Activity {
        let activity = Activity(name: name, defaultPoints: defaultPoints, category: category,
                                 iconName: iconName, colorHex: colorHex, aliases: aliases)
        context.insert(activity)
        save()
        return activity
    }

    func updateActivity(
        _ activity: Activity, name: String, defaultPoints: Double, category: Category,
        iconName: String, colorHex: String, aliases: [String]
    ) {
        activity.name = name
        activity.defaultPoints = defaultPoints
        activity.category = category
        activity.iconName = iconName
        activity.colorHex = colorHex
        activity.aliases = aliases
        save()
    }

    /// Archives (soft-deletes) if the Activity has history; otherwise
    /// removes it outright since there's nothing to preserve.
    func archiveActivity(_ activity: Activity) {
        if activity.events.isEmpty {
            context.delete(activity)
        } else {
            activity.isArchived = true
        }
        save()
    }

    func findActivity(matchingAlias raw: String) -> Activity? {
        fetchActiveActivities().first { $0.matches(alias: raw) }
    }

    /// Creates a small set of starter templates for brand-new users. Only
    /// runs if there are zero activities yet, so it never overwrites or
    /// duplicates anything on later launches.
    func seedDefaultActivitiesIfNeeded() {
        guard fetchActiveActivities().isEmpty else { return }

        let starters: [(name: String, points: Double, category: Category, icon: String, color: String)] = [
            ("Gym", 3, .fitness, "figure.strengthtraining.traditional", "#E53935"),
            ("Coding", 2, .work, "chevron.left.forwardslash.chevron.right", "#1976D2"),
            ("Study", 2, .learning, "book.fill", "#8E24AA"),
            ("Laundry", 1, .chores, "washer.fill", "#607D8B"),
            ("Piano", 2, .creativity, "pianokeys", "#F57C00")
        ]

        for starter in starters {
            createActivity(
                name: starter.name, defaultPoints: starter.points, category: starter.category,
                iconName: starter.icon, colorHex: starter.color
            )
        }
    }

    private func save() { try? context.save() }
}

// MARK: - EventService

@MainActor
final class EventService {
    private let context: ModelContext
    private let goalResolver: GoalResolver

    init(context: ModelContext) {
        self.context = context
        self.goalResolver = GoalResolver(context: context)
    }

    @discardableResult
    func logEvent(activity: Activity, points: Double? = nil, notes: String? = nil, timestamp: Date = .now) -> Event {
        let goalForDay = goalResolver.goal(for: timestamp)
        let event = Event(activity: activity, pointsEarned: points, goalSnapshot: goalForDay,
                           notes: notes, timestamp: timestamp)
        context.insert(event)
        save()
        return event
    }

    /// Logs a fully standalone one-time entry — no Activity is created or
    /// touched. Use this for "custom" entries from the Home logging sheet.
    @discardableResult
    func logCustomEvent(name: String, points: Double, notes: String? = nil, timestamp: Date = .now) -> Event {
        let goalForDay = goalResolver.goal(for: timestamp)
        let event = Event(customName: name, pointsEarned: points, goalSnapshot: goalForDay,
                           notes: notes, timestamp: timestamp)
        context.insert(event)
        save()
        return event
    }

    func deleteEvent(_ event: Event) {
        context.delete(event)
        save()
    }

    /// All events logged on the same calendar day as `date`, newest first.
    func events(on date: Date) -> [Event] {
        let dayStart = date.startOfDay
        let dayEnd = dayStart.addingDays(1)
        let predicate = #Predicate<Event> { $0.timestamp >= dayStart && $0.timestamp < dayEnd }
        let descriptor = FetchDescriptor<Event>(predicate: predicate, sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func totalPoints(on date: Date) -> Double {
        events(on: date).reduce(0) { $0 + $1.pointsEarned }
    }

    private func save() { try? context.save() }
}

// MARK: - GoalResolver

/// Answers "what's the point goal for this date?" applying
/// Day > Range > Month > Global precedence. The only place this rule lives.
@MainActor
final class GoalResolver {
    private let context: ModelContext
    private let settingsStore: SettingsStore

    init(context: ModelContext) {
        self.context = context
        self.settingsStore = SettingsStore(context: context)
    }

    func goal(for date: Date) -> Double {
        let descriptor = FetchDescriptor<DailyGoal>()
        let allGoals = (try? context.fetch(descriptor)) ?? []
        let applicable = allGoals.filter { $0.applies(to: date) }
        if let best = applicable.max(by: { $0.scope.priority < $1.scope.priority }) {
            return best.goalValue
        }
        return settingsStore.fetchOrCreateSettings().defaultDailyGoal
    }

    func setGlobalDefault(_ value: Double) {
        let settings = settingsStore.fetchOrCreateSettings()
        settings.defaultDailyGoal = value
        settingsStore.save()
    }
}

// MARK: - StreakCalculator

/// A day "counts" when total points earned meet or exceed that day's goal.
/// This single rule drives both the streak badge and the plant's growth
/// pausing (spec: "missing a day simply pauses growth").
@MainActor
final class StreakCalculator {
    private let eventService: EventService
    private let goalResolver: GoalResolver

    init(context: ModelContext) {
        self.eventService = EventService(context: context)
        self.goalResolver = GoalResolver(context: context)
    }

    func goalWasMet(on date: Date) -> Bool {
        eventService.totalPoints(on: date) >= goalResolver.goal(for: date)
    }

    /// Counts backward from today while each day's goal was met. Today
    /// itself doesn't break the streak while still in progress — we only
    /// require it to already be met if `requireToday` is true.
    func currentStreak(asOf referenceDate: Date = .now, requireToday: Bool = false) -> Int {
        var streak = 0
        var cursor = referenceDate.startOfDay
        if !requireToday && !goalWasMet(on: cursor) {
            cursor = cursor.addingDays(-1)
        }
        while goalWasMet(on: cursor) {
            streak += 1
            cursor = cursor.addingDays(-1)
        }
        return streak
    }
}

// MARK: - PlantGrowthEngine

enum PlantGrowthStage: String, CaseIterable {
    case sprout, smallPlant, leafyPlant, floweringPlant, maturePlant

    var displayName: String {
        switch self {
        case .sprout: return "Sprout"
        case .smallPlant: return "Small Plant"
        case .leafyPlant: return "Leafy Plant"
        case .floweringPlant: return "Flowering Plant"
        case .maturePlant: return "Mature Plant"
        }
    }

    /// Placeholder emoji art — swap for real illustrations later without
    /// touching any other file, since everything reads through this enum.
    var emoji: String {
        switch self {
        case .sprout: return "🌱"
        case .smallPlant: return "🌿"
        case .leafyPlant: return "🍀"
        case .floweringPlant: return "🌸"
        case .maturePlant: return "🌳"
        }
    }
}

enum PlantGrowthEngine {
    private static let thresholds: [(stage: PlantGrowthStage, daysRequired: Int)] = [
        (.sprout, 0), (.smallPlant, 3), (.leafyPlant, 7), (.floweringPlant, 14), (.maturePlant, 30)
    ]

    static func stage(forStreak streak: Int) -> PlantGrowthStage {
        var current: PlantGrowthStage = .sprout
        for entry in thresholds where streak >= entry.daysRequired {
            current = entry.stage
        }
        return current
    }
    
    /// Continuous 0...1 value for scrubbing the Lottie animation, based on
    /// how far the streak is toward full maturity (the last threshold).
    /// Unlike `stage(forStreak:)`, this doesn't jump in discrete steps —
    /// it smoothly increases day by day, so the animation visibly
    /// progresses even between named stages.
    static func overallProgress(forStreak streak: Int) -> Double {
        guard let maxDays = thresholds.last?.daysRequired, maxDays > 0 else { return 0 }
        return min(Double(streak) / Double(maxDays), 1.0)
    }
}

// MARK: - SettingsStore

/// Guarantees exactly one AppSettings row exists, creating it with
/// defaults on first launch.
@MainActor
final class SettingsStore {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func fetchOrCreateSettings() -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let fresh = AppSettings()
        context.insert(fresh)
        try? context.save()
        return fresh
    }

    func save() { try? context.save() }
}
