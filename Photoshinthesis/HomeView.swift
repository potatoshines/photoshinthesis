//
//  HomeView.swift
//  Photoshinthesis
//
//  The "Today" tab — your Page 1 sketch. Uses @Query so the view
//  auto-refreshes whenever an Event is added/deleted anywhere in the app,
//  no manual refresh logic needed.
//

import SwiftUI
import SwiftData
import UIKit

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Event.timestamp, order: .reverse) private var allEvents: [Event]

    @State private var showingLogSheet = false
    @State private var showingSettings = false
    @State private var plantTapped = false
    @State private var sparkleBurstID = 0
    @State private var plantCelebrationTrigger = 0

    private var todayEvents: [Event] {
        allEvents.filter { $0.timestamp.isSameDay(as: .now) }
    }

    private var totalPoints: Double {
        todayEvents.reduce(0) { $0 + $1.pointsEarned }
    }

    private var goal: Double {
        GoalResolver(context: context).goal(for: .now)
    }

    private var streak: Int {
        StreakCalculator(context: context).currentStreak()
    }

    private var plantStage: PlantGrowthStage {
        PlantGrowthEngine.stage(forStreak: streak)
    }

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(totalPoints / goal, 1.0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header

                    ZStack {
                        ProgressRingView(progress: progress)
                        SparkleBurstView(trigger: sparkleBurstID)
                        VStack(spacing: 4) {
                            PlantAnimationView(
                                progress: progress,
                                celebrationTrigger: plantCelebrationTrigger,
                                onCelebrationFinished: { sparkleBurstID += 1 }
                            )
                                .onTapGesture {
                                    withAnimation(.spring) { plantTapped.toggle() }
                                }
                            if plantTapped {
                                Text(plantStage.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .transition(.opacity)
                            }
                        }
                    }
                    .frame(width: 220, height: 220)

                    VStack(spacing: 4) {
                        let remaining = max(goal - totalPoints, 0)
                        if remaining > 0 {
                            Text("\(formattedPoints(totalPoints))/\(formattedPoints(goal))")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                            Text("\(formattedPoints(remaining)) points to today's goal")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(formattedPoints(totalPoints))/\(formattedPoints(goal))")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#6F8A68"))
                            Text("Today's goal complete")
                                .font(.subheadline)
                                .foregroundStyle(Color(hex: "#00386F"))
                        }
                    }

                    todaySection
                }
                .padding()
            }
            .background(
                Color(hex: "FAF9F3")
            )
            .overlay(alignment: .bottomTrailing) { addButton }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    StreakBadge(streak: streak)
                }
            }
            .onChange(of: progress) { oldValue, newValue in
                if newValue >= 1.0 && oldValue < 1.0 {
                    plantCelebrationTrigger += 1
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                LogActivitySheet()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 2) {
                Text("PHOTOSHINTHESIS")
                    .font(.custom("HelveticaNeue-CondensedBlack", size: 25))
                    .foregroundStyle(Color(hex: "#00386F"))
                    .tracking(1)
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(3)
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today")
                    .font(.custom("Cochin-Bold", size: 22))
                    .padding(.leading, 5)
                Spacer()
                Text("\(todayEvents.count) logged")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if todayEvents.isEmpty {
                Text("Nothing logged yet - tap '+' to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(todayEvents) { event in
                    TodayEventRow(event: event) {
                        withAnimation { EventService(context: context).deleteEvent(event) }
                    }
                }
                Color.clear.frame(height: 90)
            }
        }
    }

    private var addButton: some View {
        Button {
            showingLogSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color(hex: "#2E7D32")))
                .shadow(radius: 6, y: 3)
        }
        .padding()
    }

    private func formattedPoints(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.2f", value).trimmingTrailingZeros()
    }
}

// MARK: - Small reusable pieces (single-use, kept inline to limit file count)

private struct ProgressRingView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color.gray.opacity(0.15), lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color(hex: "#6F8A68"), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring, value: progress)
        }
    }
}

private struct StreakBadge: View {
    let streak: Int
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill").foregroundStyle(.orange)
            Text("\(streak)")
                .font(.subheadline.bold())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.orange.opacity(0.12)))
    }
}

private struct SparkleBurstView: View {
    let trigger: Int
    @State private var animate = false

    private let sparkles: [(x: CGFloat, y: CGFloat, delay: Double)] = [
        (-60, -40, 0.0), (60, -50, 0.05), (-70, 20, 0.1),
        (70, 30, 0.05), (0, -75, 0.15), (-30, 65, 0.1),
        (30, 70, 0.0), (0, 80, 0.2)
    ]

    var body: some View {
        ZStack {
            ForEach(Array(sparkles.enumerated()), id: \.offset) { _, sparkle in
                Image(systemName: "sparkle")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "#F4C542"))
                    .offset(x: sparkle.x, y: sparkle.y)
                    .scaleEffect(animate ? 1.2 : 0.1)
                    .opacity(animate ? 0 : 1)
                    .animation(.easeOut(duration: 0.7).delay(sparkle.delay), value: animate)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            animate = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                animate = true
            }
        }
    }
}

private struct TodayEventRow: View {
    let event: Event
    let onDelete: () -> Void
    @State private var isExpanded = false
 
    private var hasNotes: Bool {
        guard let notes = event.notes else { return false }
        return !notes.isEmpty
    }
 
    var body: some View {
        Button {
            guard hasNotes else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color(hex: event.colorHexSnapshot).opacity(0.15))
                        Image(systemName: event.iconSnapshot)
                            .foregroundStyle(Color(hex: event.colorHexSnapshot))
                    }
                    .frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.activityNameSnapshot).font(.body.weight(.medium))
                        Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if hasNotes && !isExpanded {
                            Text(event.notes ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
 
                    Spacer()
 
                    Text("+\(event.pointsEarned, specifier: "%.2g")")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
 
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
 
                // Full note only appears here once expanded, with room to wrap
                // onto multiple lines — the row grows to fit it.
                if hasNotes && isExpanded {
                    Text(event.notes ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 52) // aligns under the name, past the icon
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Activity.self, Event.self, DailyGoal.self, AppSettings.self], inMemory: true)
}
