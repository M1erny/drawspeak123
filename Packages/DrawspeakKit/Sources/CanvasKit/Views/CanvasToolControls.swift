#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// Tool buttons suitable for a native ToolbarItemGroup or Pencil popover.
public struct CanvasToolControls: View {
    @Binding private var tool: CanvasTool
    public init(tool: Binding<CanvasTool>) { _tool = tool }

    public var body: some View {
        ForEach(CanvasTool.allCases) { item in
            ToolButton(tool: item, isSelected: item == tool) { tool = item }
        }
    }
}
#endif
