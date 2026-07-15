//
//  Extensions.swift
//  Photoshinthesis
//
//  Small, reusable helpers with no dependency on Models or Services.
//

import SwiftUI

// MARK: - Color from hex

extension Color {
    /// Creates a Color from a hex string like "#4CAF50". Falls back to
    /// gray if malformed, rather than crashing.
    init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&rgb), hexString.count == 6 else {
            self = .gray
            return
        }
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Date helpers

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    func isSameDay(as other: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(self, inSameDayAs: other)
    }

    func startOfMonth(calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    func addingDays(_ days: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: self) ?? self
    }

    func addingMonths(_ months: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: months, to: self) ?? self
    }
}

// MARK: - String formatting
 
extension String {
    /// Strips trailing zeros (and a dangling decimal point) from a
    /// formatted number string, e.g. "2.50" → "2.5", "3.00" → "3".
    /// No access modifier here (defaults to internal) so every file in
    /// the app can use it — unlike a `private extension`, which is
    /// locked to the single file it's declared in.
    func trimmingTrailingZeros() -> String {
        var result = self
        while result.hasSuffix("0") { result.removeLast() }
        if result.hasSuffix(".") { result.removeLast() }
        return result
    }
}
