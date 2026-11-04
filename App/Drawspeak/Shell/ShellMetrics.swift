import SwiftUI

/// Layout constants of the app shell.
enum ShellMetrics {
    /// Margins kept around content when framing; the bottom clears the zoom menu.
    static let framingInsets = EdgeInsets(top: 16, leading: 16, bottom: 72, trailing: 16)
    /// Distance kept between a focused mark and the canvas edge.
    static let markMargin: CGFloat = 24
    /// Seconds a confirmation stays next to the zoom menu.
    static let statusDuration: Duration = .seconds(4)
    static let inspectorWidth = (min: CGFloat(300), ideal: CGFloat(360), max: CGFloat(440))
    /// Ideal heights of the fitted Settings and History sheets.
    static let settingsHeight: CGFloat = 640
    static let historyHeight: CGFloat = 520
    static let feedbackPopoverSize = CGSize(width: 440, height: 620)
}
