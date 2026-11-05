import SwiftUI
import DrawspeakCore

public struct CommentsInspector: View {
    /// Where Filter, Select and More live: in the navigation bar above the list (sheet), or in a
    /// header row inside the inspector (a floating panel has no navigation bar of its own).
    public enum ControlsPlacement: Sendable { case toolbar, header }

    @Bindable private var workspace: Workspace
    private let onShowSource: (UUID) -> Void
    private let onSend: ((Set<UUID>) -> Void)?
    private let controlsPlacement: ControlsPlacement
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var deletionFeedback = 0
    @State private var groups: [CommentGroup] = []
    @State private var filter = CommentFilter.all
    @State private var showsDeleteConfirmation = false
    @State private var pendingIDs: Set<UUID> = []
    @State private var pendingCanvasID: UUID?
    @State private var excludedRecording = false

    /// `onAddRegion` is retained for source compatibility; the inspector no longer offers Add Region.
    /// `onSend` opens Send Feedback with the comments picked in Select mode.
    public init(workspace: Workspace, onShowSource: @escaping (UUID) -> Void, onAddRegion: @escaping () -> Void,
                onSend: ((Set<UUID>) -> Void)? = nil, controls: ControlsPlacement = .toolbar) {
        self.workspace = workspace
        self.onShowSource = onShowSource
        self.onSend = onSend
        self.controlsPlacement = controls
    }

    /// Select mode lives in the workspace, so canvas pins can toggle the same selection.
    private var editMode: EditMode { workspace.commentEditMode }
    private var selectedIDs: Set<UUID> { workspace.selectedComments }

    public var body: some View {
        switch controlsPlacement {
        case .toolbar:
            list
                // One group: the column's own controls stay together, apart from the canvas items.
                .toolbar { ToolbarItemGroup(placement: .primaryAction) { controls } }
                .tint(.primary)
        case .header:
            VStack(spacing: 0) {
                HStack(spacing: NotesMetrics.controlSpacing) {
                    Text("Comments", bundle: .module).font(.title3.bold())
                    Spacer(minLength: 0)
                    controls
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .frame(minHeight: Theme.minTarget)
                list
            }
            .tint(.primary)
        }
    }

    /// Changes in what the active recording has heard; the open comment grows with it.
    private var liveGrowth: Int {
        guard let id = workspace.activeRecording?.noteId else { return 0 }
        return (workspace.liveText(for: id)?.count ?? 0) + (workspace.note(id)?.text.count ?? 0)
    }

    private var list: some View {
        ScrollViewReader { scroll in
            List(selection: editMode.isEditing ? $workspace.selectedComments : nil) {
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
                            .selectionDisabled(!editMode.isEditing)
                            .transition(reduceMotion ? .identity : .opacity)
                        }
                    } header: { Text(group.title) }
                }
            }
            .listStyle(.insetGrouped)
            // Selected rows and controls use the app's action color; black selection read as an error state.
            .tint(Theme.action)
            // The selection bar belongs to the Comments column, not to the whole window's bottom bar.
            .safeAreaBar(edge: .bottom) {
                if editMode.isEditing {
                    CommentSelectionBar(
                        selectedCount: selectedIDs.count, deletableCount: selectedDeletable.count,
                        allSelected: allVisibleSelected, canSelectAll: !filteredNotes.isEmpty, canSend: onSend != nil,
                        onToggleAll: toggleSelectAll, onSend: sendSelection, onDelete: deleteSelection
                    )
                }
            }
            .environment(\.editMode, $workspace.commentEditMode)
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
            .onChange(of: filter) { refreshGroups() }
            .onChange(of: workspace.currentCanvasId) {
                filter = .all
                showsDeleteConfirmation = false
            }
            .onChange(of: workspace.activeRecording?.noteId) { refreshGroups() }
            .task(id: workspace.focusedNoteId) {
                // Let the selected row expand before positioning it.
                await Task.yield()
                guard !Task.isCancelled, !editMode.isEditing, let id = workspace.focusedNoteId else { return }
                scroll.scrollTo(id, anchor: .center)
            }
            // The comment being transcribed grows while the person speaks; keep its end in view
            // so the newest words never slide below the column.
            .onChange(of: liveGrowth) {
                guard !editMode.isEditing, let id = workspace.activeRecording?.noteId,
                      id == workspace.focusedNoteId else { return }
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                    scroll.scrollTo(id, anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder private var controls: some View {
        CommentFilterMenu(canvas: workspace.currentCanvas, notes: workspace.visibleNotes(), selection: $filter)
        Button(action: toggleSelection) {
            if editMode.isEditing { Text("Done", bundle: .module) }
            else { Text("Select", bundle: .module) }
        }
        .disabled(groups.isEmpty && !editMode.isEditing)
        Menu {
            Toggle(isOn: $workspace.showsSentNotes) { Text("Show Sent", bundle: .module) }
            Button(role: .destructive, action: prepareDeleteAll) {
                Text("Delete All Comments…", bundle: .module)
            }
            .disabled(deletableIDs.isEmpty)
        } label: {
            Label { Text("More", bundle: .module) } icon: { Image(systemName: "ellipsis") }
        }
        .labelStyle(.iconOnly)
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
        if let selection = workspace.commentSelection {
            let visibleIDs = Set(visible.map(\.id))
            if !selection.isSubset(of: visibleIDs) { workspace.commentSelection = selection.intersection(visibleIDs) }
        }
    }

    private func toggleSelection() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            workspace.commentSelection = editMode.isEditing ? nil : []
        }
    }

    private var allVisibleSelected: Bool {
        let ids = Set(filteredNotes.map(\.id))
        return !ids.isEmpty && ids.isSubset(of: selectedIDs)
    }

    private func toggleSelectAll() {
        let ids = Set(filteredNotes.map(\.id))
        workspace.commentSelection = allVisibleSelected ? selectedIDs.subtracting(ids) : selectedIDs.union(ids)
    }

    private var selectedDeletable: Set<UUID> { selectedIDs.intersection(deletableIDs) }

    private func deleteSelection() {
        let ids = selectedDeletable
        delete(ids, canvasID: workspace.currentCanvasId)
        workspace.commentSelection = selectedIDs.subtracting(ids)
    }

    private func sendSelection() {
        let ids = selectedIDs
        workspace.commentSelection = nil
        onSend?(ids)
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
        if workspace.commentSelection != nil { workspace.commentSelection = [] }
    }

    private func delete(_ ids: Set<UUID>, canvasID: UUID?) {
        guard !ids.isEmpty, let canvasID else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            workspace.deleteNotes(ids, canvasId: canvasID)
            deletionFeedback += 1
        }
    }

}

#Preview { NavigationStack { CommentsInspector(workspace: NotesPreview.workspace(), onShowSource: { _ in }, onAddRegion: {}).navigationTitle("Comments") } }
