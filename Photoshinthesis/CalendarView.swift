//
//  CalendarView.swift
//  Photoshinthesis
//
//  The "Calendar" tab. A custom month grid (not Apple's default calendar
//  UI, per spec) defaulting to today, with the selected day's detail
//  embedded below the grid on the same scrollable page.
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Query private var allEvents: [Event]

    @State private var displayedMonth: Date = Date.now.startOfMonth()
    @State private var selectedDate: Date = .now

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    monthHeader
                    weekdayHeader
                    dayGrid

                    if !selectedDate.isSameDay(as: .now) {
                        Button("Go back to today") {
                            withAnimation {
                                displayedMonth = Date.now.startOfMonth()
                                selectedDate = .now
                            }
                        }
                        .font(.subheadline)
                        .transition(.opacity)
                    }

                    Divider()

                    DayDetailSection(date: selectedDate)
                }
                .padding()
            }
            .background(Color(hex: "#FAF9F3"))
            .navigationTitle("Your Calendar")
        }
    }

    private var monthHeader: some View {
        HStack {
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.title3.bold())
            Spacer()
            Button { shiftMonth(by: -1) } label: { Image(systemName: "chevron.left") }
            Button { shiftMonth(by: 1) } label: { Image(systemName: "chevron.right") }
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(Calendar.current.veryShortWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        let days = daysToDisplay()
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(days, id: \.self) { day in
                if let day {
                    DayCellView(
                        date: day,
                        isSelected: day.isSameDay(as: selectedDate),
                        totalPoints: totalPoints(on: day),
                        goal: GoalResolver(context: context).goal(for: day)
                    )
                    .onTapGesture { withAnimation { selectedDate = day } }
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    private func totalPoints(on date: Date) -> Double {
        allEvents.filter { $0.timestamp.isSameDay(as: date) }.reduce(0) { $0 + $1.pointsEarned }
    }

    private func shiftMonth(by delta: Int) {
        withAnimation { displayedMonth = displayedMonth.addingMonths(delta) }
    }

    /// Builds a 7-column grid: leading blanks so day 1 lands on the right
    /// weekday, then every day in the month.
    private func daysToDisplay() -> [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: displayedMonth) - 1 // 0-indexed
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for dayNumber in range {
            if let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: displayedMonth) {
                days.append(date)
            }
        }
        return days
    }
}

// MARK: - DayCellView

private struct DayCellView: View {
    let date: Date
    let isSelected: Bool
    let totalPoints: Double
    let goal: Double

    /// gray = nothing logged, light green = partial, green = goal met.
    private var fillColor: Color {
        if totalPoints <= 0 { return Color.gray.opacity(0.12) }
        if totalPoints >= goal { return Color(hex: "#4CAF50") }
        return Color(hex: "#A5D6A7")
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.subheadline.weight(.semibold))
            if totalPoints > 0 {
                Text("\(Int(totalPoints))/\(Int(goal))")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(RoundedRectangle(cornerRadius: 10).fill(fillColor))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.primary, lineWidth: isSelected ? 2 : 0)
        )
    }
}

// MARK: - DayDetailSection

private struct DayDetailSection: View {
    let date: Date
    @Environment(\.modelContext) private var context

    private var events: [Event] {
        EventService(context: context).events(on: date)
    }
    private var totalPoints: Double {
        events.reduce(0) { $0 + $1.pointsEarned }
    }
    private var goal: Double {
        GoalResolver(context: context).goal(for: date)
    }
    private var completionPercent: Int {
        guard goal > 0 else { return 0 }
        return Int(min(totalPoints / goal, 1.0) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.headline)

            HStack {
                Text("\(Int(totalPoints))/\(Int(goal)) points")
                    .font(.subheadline)
                Text("(\(completionPercent)%)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(events.count) logged")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if events.isEmpty {
                Text("Nothing logged this day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(events) { event in
                    CalendarEventRow(event: event)
                }
            }
        }
    }
}

// MARK: - CalendarEventRow

/// One event line inside Day Detail. Tap to expand/collapse its note —
/// same interaction as TodayEventRow on Home, so the behavior feels
/// consistent everywhere a note can be long.
private struct CalendarEventRow: View {
    let event: Event
    @State private var isExpanded = false

    private var hasNotes: Bool {
        guard let notes = event.notes else { return false }
        return !notes.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: event.iconSnapshot)
                    .foregroundStyle(Color(hex: event.colorHexSnapshot))
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.activityNameSnapshot).font(.subheadline.weight(.medium))
                    if hasNotes && !isExpanded {
                        Text(event.notes ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("+\(event.pointsEarned, specifier: "%.2g")")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }

            if hasNotes && isExpanded {
                Text(event.notes ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 32)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            guard hasNotes else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: [Activity.self, Event.self, DailyGoal.self, AppSettings.self], inMemory: true)
}
