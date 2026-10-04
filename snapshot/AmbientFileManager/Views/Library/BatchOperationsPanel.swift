import SwiftUI
import SwiftData

struct BatchOperationsPanel: View {
    let samples: [Sample]
    let tagGroups: [TagGroup]
    let vaultPath: String
    let undoManager: AppUndoManager
    let onDone: () -> Void

    @State private var batchKeyString: String? = nil
    @State private var tempoText: String = ""
    @State private var showKeyMixed = false
    @State private var showTempoMixed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(samples.count) Samples Selected")
                    .font(.headline)

                Divider()

                // Tags
                tagSection

                Divider()

                // Key
                metadataSection

                Divider()

                // Mark as processed
                if samples.contains(where: { !$0.isProcessed }) {
                    Button("Mark All as Processed") {
                        BatchOperations.markAsProcessed(samples, vaultPath: vaultPath, undoManager: undoManager)
                    }
                }
            }
            .padding()
        }
        .onAppear { loadCommonValues() }
        .onChange(of: samples.count) { _, _ in loadCommonValues() }
    }

    // MARK: - Tags

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Click to add to all. Option-click to remove from all.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if tagGroups.isEmpty {
                Text("No tag groups created.")
                    .foregroundStyle(.tertiary)
                    .font(.callout)
            } else {
                ForEach(tagGroups) { group in
                    Text("\(group.name) (\(group.code))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                    ForEach(group.tags.sorted { $0.name < $1.name }) { tag in
                        tagRow(tag)
                    }
                }
            }
        }
    }

    private func tagRow(_ tag: Tag) -> some View {
        let state = tagState(for: tag)
        return HStack {
            Image(systemName: state == .all ? "checkmark.circle.fill" : state == .some ? "minus.circle.fill" : "circle")
                .foregroundColor(state == .none ? .gray : .accentColor)
            Text(tag.name)
                .font(.callout)
            Spacer()
            Text(tag.code)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.option) {
                // Option-click: remove from all
                BatchOperations.removeTags([tag], from: samples, vaultPath: vaultPath, undoManager: undoManager)
            } else {
                // Click: add to all
                BatchOperations.applyTags([tag], to: samples, vaultPath: vaultPath, undoManager: undoManager)
            }
        }
    }

    private enum TagPresence { case all, some, none }

    private func tagState(for tag: Tag) -> TagPresence {
        let count = samples.filter { $0.tags.contains(where: { $0.id == tag.id }) }.count
        if count == samples.count { return .all }
        if count > 0 { return .some }
        return .none
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metadata")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Key").font(.caption).foregroundStyle(.secondary)
                    if showKeyMixed {
                        Text("(mixed)").font(.caption2).foregroundStyle(.orange)
                    }
                }
                HStack {
                    KeyPicker(keyString: $batchKeyString)
                    Button("Apply") {
                        BatchOperations.setKey(batchKeyString, on: samples, vaultPath: vaultPath, undoManager: undoManager)
                        showKeyMixed = false
                    }
                    .controlSize(.small)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Tempo").font(.caption).foregroundStyle(.secondary)
                        if showTempoMixed {
                            Text("(mixed)").font(.caption2).foregroundStyle(.orange)
                        }
                    }
                    TextField("BPM", text: $tempoText)
                        .textFieldStyle(.roundedBorder)
                }
                Button("Apply") {
                    let tempo = Int(tempoText.trimmingCharacters(in: .whitespaces))
                    BatchOperations.setTempo(tempo, on: samples, vaultPath: vaultPath, undoManager: undoManager)
                    showTempoMixed = false
                }
                .controlSize(.small)
            }
        }
    }

    private func loadCommonValues() {
        let keys = Set(samples.compactMap(\.key))
        if keys.count == 1, let key = keys.first {
            batchKeyString = key
            showKeyMixed = false
        } else {
            batchKeyString = nil
            showKeyMixed = keys.count > 1
        }

        let tempos = Set(samples.compactMap(\.tempo))
        if tempos.count == 1, let tempo = tempos.first {
            tempoText = String(tempo)
            showTempoMixed = false
        } else {
            tempoText = ""
            showTempoMixed = tempos.count > 1
        }
    }
}
