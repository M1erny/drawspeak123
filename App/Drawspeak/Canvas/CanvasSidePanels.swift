import DrawspeakCore
import NotesKit
import SwiftUI

/// Recording bar, note inspector, voice notices and status banners.
struct CanvasSidePanels: View {
    let workspace: Workspace
    @Binding var banner: CanvasBanner?
    let onShowSource: (UUID) -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                Spacer()
                if let noteId = workspace.focusedNoteId, workspace.note(noteId) != nil {
                    NoteInspector(workspace: workspace, noteId: noteId, onShowSource: onShowSource) {
                        workspace.focusedNoteId = nil
                    }
                    .frame(maxWidth: 380)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.top, 72)
            .padding(.horizontal, 16)

            Spacer()

            VStack(spacing: 8) {
                if let banner {
                    BannerView(banner: banner) { self.banner = nil }
                        .task(id: banner.id) {
                            try? await Task.sleep(for: .seconds(banner.isError ? 12 : 5))
                            if self.banner?.id == banner.id { self.banner = nil }
                        }
                }
                if let issue = workspace.voiceIssue {
                    VoicePermissionNotice(issue: issue, onOpenSettings: onOpenSettings) {
                        workspace.clearVoiceIssue()
                    }
                    .frame(maxWidth: 480)
                }
                if workspace.activeRecording != nil {
                    RecordingBar(workspace: workspace)
                        .frame(maxWidth: 480)
                }
            }
            .padding(.bottom, 84)
            .padding(.horizontal, 16)
        }
        .animation(.snappy, value: workspace.focusedNoteId)
    }
}
