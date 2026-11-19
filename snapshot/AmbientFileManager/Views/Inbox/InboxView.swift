import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Sample> { !$0.isProcessed }, sort: \Sample.name)
    private var unprocessedSamples: [Sample]
    @Query(sort: \TagGroup.name) private var tagGroups: [TagGroup]

    @State private var selection = Set<PersistentIdentifier>()
    @State private var editingSample: Sample?
    @State private var showMarkProcessedConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            if unprocessedSamples.isEmpty {
                ContentUnavailableView {
                    Label("Inbox Empty", systemImage: "tray")
                } description: {
                    Text("No unprocessed files. Quick-dump imports will appear here.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                inboxHeader
                Divider()
                HStack(spacing: 0) {
                    inboxList
                    if let sample = editingSample {
                        Divider()
                        InboxEditorPanel(sample: sample, tagGroups: tagGroups) {
                            markAsProcessed([sample.persistentModelID])
                        }
                        .frame(width: 300)
                    }
                }
            }
        }
        .navigationTitle("Inbox (\(unprocessedSamples.count))")
        .toolbar {
            ToolbarItem {
                Button("Mark Selected as Processed") {
                    showMarkProcessedConfirm = true
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(selection.isEmpty)
            }
        }
        .alert("Mark as Processed?", isPresented: $showMarkProcessedConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Mark \(selection.count) File(s) as Processed") {
                markAsProcessed(selection)
            }
        } message: {
            Text("These files will move from the inbox to the library. You can mark them as processed with as little or as much metadata as you like.")
        }
        .onChange(of: selection) { _, newValue in
            if newValue.count == 1, let id = newValue.first {
                editingSample = unprocessedSamples.first { $0.persistentModelID == id }
            } else {
                editingSample = nil
            }
        }
    }

    private var inboxHeader: some View {
        HStack(spacing: 0) {
            Text("Name")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Key")
                .frame(width: 70, alignment: .leading)
            Text("Tags")
                .frame(width: 140, alignment: .leading)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.leading, 28)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }

    private var inboxList: some View {
        List(selection: $selection) {
            ForEach(unprocessedSamples) { sample in
                HStack(spacing: 0) {
                    Text(sample.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(sample.key ?? "—")
                        .foregroundStyle(sample.key == nil ? .tertiary : .primary)
                        .frame(width: 70, alignment: .leading)
                    Text(tagSummary(for: sample))
                        .foregroundStyle(sample.tags.isEmpty ? .tertiary : .secondary)
                        .frame(width: 140, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .font(.callout)
                .tag(sample.persistentModelID)
            }
        }
    }

    private func markAsProcessed(_ ids: Set<PersistentIdentifier>) {
        for sample in unprocessedSamples where ids.contains(sample.persistentModelID) {
            sample.isProcessed = true
            let newFilename = FilenameEncoder.encode(sample: sample)
            let currentFilename = currentVaultFilename(for: sample)
            if currentFilename != newFilename {
                do {
                    let vaultPath = UserDefaults.standard.string(forKey: "vaultPath") ?? ""
                    try VaultManager.renameInVault(from: currentFilename, to: newFilename, vaultPath: vaultPath)
                } catch {
                    // If rename fails, still keep the DB change — the file just has a stale name
                }
            }
        }
        selection.removeAll()
        editingSample = nil
    }

    private func currentVaultFilename(for sample: Sample) -> String {
        FilenameEncoder.encode(sample: sample)
    }

    private func tagSummary(for sample: Sample) -> String {
        guard !sample.tags.isEmpty else { return "—" }
        let names = sample.tags.sorted { $0.name < $1.name }.map(\.name)
        if names.count <= 3 {
            return names.joined(separator: ", ")
        }
        return names.prefix(2).joined(separator: ", ") + " +\(names.count - 2)"
    }
}

// MARK: - Inbox Editor Panel

struct InboxEditorPanel: View {
    @Bindable var sample: Sample
    @AppStorage("vaultPath") private var vaultPath: String = ""
    let tagGroups: [TagGroup]
    let onMarkProcessed: () -> Void

    @State private var nameText: String = ""
    @State private var keyText: String = ""
    @State private var tempoText: String = ""
    @State private var lastKnownFilename: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Edit Sample")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Metadata")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name").font(.caption).foregroundStyle(.secondary)
                        TextField("Sample name", text: $nameText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { applyName() }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Key").font(.caption).foregroundStyle(.secondary)
                        TextField("e.g. Cmaj, Fmin", text: $keyText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { applyKey() }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tempo").font(.caption).foregroundStyle(.secondary)
                        TextField("BPM (empty for free-time)", text: $tempoText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { applyChangesAndRename() }
                    }

                    Button("Apply Changes") {
                        applyChangesAndRename()
                    }
                    .font(.callout)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if tagGroups.isEmpty {
                        Text("No tag groups created yet.")
                            .foregroundStyle(.tertiary)
                            .font(.callout)
                    } else {
                        ForEach(tagGroups) { group in
                            Text("\(group.name) (\(group.code))")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.tertiary)
                            ForEach(group.tags.sorted { $0.name < $1.name }) { tag in
                                Toggle(isOn: tagBinding(for: tag)) {
                                    HStack {
                                        Text(tag.name)
                                            .font(.callout)
                                        Spacer()
                                        Text(tag.code)
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .toggleStyle(.checkbox)
                            }
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Vault Filename")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(FilenameEncoder.encode(sample: sample))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }

                Divider()

                Button {
                    onMarkProcessed()
                } label: {
                    Label("Mark as Processed", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onAppear { loadSampleValues() }
        .onChange(of: sample.persistentModelID) { _, _ in loadSampleValues() }
    }

    private func loadSampleValues() {
        nameText = sample.name
        keyText = sample.key ?? ""
        tempoText = sample.tempo.map { String($0) } ?? ""
        lastKnownFilename = FilenameEncoder.encode(sample: sample)
    }

    private func applyName() {
        let trimmed = nameText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { sample.name = trimmed }
    }

    private func applyKey() {
        let trimmed = keyText.trimmingCharacters(in: .whitespaces)
        sample.key = trimmed.isEmpty ? nil : trimmed
    }

    private func applyTempo() {
        let trimmed = tempoText.trimmingCharacters(in: .whitespaces)
        sample.tempo = Int(trimmed)
    }

    private func applyChangesAndRename() {
        let oldFilename = lastKnownFilename
        applyName()
        applyKey()
        applyTempo()
        let newFilename = FilenameEncoder.encode(sample: sample)
        if oldFilename != newFilename {
            try? VaultManager.renameInVault(from: oldFilename, to: newFilename, vaultPath: vaultPath)
        }
        lastKnownFilename = newFilename
    }

    private func tagBinding(for tag: Tag) -> Binding<Bool> {
        Binding(
            get: { sample.tags.contains(where: { $0.id == tag.id }) },
            set: { isOn in
                let oldFilename = FilenameEncoder.encode(sample: sample)
                if isOn {
                    if !sample.tags.contains(where: { $0.id == tag.id }) {
                        sample.tags.append(tag)
                    }
                } else {
                    sample.tags.removeAll { $0.id == tag.id }
                }
                let newFilename = FilenameEncoder.encode(sample: sample)
                if oldFilename != newFilename {
                    try? VaultManager.renameInVault(from: oldFilename, to: newFilename, vaultPath: vaultPath)
                    lastKnownFilename = newFilename
                }
            }
        )
    }
}
