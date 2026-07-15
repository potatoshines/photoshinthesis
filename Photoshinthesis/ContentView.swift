//
//  ContentView.swift
//  Photoshinthesis
//
//  The root tab bar — Today, Activities, Calendar. Settings isn't a tab;
//  it's reached via the gear icon on Home, per your sketch's hamburger icon.
//
 
import SwiftUI
import SwiftData
 
struct ContentView: View {
    @Environment(\.modelContext) private var context
 
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Today", systemImage: "leaf.fill") }
 
            ActivitiesView()
                .tabItem { Label("Activities", systemImage: "figure.run") }
 
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
        }
        .tint(Color(hex: "#2E7D32"))
        .onAppear {
            // Runs once ever — seedDefaultActivitiesIfNeeded() checks for
            // zero existing activities first, so this is a no-op on every
            // launch after the first.
            ActivityService(context: context).seedDefaultActivitiesIfNeeded()
        }
    }
}
 
#Preview {
    ContentView()
        .modelContainer(for: [Activity.self, Event.self, DailyGoal.self, AppSettings.self], inMemory: true)
}
