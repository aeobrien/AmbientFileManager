import SwiftUI
import SwiftData

struct ExportFlowView: View {
    let samples: [Sample]

    @Environment(\.dismiss) private var dismiss
    @AppStorage("vaultPath") private var vaultPath: String = ""
    @Query(sort: \TagGroup.name) private var tagGroups: [TagGroup]

    @State private var destinationPath: URL?
    @State private var folderGrouping: GroupingChoice = .flat
    @State private var includeCodebook = true
    @State private var applyAdjustments = false
    @State private var isExporting = false
    @State private var result: ExportResult?

    enum GroupingChoice: Hashable {
        case flat
        case byTagGroup(UUID)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let result = result {
                completionView(result)
            } else if isExporting {
                exportingView
            } else {
                configurationView
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    // MARK: - Configuration

    private var configurationView: some View {
        VStack(spacing: 0) {
            Text("Export \(samples.count) Sample(s)")
                .font(.headline)
                .padding()

            List {
                Section("Destination") {
                    HStack {
                        if let path = destinationPath {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.blue)
                            Text(path.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("No destination selected")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Choose...") {
                            chooseDestination()
                        }
                    }
                }

                Section("Folder Structure") {
                    Picker("Grouping", selection: $folderGrouping) {
                        Text("Flat (all files in one folder)").tag(GroupingChoice.flat)
                        ForEach(tagGroups) { group in
                            Text("Group by \(group.name) (\(group.code))").tag(GroupingChoice.byTagGroup(group.id))
                        }
                    }
                    .pickerStyle(.radioGroup)

                    if case .byTagGroup = folderGrouping {
                        Text("Files are placed in subfolders by their tag in the selected group. Files with no matching tag go to \"Ungrouped\".")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Options") {
                    Toggle("Include codebook.json", isOn: $includeCodebook)
                    Text("A reference file listing all tag groups and codes for interpreting encoded filenames.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Apply trim and pitch adjustments", isOn: $applyAdjustments)
                    if applyAdjustments {
                        Text("Samples with non-zero trim or pitch will be rendered with adjustments baked into the audio. Samples with no adjustments are copied as-is.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        let adjusted = samples.filter { $0.pitchSemitones != 0 || $0.trimDb != 0 }
                        if !adjusted.isEmpty {
                            Text("\(adjusted.count) sample(s) have adjustments that will be rendered.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section("Files to Export") {
                    ForEach(samples.prefix(20)) { sample in
                        HStack {
                            Text(sample.name)
                            Spacer()
                            Text(FilenameEncoder.encode(sample: sample))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    if samples.count > 20 {
                        Text("...and \(samples.count - 20) more")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Export") { performExport() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(destinationPath == nil)
            }
            .padding()
        }
    }

    // MARK: - Exporting

    private var exportingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Exporting...")
                .font(.headline)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Completion

    private func completionView(_ result: ExportResult) -> some View {
        VStack(spacing: 16) {
            Spacer()

            if result.failedCount == 0 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("Export Complete")
                    .font(.headline)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)
                Text("Export Complete with Issues")
                    .font(.headline)
            }

            Text("\(result.exportedCount) exported\(result.failedCount > 0 ? ", \(result.failedCount) failed" : "")")
                .foregroundStyle(.secondary)

            if !result.errors.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(result.errors, id: \.self) { error in
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 120)
            }

            Spacer()

            HStack {
                Button("Show in Finder") {
                    if let path = destinationPath {
                        NSWorkspace.shared.open(path)
                    }
                }
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Here"
        panel.message = "Choose a destination folder for the export"

        if panel.runModal() == .OK, let url = panel.url {
            destinationPath = url
        }
    }

    private func performExport() {
        guard let destination = destinationPath else { return }

        let grouping: FolderGrouping
        switch folderGrouping {
        case .flat:
            grouping = .flat
        case .byTagGroup(let groupId):
            if let group = tagGroups.first(where: { $0.id == groupId }) {
                grouping = .byTagGroup(group)
            } else {
                grouping = .flat
            }
        }

        let config = ExportConfiguration(
            destinationPath: destination,
            folderGrouping: grouping,
            includeCodebook: includeCodebook,
            audioMode: applyAdjustments ? .applyAdjustments : .original
        )

        isExporting = true

        DispatchQueue.global(qos: .userInitiated).async {
            let exportResult = ExportService.export(
                samples: samples,
                tagGroups: tagGroups,
                config: config,
                vaultPath: vaultPath
            )
            DispatchQueue.main.async {
                isExporting = false
                result = exportResult
            }
        }
    }
}
