import DrawspeakCore

/// Builds the versioned `DOMTarget` for a confirmed component selection.
nonisolated enum ComponentTargetBuilder {
    /// `nil` when the snapshot is not HTML, the selection is empty or the
    /// element has no visible outline.
    static func target(for selection: ComponentSelection, snapshot: Snapshot, renderHash: String) -> DOMTarget? {
        guard snapshot.kind == .html, snapshot.id == selection.snapshotId,
              let source = snapshot.html, let element = selection.element else { return nil }
        let bounds = element.bounds.clamped()
        guard bounds.isValid else { return nil }
        return DOMTarget(
            snapshotId: snapshot.id,
            sourceHash: source.sha256,
            renderHash: renderHash,
            renderPolicy: snapshot.renderPolicy ?? .staticNoScript,
            viewport: snapshot.viewport,
            locator: element.locator,
            label: element.label,
            tagName: element.tagName,
            ancestry: selection.chain,
            selectedDepth: selection.depth,
            layer: selection.layer,
            selectionMethod: selection.method,
            pressure: selection.pressure,
            bounds: bounds
        )
    }
}
