import SwiftUI
import DrawspeakCore

struct CommentStatusSymbol: View {
    let note: Note
    var body: some View {
        if note.isRecording {
            Image(systemName: "mic.fill").accessibilityLabel(Text("Recording", bundle: .module))
        } else if note.isTranscribing {
            Image(systemName: "waveform").accessibilityLabel(Text("Transcribing…", bundle: .module))
        } else if note.recordings.contains(where: { recording in
            switch recording.state { case .failed, .saveFailed, .interrupted: true; default: false }
        }) {
            Image(systemName: "exclamationmark.triangle").accessibilityLabel(Text("Recording failed", bundle: .module))
        }
    }
}
