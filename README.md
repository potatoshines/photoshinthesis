# Photoshinthesis 🌱

A native iOS application that promotes personal productivity by encouraging users to spend more time on meaningful and productive activities instead of mindless distractions such as doom-scrolling on social media.

Users manually log activities from studying and exercising to hobbies such as learning an instrument, and assign customizable points based on their personal values. Each day's goal is to complete a set amount of points which the user sets for themselves. Photoshinthesis can also be a lightweight journal, as with every activity stored each day, users can jot down specific notes or reflect on their past history.
                                                
> **Status:** Early draft, actively in development.

## Features (current)

- **Home** — daily point ring, virtual plant that grows with your streak,today's logged activities with tap-to-expand notes
- **Activities** — reusable activity templates (name, points, category, color, icon, aliases), create/edit/archive
- **Calendar** — custom month grid with color-coded daily completion, tap a day to see its full detail inline
- **Settings** — setting default daily point goal, theme, plant type
- **Logging** — quick "+" sheet to log an activity (custom or existing template)

## Tech stack

- **SwiftUI** — declarative UI, iOS-native (not cross-platform)
- **SwiftData** — local persistence

## Project structure

```
Photoshinthesis/
├── PhotoshinthesisApp.swift   — app entry point, SwiftData container setup
├── ContentView.swift          — root tab bar (Today / Activities / Calendar)
├── Models.swift               — Activity, Event, DailyGoal, AppSettings, Category
├── Extensions.swift           — Color(hex:), Date helpers, custom font helper
├── Services.swift             — all business logic
├── HomeView.swift             — Today tab
├── LogActivitySheet.swift     — "+" logging flow
├── ActivitiesView.swift       — Activities tab + template editor
├── CalendarView.swift         — Calendar tab + embedded day detail
└── SettingsView.swift         — Settings screen
```
