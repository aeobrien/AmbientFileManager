import SwiftUI
import SwiftData

struct ImportCandidate: Identifiable {
    let id = UUID()
    let sourceURL: URL
    var isSelected: Bool = true
    var name: String
    var version: Int = 1
    var isAudio: Bool

    init(sourceURL: URL) {
        self.sourceURL = sourceURL
        self.name = sourceURL.deletingPathExtension().lastPathComponent
        self.isAudio = VaultManager.isAudioFile(sourceURL)
        self.isSelected = self.isAudio
    }

    var fileExtension: String {
        sourceURL.pathExtension.lowercased()
    }
}

enum ImportMode {
    case quickDump
    case detailed
}

private enum ImportStep {
    case selectFiles
    case chooseMode
    case detailed
    case importing
    case collision
    case complete
}

struct ImportFlowView: View {
    let sourceURLs: [URL]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("vaultPath") private var vaultPath: String = ""
    @Query(sort: \TagGroup.name) private var tagGroups: [TagGroup]

    @State private var step: ImportStep = .selectFiles
    @State private var candidates: [ImportCandidate] = []
    @State private var importedCount = 0
    @State private var skippedCount = 0

    // Detailed mode shared metadata
    @State private var batchKey: String = ""
    @State private var batchTempo: String = ""
    @State private var batchTagIds: Set<UUID> = []

    // Collision handling
    @State private var showCollision = false
    @State private var collisionIndex: Int = 0
    @State private var collisionFilename: String = ""
    @State private var collisionNewName: String = ""
    @State private var importQueue: [Int] = []
    @State private var queuePosition: Int = 0
    @State private var activeMode: ImportMode = .quickDump

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .selectFiles:
                selectFilesView
            case .chooseMode:
                chooseModeView
            case .detailed:
                detailedView
            case .importing:
                importingView
            case .collision:
                collisionView
            case .complete:
                completeView
            }
        }
        .frame(minWidth: 600, minHeight: 450)
        .onAppear {
            discoverFiles()
        }
    }

    // MARK: - File Discovery

    private func discoverFiles() {
        var allURLs: [URL] = []
        let fm = FileManager.default

        for url in sourceURLs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                if let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for case let fileURL as URL in enumerator {
                        allURLs.append(fileURL)
                    }
                }
            } else {
                allURLs.append(url)
            }
        }

        candidates = allURLs.map { ImportCandidate(sourceURL: $0) }
    }

    private var selectedCount: Int {
        candidates.filter { $0.isSelected && $0.isAudio }.count
    }

    // MARK: - Step 1: Select Files

    private var selectFilesView: some View {
        VStack(spacing: 0) {
            Text("Import Files")
                .font(.headline)
                .padding()

            if candidates.isEmpty {
                Spacer()
                Text("No files found.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                HStack {
                    Button("Select All") {
                        for i in candidates.indices where candidates[i].isAudio {
                            candidates[i].isSelected = true
                        }
                    }
                    Button("Deselect All") {
                        for i in candidates.indices {
                            candidates[i].isSelected = false
                        }
                    }
                    Spacer()
                    Text("\(selectedCount) of \(candidates.filter(\.isAudio).count) audio files selected")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                .padding(.horizontal)

                List {
                    ForEach($candidates) { $candidate in
                        HStack {
                            if candidate.isAudio {
                                Toggle(isOn: $candidate.isSelected) {
                                    VStack(alignment: .leading) {
                                        Text(candidate.sourceURL.lastPathComponent)
                                        Text(candidate.sourceURL.deletingLastPathComponent().path)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .toggleStyle(.checkbox)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                VStack(alignment: .leading) {
                                    Text(candidate.sourceURL.lastPathComponent)
                                        .strikethrough()
                                        .foregroundStyle(.secondary)
                                    Text("Not an audio file")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }
            }

            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Next") { step = .chooseMode }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedCount == 0)
            }
            .padding()
        }
    }

    // MARK: - Step 2: Choose Mode

    private var chooseModeView: some View {
        VStack(spacing: 24) {
            Text("Import Mode")
                .font(.headline)

            Text("\(selectedCount) file(s) ready to import")
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                Button {
                    activeMode = .quickDump
                    startImport()
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 32))
                        Text("Quick Dump")
                            .font(.headline)
                        Text("Import now, tag later.\nFiles land in the inbox.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 200, height: 150)
                }
                .buttonStyle(.bordered)

                Button {
                    activeMode = .detailed
                    step = .detailed
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "tag")
                            .font(.system(size: 32))
                        Text("Detailed")
                            .font(.headline)
                        Text("Assign metadata and tags\nbefore importing.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 200, height: 150)
                }
                .buttonStyle(.bordered)
            }

            Button("Back") { step = .selectFiles }
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Step 3: Detailed Mode

    private var detailedView: some View {
        VStack(spacing: 0) {
            Text("Detailed Import")
                .font(.headline)
                .padding()

            List {
                Section("File Names") {
                    ForEach($candidates) { $candidate in
                        if candidate.isSelected && candidate.isAudio {
                            HStack {
                                TextField("Name", text: $candidate.name)
                                    .textFieldStyle(.roundedBorder)
                                Text(".\(candidate.fileExtension)")
                                    .foregroundStyle(.secondary)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                }

                Section("Metadata (applied to all files)") {
                    HStack {
                        Text("Key")
                            .frame(width: 50, alignment: .leading)
                        TextField("e.g. Cmaj, Fmin", text: $batchKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("Tempo")
                            .frame(width: 50, alignment: .leading)
                        TextField("BPM (leave empty for free-time)", text: $batchTempo)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section("Tags (applied to all files)") {
                    if tagGroups.isEmpty {
                        Text("No tag groups created yet. You can add tags later.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(tagGroups) { group in
                            DisclosureGroup("\(group.name) (\(group.code))") {
                                ForEach(sortedTags(for: group)) { tag in
                                    Toggle(isOn: tagBinding(for: tag.id)) {
                                        HStack {
                                            Text(tag.name)
                                            Spacer()
                                            Text(tag.code)
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }
                    }
                }

                if !batchKey.isEmpty || !batchTempo.isEmpty || !batchTagIds.isEmpty {
                    Section("Filename Preview") {
                        let preview = previewFilename()
                        Text(preview)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()
            HStack {
                Button("Back") { step = .chooseMode }
                Spacer()
                Button("Import \(selectedCount) File(s)") { startImport() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    private func sortedTags(for group: TagGroup) -> [Tag] {
        group.tags.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func tagBinding(for tagId: UUID) -> Binding<Bool> {
        Binding(
            get: { batchTagIds.contains(tagId) },
            set: { isOn in
                if isOn { batchTagIds.insert(tagId) } else { batchTagIds.remove(tagId) }
            }
        )
    }

    private func previewFilename() -> String {
        guard let first = candidates.first(where: { $0.isSelected && $0.isAudio }) else {
            return ""
        }
        let tagCodes = resolveTagCodes(from: batchTagIds)
        let key = batchKey.isEmpty ? nil : batchKey
        let tempo = Int(batchTempo)
        return FilenameEncoder.encode(
            name: first.name,
            key: key,
            tempo: tempo,
            tagCodes: tagCodes,
            version: first.version,
            fileExtension: first.fileExtension
        )
    }

    private func resolveTagCodes(from tagIds: Set<UUID>) -> [(groupCode: String, tagCode: String)] {
        var codes: [(groupCode: String, tagCode: String)] = []
        for group in tagGroups {
            for tag in group.tags {
                if tagIds.contains(tag.id) {
                    codes.append((groupCode: group.code, tagCode: tag.code))
                }
            }
        }
        return codes
    }

    private func resolveTags(from tagIds: Set<UUID>) -> [Tag] {
        var result: [Tag] = []
        for group in tagGroups {
            for tag in group.tags {
                if tagIds.contains(tag.id) {
                    result.append(tag)
                }
            }
        }
        return result
    }

    // MARK: - Step 4: Importing

    private var importingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Importing files...")
                .font(.headline)
            Text("\(importedCount) of \(selectedCount) imported")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Step 5: Complete

    private var completeView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Import Complete")
                .font(.headline)
            Text("\(importedCount) file(s) imported\(skippedCount > 0 ? ", \(skippedCount) skipped" : "")")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Import Execution

    private func startImport() {
        importedCount = 0
        skippedCount = 0
        importQueue = candidates.indices.filter { candidates[$0].isSelected && candidates[$0].isAudio }
        queuePosition = 0
        step = .importing
        processNextImport()
    }

    private func processNextImport() {
        guard queuePosition < importQueue.count else {
            step = .complete
            return
        }

        let idx = importQueue[queuePosition]
        let candidate = candidates[idx]
        let filename = generateFilename(for: candidate)

        if VaultManager.fileExistsInVault(filename: filename, vaultPath: vaultPath) {
            collisionIndex = idx
            collisionFilename = filename
            collisionNewName = candidate.name
            step = .collision
            return
        }

        performSingleImport(candidateIndex: idx, filename: filename)
        queuePosition += 1

        DispatchQueue.main.async {
            processNextImport()
        }
    }

    private func generateFilename(for candidate: ImportCandidate) -> String {
        switch activeMode {
        case .quickDump:
            return FilenameEncoder.encode(
                name: candidate.name,
                key: nil,
                tempo: nil,
                tagCodes: [],
                version: candidate.version,
                fileExtension: candidate.fileExtension
            )
        case .detailed:
            let key = batchKey.isEmpty ? nil : batchKey
            let tempo = Int(batchTempo)
            let tagCodes = resolveTagCodes(from: batchTagIds)
            return FilenameEncoder.encode(
                name: candidate.name,
                key: key,
                tempo: tempo,
                tagCodes: tagCodes,
                version: candidate.version,
                fileExtension: candidate.fileExtension
            )
        }
    }

    private func performSingleImport(candidateIndex idx: Int, filename: String) {
        let candidate = candidates[idx]
        do {
            try VaultManager.copyToVault(from: candidate.sourceURL, filename: filename, vaultPath: vaultPath)

            let isDetailed = activeMode == .detailed
            let key: String? = isDetailed && !batchKey.isEmpty ? batchKey : nil
            let tempo: Int? = isDetailed ? Int(batchTempo) : nil
            let tags = isDetailed ? resolveTags(from: batchTagIds) : []

            let sample = Sample(
                name: candidate.name,
                originalFilename: candidate.sourceURL.lastPathComponent,
                key: key,
                tempo: tempo,
                version: candidate.version,
                isProcessed: isDetailed,
                fileExtension: candidate.fileExtension
            )
            modelContext.insert(sample)

            for tag in tags {
                sample.tags.append(tag)
            }

            importedCount += 1
        } catch {
            skippedCount += 1
        }
    }

    // MARK: - Collision Resolution

    private var collisionView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)

            Text("Filename Collision")
                .font(.headline)

            Text("A file named \"\(collisionFilename)\" already exists in the vault.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 8) {
                Text("Rename the file:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("New name", text: $collisionNewName)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 60)

            HStack(spacing: 12) {
                Button("Skip") {
                    resolveCollision(.skip)
                }
                Button("Import as v\(String(format: "%02d", candidates[collisionIndex].version + 1))") {
                    resolveCollision(.incrementVersion)
                }
                Button("Rename & Import") {
                    resolveCollision(.rename)
                }
                .buttonStyle(.borderedProminent)
                .disabled(collisionNewName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private enum CollisionResolution {
        case skip
        case incrementVersion
        case rename
    }

    private func resolveCollision(_ resolution: CollisionResolution) {
        let idx = collisionIndex

        switch resolution {
        case .skip:
            skippedCount += 1

        case .incrementVersion:
            candidates[idx].version += 1
            let newFilename = generateFilename(for: candidates[idx])
            if VaultManager.fileExistsInVault(filename: newFilename, vaultPath: vaultPath) {
                collisionFilename = newFilename
                // Stay on collision step with updated info
                return
            }
            performSingleImport(candidateIndex: idx, filename: newFilename)

        case .rename:
            candidates[idx].name = collisionNewName.trimmingCharacters(in: .whitespaces)
            let newFilename = generateFilename(for: candidates[idx])
            if VaultManager.fileExistsInVault(filename: newFilename, vaultPath: vaultPath) {
                collisionFilename = newFilename
                collisionNewName = candidates[idx].name
                return
            }
            performSingleImport(candidateIndex: idx, filename: newFilename)
        }

        queuePosition += 1
        step = .importing
        DispatchQueue.main.async {
            processNextImport()
        }
    }
}
