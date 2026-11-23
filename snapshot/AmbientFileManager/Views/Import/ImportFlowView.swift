import SwiftUI
import SwiftData

struct ImportCandidate: Identifiable {
    let id = UUID()
    let sourceURL: URL
    var isSelected: Bool = true
    var name: String
    var version: Int = 1
    var isAudio: Bool

    // Metadata parsed from the filename
    var parsedKey: String?
    var parsedTempo: Int?
    var parsedTagCodes: [(groupCode: String, tagCode: String)] = []
    var unrecognizedTagCodes: [(groupCode: String, tagCode: String)] = []
    var hasParsedMetadata: Bool {
        parsedKey != nil || parsedTempo != nil || !parsedTagCodes.isEmpty || !unrecognizedTagCodes.isEmpty
    }

    init(sourceURL: URL) {
        self.sourceURL = sourceURL
        self.name = sourceURL.deletingPathExtension().lastPathComponent
        self.isAudio = VaultManager.isAudioFile(sourceURL)
        self.isSelected = self.isAudio
    }

    var fileExtension: String {
        sourceURL.pathExtension.lowercased()
    }

    /// Parse the filename and populate metadata fields.
    mutating func parseFilename(tagGroups: [TagGroup]) {
        let rawName = sourceURL.deletingPathExtension().lastPathComponent
        let decoded = FilenameDecoder.decodeAndResolve(rawName + "." + fileExtension, tagGroups: tagGroups)
        name = decoded.name
        version = decoded.version
        parsedKey = decoded.key
        parsedTempo = decoded.tempo
        parsedTagCodes = decoded.tagCodes
        unrecognizedTagCodes = decoded.unrecognizedTagCodes
    }
}

/// A tag code found in filenames that doesn't match any existing tag.
struct UnresolvedTagCode: Identifiable, Hashable {
    var id: String { "\(groupCode)-\(tagCode)" }
    let groupCode: String
    let tagCode: String
    /// How many selected files contain this tag code.
    var fileCount: Int = 0

    func hash(into hasher: inout Hasher) {
        hasher.combine(groupCode)
        hasher.combine(tagCode)
    }

    static func == (lhs: UnresolvedTagCode, rhs: UnresolvedTagCode) -> Bool {
        lhs.groupCode == rhs.groupCode && lhs.tagCode == rhs.tagCode
    }
}

enum ImportMode {
    case quickDump
    case detailed
}

private enum ImportStep {
    case selectFiles
    case chooseMode
    case unresolvedTags
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
    @State private var detailedPrePopulated = false

    // Unresolved tag codes across all selected candidates
    @State private var unresolvedCodes: [UnresolvedTagCode] = []
    @State private var showCreateTagSheet = false
    @State private var creatingForCode: UnresolvedTagCode?

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
            case .unresolvedTags:
                unresolvedTagsView
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

        candidates = allURLs.map { url in
            var candidate = ImportCandidate(sourceURL: url)
            if candidate.isAudio {
                candidate.parseFilename(tagGroups: tagGroups)
            }
            return candidate
        }
    }

    private var selectedCount: Int {
        candidates.filter { $0.isSelected && $0.isAudio }.count
    }

    /// Count of selected files that had metadata parsed from their filenames.
    private var parsedMetadataCount: Int {
        candidates.filter { $0.isSelected && $0.isAudio && $0.hasParsedMetadata }.count
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
                                        if candidate.hasParsedMetadata {
                                            HStack(spacing: 4) {
                                                if let key = candidate.parsedKey {
                                                    Text(key)
                                                        .padding(.horizontal, 4)
                                                        .background(.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                                                }
                                                if let tempo = candidate.parsedTempo {
                                                    Text("\(tempo)bpm")
                                                        .padding(.horizontal, 4)
                                                        .background(.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                                                }
                                                ForEach(Array(candidate.parsedTagCodes.enumerated()), id: \.offset) { _, tc in
                                                    Text("\(tc.groupCode)-\(tc.tagCode)")
                                                        .padding(.horizontal, 4)
                                                        .background(.purple.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                                                }
                                                ForEach(Array(candidate.unrecognizedTagCodes.enumerated()), id: \.offset) { _, tc in
                                                    Text("\(tc.groupCode)-\(tc.tagCode)")
                                                        .padding(.horizontal, 4)
                                                        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                                                }
                                            }
                                            .font(.caption)
                                        }
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

                if parsedMetadataCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("Detected metadata in \(parsedMetadataCount) filename(s) — this will be applied automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
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
                    proceedAfterModeChoice()
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
                        if parsedMetadataCount > 0 {
                            Text("Detected metadata will still be applied.")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                    .frame(width: 200, height: 150)
                }
                .buttonStyle(.bordered)

                Button {
                    activeMode = .detailed
                    proceedAfterModeChoice()
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

    /// After mode is chosen, check for unresolved tags or proceed directly.
    private func proceedAfterModeChoice() {
        collectUnresolvedCodes()
        if !unresolvedCodes.isEmpty {
            step = .unresolvedTags
        } else if activeMode == .detailed {
            prePopulateDetailedFields()
            step = .detailed
        } else {
            startImport()
        }
    }

    /// Gather all unrecognized tag codes from selected candidates.
    private func collectUnresolvedCodes() {
        var codeMap: [String: UnresolvedTagCode] = [:]
        for candidate in candidates where candidate.isSelected && candidate.isAudio {
            for tc in candidate.unrecognizedTagCodes {
                let key = "\(tc.groupCode)-\(tc.tagCode)"
                if var existing = codeMap[key] {
                    existing.fileCount += 1
                    codeMap[key] = existing
                } else {
                    codeMap[key] = UnresolvedTagCode(groupCode: tc.groupCode, tagCode: tc.tagCode, fileCount: 1)
                }
            }
        }
        unresolvedCodes = codeMap.values.sorted { $0.id < $1.id }
    }

    // MARK: - Step 2.5: Unresolved Tags

    private var unresolvedTagsView: some View {
        VStack(spacing: 0) {
            Text("Unrecognised Tags in Filenames")
                .font(.headline)
                .padding()

            Text("The following tag codes were found in filenames but don't match any tags in your library. You can create them now or skip — skipped codes will be ignored during import.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            List {
                ForEach(unresolvedCodes) { code in
                    HStack {
                        Text(code.id)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                        Text("(\(code.fileCount) file\(code.fileCount == 1 ? "" : "s"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()

                        if isCodeNowResolved(code) {
                            Label("Created", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Button("Create Tag...") {
                                creatingForCode = code
                                showCreateTagSheet = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            Divider()
            HStack {
                Button("Back") { step = .chooseMode }
                Spacer()

                let remaining = unresolvedCodes.filter { !isCodeNowResolved($0) }.count
                if remaining > 0 {
                    Text("\(remaining) unresolved")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Button(remaining > 0 ? "Skip & Continue" : "Continue") {
                    // Re-parse candidates now that new tags may have been created
                    reparseAllCandidates()
                    if activeMode == .detailed {
                        prePopulateDetailedFields()
                        step = .detailed
                    } else {
                        startImport()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .sheet(isPresented: $showCreateTagSheet) {
            if let code = creatingForCode {
                UnresolvedTagCreateSheet(
                    groupCode: code.groupCode,
                    tagCode: code.tagCode,
                    tagGroups: tagGroups
                )
            }
        }
    }

    /// Check if a previously unresolved code now matches a tag in the library.
    private func isCodeNowResolved(_ code: UnresolvedTagCode) -> Bool {
        for group in tagGroups where group.code.uppercased() == code.groupCode.uppercased() {
            if group.tags.contains(where: { $0.code.uppercased() == code.tagCode.uppercased() }) {
                return true
            }
        }
        return false
    }

    /// Re-parse all candidate filenames after new tags have been created.
    private func reparseAllCandidates() {
        for i in candidates.indices where candidates[i].isAudio {
            candidates[i].parseFilename(tagGroups: tagGroups)
        }
        collectUnresolvedCodes()
    }

    /// Pre-populate detailed mode fields from the first candidate's parsed metadata.
    private func prePopulateDetailedFields() {
        guard !detailedPrePopulated else { return }
        detailedPrePopulated = true

        // Use the first selected candidate's parsed data as defaults
        guard let first = candidates.first(where: { $0.isSelected && $0.isAudio && $0.hasParsedMetadata }) else { return }

        if batchKey.isEmpty, let key = first.parsedKey {
            batchKey = key
        }
        if batchTempo.isEmpty, let tempo = first.parsedTempo {
            batchTempo = String(tempo)
        }
        // Pre-select tags that were parsed from filenames
        let allParsedCodes = candidates
            .filter { $0.isSelected && $0.isAudio }
            .flatMap(\.parsedTagCodes)
        for tc in allParsedCodes {
            for group in tagGroups where group.code.uppercased() == tc.groupCode.uppercased() {
                if let tag = group.tags.first(where: { $0.code.uppercased() == tc.tagCode.uppercased() }) {
                    batchTagIds.insert(tag.id)
                }
            }
        }
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
            // In quick dump, use per-file parsed metadata
            let tagCodes = candidate.parsedTagCodes
            return FilenameEncoder.encode(
                name: candidate.name,
                key: candidate.parsedKey,
                tempo: candidate.parsedTempo,
                tagCodes: tagCodes,
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

            // Determine key and tempo: detailed uses batch, quick dump uses parsed
            let key: String?
            let tempo: Int?
            if isDetailed {
                key = batchKey.isEmpty ? nil : batchKey
                tempo = Int(batchTempo)
            } else {
                key = candidate.parsedKey
                tempo = candidate.parsedTempo
            }

            // Determine tags: detailed uses batch selection, quick dump uses per-file parsed tags
            let tags: [Tag]
            if isDetailed {
                tags = resolveTags(from: batchTagIds)
            } else {
                tags = FilenameDecoder.resolveTags(from: candidate.parsedTagCodes, in: tagGroups)
            }

            // A file is considered "processed" if it has any metadata at all
            let hasMetadata = key != nil || tempo != nil || !tags.isEmpty

            let sample = Sample(
                name: candidate.name,
                originalFilename: candidate.sourceURL.lastPathComponent,
                key: key,
                tempo: tempo,
                version: candidate.version,
                isProcessed: isDetailed || hasMetadata,
                fileExtension: candidate.fileExtension
            )
            modelContext.insert(sample)

            for tag in tags {
                sample.tags.append(tag)
            }

            try modelContext.save()
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

// MARK: - Unresolved Tag Create Sheet

/// A sheet that lets the user quickly create a tag for an unresolved code.
/// If a group with the matching code exists, the tag is added to it.
/// Otherwise, a new group is created.
struct UnresolvedTagCreateSheet: View {
    let groupCode: String
    let tagCode: String
    let tagGroups: [TagGroup]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var tagName: String = ""
    @State private var groupName: String = ""
    @State private var selectedGroupId: UUID?

    private var matchingGroup: TagGroup? {
        tagGroups.first { $0.code.uppercased() == groupCode.uppercased() }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Tag: \(groupCode)-\(tagCode)")
                .font(.headline)

            if let group = matchingGroup {
                Text("Group \"\(group.name)\" (\(group.code)) already exists. The new tag will be added to it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Group Name (code: \(groupCode))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("e.g. Sound Source", text: $groupName)
                        .textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Tag Name (code: \(tagCode))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("e.g. Arrival", text: $tagName)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(tagName.trimmingCharacters(in: .whitespaces).isEmpty
                              || (matchingGroup == nil && groupName.trimmingCharacters(in: .whitespaces).isEmpty))
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func create() {
        let trimmedTagName = tagName.trimmingCharacters(in: .whitespaces)
        guard !trimmedTagName.isEmpty else { return }

        let group: TagGroup
        if let existing = matchingGroup {
            group = existing
        } else {
            let trimmedGroupName = groupName.trimmingCharacters(in: .whitespaces)
            guard !trimmedGroupName.isEmpty else { return }
            group = TagGroup(name: trimmedGroupName, code: groupCode.uppercased())
            modelContext.insert(group)
        }

        let tag = Tag(name: trimmedTagName, code: tagCode.uppercased(), group: group)
        modelContext.insert(tag)
        group.tags.append(tag)

        try? modelContext.save()
        dismiss()
    }
}
