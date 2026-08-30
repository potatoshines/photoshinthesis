//
//  Models.swift
//  Photoshinthesis
//
//  All persisted data types live here. Kept in one file for now since
//  they're small and read together as "the data model" — split into
//  separate files later only if one of them grows complex.
//

import Foundation
import SwiftData

// MARK: - Category

enum Category: String, Codable, CaseIterable, Identifiable {
    case fitness, learning, work, creativity
    case selfCare = "self_care"
    case chores, social, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fitness: return "Fitness"
        case .learning: return "Learning"
        case .work: return "Work"
        case .creativity: return "Creativity"
        case .selfCare: return "Self Care"
        case .chores: return "Chores"
        case .social: return "Social"
        case .other: return "Other"
        }
    }

    var defaultIconName: String {
        switch self {
        case .fitness: return "figure.run"
        case .learning: return "book.fill"
        case .work: return "briefcase.fill"
        case .creativity: return "paintpalette.fill"
        case .selfCare: return "heart.fill"
        case .chores: return "house.fill"
        case .social: return "person.2.fill"
        case .other: return "sparkles"
        }
    }
}

// MARK: - Activity

@Model
final class Activity {
    @Attribute(.unique) var id: UUID
    var name: String
    var defaultPoints: Double
    var category: Category
    var iconName: String
    var colorHex: String
    var isArchived: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Event.activity)
    var events: [Event] = []

    init(
        id: UUID = UUID(),
        name: String,
        defaultPoints: Double,
        category: Category = .other,
        iconName: String? = nil,
        colorHex: String = "#4CAF50",
        isArchived: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.defaultPoints = defaultPoints
        self.category = category
        self.iconName = iconName ?? category.defaultIconName
        self.colorHex = colorHex
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}

// MARK: - Event

/// A single logged occurrence. Snapshots the activity's name/icon/color and
/// the goal that was active at logging time, so editing an Activity or
/// changing goals later never rewrites history.
@Model
final class Event {
    @Attribute(.unique) var id: UUID
    var activity: Activity?

    var activityNameSnapshot: String
    var iconSnapshot: String
    var colorHexSnapshot: String
    var categorySnapshot: Category

    var timestamp: Date
    var pointsEarned: Double
    var goalSnapshot: Double
    var notes: String?

    init(
        id: UUID = UUID(),
        activity: Activity,
        pointsEarned: Double? = nil,
        goalSnapshot: Double,
        notes: String? = nil,
        timestamp: Date = .now
    ) {
        self.id = id
        self.activity = activity
        self.activityNameSnapshot = activity.name
        self.iconSnapshot = activity.iconName
        self.colorHexSnapshot = activity.colorHex
        self.categorySnapshot = activity.category
        self.timestamp = timestamp
        self.pointsEarned = pointsEarned ?? activity.defaultPoints
        self.goalSnapshot = goalSnapshot
        self.notes = notes
    }

    /// Standalone one-time entry — no Activity is created or linked. Used
    /// for custom logs from the Home "+" sheet that shouldn't turn into a
    /// reusable template. `activity` stays nil forever for these Events.
    init(
        id: UUID = UUID(),
        customName: String,
        pointsEarned: Double,
        goalSnapshot: Double,
        notes: String? = nil,
        timestamp: Date = .now,
        iconSnapshot: String = "sparkles",
        colorHexSnapshot: String = "#9E9E9E",
        categorySnapshot: Category = .other
    ) {
        self.id = id
        self.activity = nil
        self.activityNameSnapshot = customName
        self.iconSnapshot = iconSnapshot
        self.colorHexSnapshot = colorHexSnapshot
        self.categorySnapshot = categorySnapshot
        self.timestamp = timestamp
        self.pointsEarned = pointsEarned
        self.goalSnapshot = goalSnapshot
        self.notes = notes
    }
}

// MARK: - Goals

enum GoalScope: String, Codable, CaseIterable, Identifiable {
    case day, range, month, global
    var id: String { rawValue }

    /// Higher number wins when multiple goals could apply to the same date.
    var priority: Int {
        switch self {
        case .day: return 3
        case .range: return 2
        case .month: return 1
        case .global: return 0
        }
    }
}

@Model
final class DailyGoal {
    @Attribute(.unique) var id: UUID
    var goalValue: Double
    var scope: GoalScope
    var startDate: Date
    var endDate: Date?
    var label: String?

    init(
        id: UUID = UUID(),
        goalValue: Double,
        scope: GoalScope,
        startDate: Date = .now,
        endDate: Date? = nil,
        label: String? = nil
    ) {
        self.id = id
        self.goalValue = goalValue
        self.scope = scope
        self.startDate = startDate
        self.endDate = endDate
        self.label = label
    }

    func applies(to date: Date, calendar: Calendar = .current) -> Bool {
        switch scope {
        case .global:
            return true
        case .day:
            return calendar.isDate(startDate, inSameDayAs: date)
        case .range:
            let end = endDate ?? startDate
            return calendar.isDate(startDate, inSameDayAs: date) ||
                calendar.isDate(end, inSameDayAs: date) ||
                (startDate...end).contains(date)
        case .month:
            return calendar.isDate(startDate, equalTo: date, toGranularity: .month) &&
                calendar.isDate(startDate, equalTo: date, toGranularity: .year)
        }
    }
}

// MARK: - Settings

/// Single-row settings object — there's only ever one instance (see
/// SettingsStore, which guarantees that).
@Model
final class AppSettings {
    var theme: String
    var plantType: String
    var animationsEnabled: Bool
    var defaultDailyGoal: Double

    init(
        theme: String = "system",
        plantType: String = "classic",
        animationsEnabled: Bool = true,
        defaultDailyGoal: Double = 20
    ) {
        self.theme = theme
        self.plantType = plantType
        self.animationsEnabled = animationsEnabled
        self.defaultDailyGoal = defaultDailyGoal
    }
}
