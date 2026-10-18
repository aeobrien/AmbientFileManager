import SwiftUI
import SwiftData

struct SampleInspectorView: View {
    @Environment(AudioPlayer.self) private var audioPlayer
    @AppStorage("vaultPath") private var vaultPath: String = ""
    @Query(sort: \TagGroup.name) private var tagGroups: [TagGroup]
    @Bindable var sample: Sample

    @State private var nameText: String = ""
    @State private var keyValue: String? = nil
    @State private var tempoText: String = ""
    @State private var lastKnownFilename: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header + Play
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        if sample.isProcessed {
                            Label("Processed", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Label("Unprocessed", systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    Button {
                        playSample()
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }

                Divider()

                // Editable metadata
                VStack(alignment: .leading, spacing: 8) {
                    Text("Metadata")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name").font(.caption).foregroundStyle(.secondary)
                        TextField("Sample name", text: $nameText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { applyNameChange() }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Key").font(.caption).foregroundStyle(.secondary)
                        KeyPicker(keyString: $keyValue, onChanged: { applyKeyChange() })
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tempo").font(.caption).foregroundStyle(.secondary)
                        TextField("BPM (empty for free-time)", text: $tempoText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { applyTempoChange() }
                    }

                    HStack {
                        metadataRow("Version", value: "v\(String(format: "%02d", sample.version))")
                        Spacer()
                        metadataRow("Format", value: sample.fileExtension.uppercased())
                    }

                    let pitchStr = sample.pitchSemitones == 0 ? "0" : (sample.pitchSemitones > 0 ? "+\(sample.pitchSemitones)" : "\(sample.pitchSemitones)")
                    metadataRow("Pitch", value: "\(pitchStr) semitones")

                    let trimStr = sample.trimDb == 0 ? "0" : String(format: "%+.1f", sample.trimDb)
                    metadataRow("Trim", value: "\(trimStr) dB")

                    metadataRow("Imported", value: sample.dateImported.formatted(date: .abbreviated, time: .shortened))
                }

                Divider()

                // Tags
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if tagGroups.isEmpty {
                        Text("No tag groups created.")
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

                // Filename
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vault Filename")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(FilenameEncoder.encode(sample: sample))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Original Filename")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(sample.originalFilename)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
        }
        .onAppear { loadSampleValues() }
        .onChange(of: sample.persistentModelID) { _, _ in loadSampleValues() }
    }

    // MARK: - State management

    private func loadSampleValues() {
        nameText = sample.name
        keyValue = sample.key
        tempoText = sample.tempo.map { String($0) } ?? ""
        lastKnownFilename = FilenameEncoder.encode(sample: sample)
    }

    private func applyNameChange() {
        let trimmedName = nameText.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, trimmedName != sample.name else { return }
        let oldFilename = lastKnownFilename
        sample.name = trimmedName
        renameIfNeeded(from: oldFilename)
    }

    private func applyKeyChange() {
        guard keyValue != sample.key else { return }
        let oldFilename = lastKnownFilename
        sample.key = keyValue
        renameIfNeeded(from: oldFilename)
    }

    private func applyTempoChange() {
        let newTempo = Int(tempoText.trimmingCharacters(in: .whitespaces))
        guard newTempo != sample.tempo else { return }
        let oldFilename = lastKnownFilename
        sample.tempo = newTempo
        renameIfNeeded(from: oldFilename)
    }

    private func renameIfNeeded(from oldFilename: String) {
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

    private func playSample() {
        let filename = FilenameEncoder.encode(sample: sample)
        let fileURL = VaultManager.vaultURL(from: vaultPath).appendingPathComponent(filename)
        audioPlayer.play(url: fileURL, name: sample.name, sampleId: sample.persistentModelID, pitch: sample.pitchSemitones, trim: sample.trimDb)
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
        }
        .font(.callout)
    }
}

// Simple flow layout for tag chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
        var sizes: [CGSize]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return ArrangeResult(size: CGSize(width: maxX, height: y + rowHeight), positions: positions, sizes: sizes)
    }
}
