import SwiftUI
import DrawspeakCore

public struct CommentsInspector: View {
    @Bindable private var workspace: Workspace
    private let onShowSource: (UUID) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var deletionFeedback = 0
    @State private var groups: [CommentGroup] = []
    @State private var filter = CommentFilter.all
    @State private var editMode = EditMode.inactive
    @State private var selectedIDs: Set<UUID> = []
    @State private var showsDeleteConfirmation = false
    @State private var pendingIDs: Set<UUID> = []
    @State private var pendingCanvasID: UUID?
    @State private var excludedRecording = false

    /// `onAddRegion` is retained for source compatibility; the inspector no longer offers Add Region.
    public init(workspace: Workspace, onShowSource: @escaping (UUID) -> Void, onAddRegion: @escaping () -> Void) {
        self.workspace = workspace
        self.onShowSource = onShowSource
    }

    public var body: some View {
        ScrollViewReader { scroll in
            List(selection: editMode.isEditing ? $selectedIDs : nil) {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.notes) { note in
                            VStack(alignment: .leading) {
                                if editMode.isEditing {
                                    CommentSelectionRow(workspace: workspace, note: note)
                                } else {
                                    CommentInspectorRow(workspace: workspace, note: note, onShowSource: onShowSource) {
                                        deletionFeedback += 1
                                    }
                                }
                            }
                            .tag(note.id)
                            .id(note.id)
                            .selectionDisabled(!editMode.isEditing || !canDelete(note))
                            .transition(reduceMotion ? .identity : .opacity)
                        }
                    } header: { Text(group.title) }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, $editMode)
            .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: groups.map { $0.notes.map(\.id) })
            // HIG: “Make sure all feedback is accessible.” Status text remains visible without effects.
            .sensoryFeedback(.selection, trigger: workspace.activeRecording?.recordingId) { _, _ in !reduceMotion }
            .sensoryFeedback(.impact(weight: .light), trigger: deletionFeedback) { _, _ in !reduceMotion }
            .overlay {
                if groups.isEmpty {
                    ContentUnavailableView {
                        Label { Text("No Comments", bundle: .module) } icon: { Image(systemName: "text.bubble") }
                    } description: { Text("Draw on a screen to add one.", bundle: .module) }
                }
            }
            .onChange(of: workspace.currentCanvas, initial: true) { _, canvas in
                refreshGroups()
                if let id = workspace.focusedNoteId, canvas?.notes.contains(where: { $0.id == id }) != true {
                    workspace.focusedNoteId = nil
                }
            }
            .onChange(of: workspace.showsSentNotes) {
                refreshGroups()
            }
            .onChange(of: filter) { refreshGroups(); selectedIDs.removeAll() }
            .onChange(of: workspace.currentCanvasId) {
                filter = .all
                selectedIDs.removeAll()
                editMode = .inactive
                showsDeleteConfirmation = false
            }
            .onChange(of: workspace.activeRecording?.noteId) { refreshGroups() }
            .task(id: workspace.focusedNoteId) {
                // Let the selected row expand before positioning it.
                await Task.yield()
                guard !Task.isCancelled, !editMode.isEditing, let id = workspace.focusedNoteId else { return }
                scroll.scrollTo(id, anchor: .center)
            }
        }
        .navigationTitle(Text("Comments", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                CommentFilterMenu(canvas: workspace.currentCanvas, notes: workspace.visibleNotes(), selection: $filter)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: toggleSelection) {
                    if editMode.isEditing { Text("Done", bundle: .module) }
                    else { Text("Select", bundle: .module) }
                }
                .disabled(groups.isEmpty && !editMode.isEditing)
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Toggle(isOn: $workspace.showsSentNotes) { Text("Show Sent", bundle: .module) }
                    Button(role: .destructive, action: prepareDeleteAll) {
                        Text("Delete All Comments…", bundle: .module)
                    }
                    .disabled(deletableIDs.isEmpty)
                } label: {
                    Label { Text("More", bundle: .module) } icon: { Image(systemName: "ellipsis") }
                }
                // Anchor the confirmation to the visible menu control on iPad.
                .confirmationDialog(
                    Text("Delete ^[\(pendingIDs.count) Comments](inflect: true)", bundle: .module),
                    isPresented: $showsDeleteConfirmation, titleVisibility: .visible
                ) {
                    Button(role: .destructive, action: confirmDeleteAll) {
                        Text("Delete ^[\(pendingIDs.count) Comments](inflect: true)", bundle: .module)
                    }
                    Button(role: .cancel) { } label: { Text("Cancel", bundle: .module) }
                } message: {
                    if excludedRecording {
                        Text("Recording comments are excluded. Stop recording to delete them.", bundle: .module)
                    }
                }
            }
            if editMode.isEditing {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(action: selectAll) { Text("Select All", bundle: .module) }
                        .disabled(deletableIDs.isEmpty)
                    Spacer()
                    Button(role: .destructive, action: deleteSelection) {
                        Text("Delete ^[\(selectedIDs.count) Comments](inflect: true)", bundle: .module)
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
        }
        .tint(.primary)
    }

    private var filteredNotes: [Note] {
        workspace.visibleNotes().filter { filter.includes($0, canvas: workspace.currentCanvas) }
    }

    private var deletableIDs: Set<UUID> { Set(filteredNotes.filter(canDelete).map(\.id)) }

    private func canDelete(_ note: Note) -> Bool {
        !note.isRecording && workspace.activeRecording?.noteId != note.id
    }

    private func refreshGroups() {
        let visible = workspace.visibleNotes()
        if filter != .all && !visible.contains(where: { filter.includes($0, canvas: workspace.currentCanvas) }) {
            filter = .all
        }
        groups = CommentGroup.make(workspace.currentCanvas, notes: filteredNotes)
        selectedIDs.formIntersection(deletableIDs)
    }

    private func toggleSelection() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            editMode = editMode.isEditing ? .inactive : .active
            selectedIDs.removeAll()
        }
    }

    private func selectAll() { selectedIDs = deletableIDs }

    private func deleteSelection() {
        delete(selectedIDs.intersection(deletableIDs), canvasID: workspace.currentCanvasId)
        selectedIDs.removeAll()
    }

    private func prepareDeleteAll() {
        pendingIDs = deletableIDs
        pendingCanvasID = workspace.currentCanvasId
        excludedRecording = filteredNotes.contains { !canDelete($0) }
        showsDeleteConfirmation = true
    }

    private func confirmDeleteAll() {
        guard let canvasID = pendingCanvasID, canvasID == workspace.currentCanvasId else { return }
        // Capture may have started while the dialog was open.
        let safeIDs = Set(workspace.visibleNotes().filter(canDelete).map(\.id))
        delete(pendingIDs.intersection(safeIDs), canvasID: canvasID)
        selectedIDs.removeAll()
    }

    private func delete(_ ids: Set<UUID>, canvasID: UUID?) {
        guard !ids.isEmpty, let canvasID else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            workspace.deleteNotes(ids, canvasId: canvasID)
            deletionFeedback += 1
        }
    }

}

#Preview { NavigationStack { CommentsInspector(workspace: NotesPreview.workspace(), onShowSource: { _ in }, onAddRegion: {}) } }
