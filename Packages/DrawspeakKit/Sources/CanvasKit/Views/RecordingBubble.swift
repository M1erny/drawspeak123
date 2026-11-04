#if canImport(UIKit)
import Accessibility
import DrawspeakCore
import SwiftUI

/// Only this leaf observes streaming text. Its dimensions are independent of zoom.
struct RecordingBubble: View {
    let workspace: Workspace
    let noteId: UUID
    let pin: CGPoint
    let bounds: CGRect

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var followedRecording = false
    @State private var expired = false
    @State private var size = CGSize(width: 280, height: 72)

    var body: some View {
        let note = workspace.note(noteId)
        let recording = workspace.activeRecording?.noteId == noteId || note?.isRecording == true
        let transcribing = note?.isTranscribing == true
        let refining = note?.refinement?.state == .refining
        let live = workspace.liveText(for: noteId)
        let text = live ?? note?.text ?? ""
        let partial = recording ? workspace.livePartialText : ""
        let busy = recording || transcribing || refining
        let visible = busy || (followedRecording && !expired)
        let origin = RecordingBubblePlacement.origin(pin: pin, bubble: size, bounds: bounds)

        Button {
            workspace.focusedNoteId = noteId
        } label: {
            HStack(alignment: .top, spacing: 6) {
                if refining {
                    Image(systemName: "sparkles")
                        .accessibilityLabel(Text("Refining", bundle: .module))
                }
                if !recording && transcribing {
                    Text("Transcribing…", bundle: .module)
                } else if text.isEmpty {
                    Text("Recording", bundle: .module)
                } else {
                    styledText(text, partial: partial)
                        .lineLimit(3)
                        .truncationMode(.head)
                }
            }
            .font(.caption)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .padding(10)
            .frame(minHeight: 44, alignment: .leading)
            .frame(width: min(280, max(1, bounds.width)), alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(reduceTransparency ? AnyShapeStyle(Theme.surface) : AnyShapeStyle(.regularMaterial))
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(text: text, recording: recording, transcribing: transcribing, refining: refining))
        .onChange(of: text) {
            guard visible, !text.isEmpty else { return }
            var announcement = AttributedString(text)
            announcement.accessibilitySpeechAnnouncementPriority = .low
            AccessibilityNotification.Announcement(announcement).post()
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .offset(x: origin.x, y: origin.y)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .accessibilityHidden(!visible)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: visible)
        .onChange(of: recording, initial: true) {
            if recording { followedRecording = true; expired = false }
        }
        .onChange(of: transcribing, initial: true) {
            if transcribing { followedRecording = true; expired = false }
        }
        .task(id: busy) {
            guard !busy, followedRecording else { return }
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            expired = true
        }
    }

    private func styledText(_ text: String, partial: String) -> Text {
        guard !partial.isEmpty, text.hasSuffix(partial) else { return Text(verbatim: text) }
        let committed = String(text.dropLast(partial.count))
        return Text("\(Text(verbatim: committed))\(Text(verbatim: partial).foregroundStyle(.secondary))")
    }

    private func accessibilityText(text: String, recording: Bool, transcribing: Bool, refining: Bool) -> String {
        if transcribing && !recording { return String(localized: "Transcribing…", bundle: .module) }
        if refining { return String(localized: "Refining", bundle: .module) + ". " + text }
        return text.isEmpty ? String(localized: "Recording", bundle: .module) : text
    }
}
#endif
