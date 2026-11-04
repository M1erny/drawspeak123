import SwiftUI
import DrawspeakCore

struct FeedbackNoteRow: View {
    let note: Note
    let reason: String?
    @Binding var selection: Set<UUID>
    @State private var included = false
    var body: some View {
        Toggle(isOn: $included) {
            VStack(alignment: .leading) {
                Text("\(note.ordinal). \(note.trimmedText)")
                if let reason { Text("Comment \(note.ordinal): \(reason) — deselect to send the rest").font(.caption).foregroundStyle(.red) }
            }
        }
        .toggleStyle(FeedbackCheckboxStyle())
        .frame(minHeight: 44)
        .onAppear { included = selection.contains(note.id) }
        .onChange(of: included) { if included { selection.insert(note.id) } else { selection.remove(note.id) } }
        .onChange(of: selection) { included = selection.contains(note.id) }
    }
}
