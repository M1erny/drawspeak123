#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

struct VersionMenuRow: View {
    let entry: VersionMenuEntry
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Environment(\.timeZone) private var timeZone
    var body: some View {
        let date = entry.capturedAt.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened,
                                                            locale: locale, calendar: calendar, timeZone: timeZone))
        Text("\(entry.title) · \(date)", bundle: .module, comment: "Version title and capture date/time.")
    }
}
#endif
