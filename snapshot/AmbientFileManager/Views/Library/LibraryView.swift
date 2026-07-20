import SwiftUI
import SwiftData

enum TempoFilter: String, CaseIterable {
    case all = "All"
    case freeTime = "Free-time"
    case hasTempo = "Has Tempo"
}

enum ProcessedFilter: String, CaseIterable {
    case all = "All"
    case processed = "Processed"
    case unprocessed = "Unprocessed"
}

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(AppUndoManager.self) private var appUndoManager
    @AppStorage("vaultPath") private var vaultPath: String = ""
    @Query(sort: \Sample.name) private var allSamples: [Sample]
    @Query(sort: \TagGroup.name) private var tagGroups: [TagGroup]

    @State private var searchText = ""
    @State private var selectedKeys: Set<String> = []
    @State private var tempoFilter: TempoFilter = .all
    @State private var processedFilter: ProcessedFilter = .all
    @State private var selectedTagIds: Set<UUID> = []
    @State private var showTagFilterPopover = false

    @State private var selection = Set<PersistentIdentifier>()
    @State private var sortField: SortField = .name
    @State private var sortAscending = true

    // Browse mode
    @State private var browseByPrimary: UUID? = nil   // tag group id
    @State private var browseBySecondary: UUID? = nil  // tag group id

    enum SortField: String, CaseIterable {
        case name = "Name"
        case key = "Key"
        case tempo = "Tempo"
        case pitch = "Pitch"
        case trim = "Trim"
        case tags = "Tags"
        case dateImported = "Imported"
    }
    @State private var showDeleteAlert = false
    @State private var showExport = false

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()

            if allSamples.isEmpty {
                ContentUnavailableView {
                    Label("No Samples", systemImage: "music.note")
                } description: {
                    Text("Import audio files to get started.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if displayedSamples.isEmpty {
                columnHeader
                Divider()
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    if browseByPrimary != nil {
                        groupedBrowseView
                    } else {
                        sampleTable
                    }
                    if selectedSamples.count > 1 {
                        Divider()
                        BatchOperationsPanel(
                            samples: selectedSamples,
                            tagGroups: tagGroups,
                            vaultPath: vaultPath,
                            undoManager: appUndoManager,
                            onDone: { selection.removeAll() }
                        )
                        .frame(width: 300)
                    } else if let sample = selectedSample {
                        Divider()
                        SampleInspectorView(sample: sample)
                            .frame(width: 280)
                    }
                }
            }
        }
        .navigationTitle("Library (\(displayedSamples.count))")
        .toolbar {
            ToolbarItem {
                Button {
                    appUndoManager.undo(modelContext: modelContext)
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!appUndoManager.canUndo)
            }
            ToolbarItem {
                Button {
                    showExport = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(exportSamples.isEmpty)
            }
            ToolbarItem {
                Button {
                    showDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(selection.isEmpty)
            }
        }
        .onKeyPress(phases: .down) { keyPress in
            handleKeyPress(keyPress)
        }
        .onChange(of: audioPlayer.semitoneOffset) { _, _ in syncAudioSettingsToSample() }
        .onChange(of: audioPlayer.trimDb) { _, _ in syncAudioSettingsToSample() }
        .onChange(of: selection) { _, newValue in
            if newValue.count == 1, let id = newValue.first,
               let sample = allSamples.first(where: { $0.persistentModelID == id }) {
                let filename = FilenameEncoder.encode(sample: sample)
                let fileURL = VaultManager.vaultURL(from: vaultPath).appendingPathComponent(filename)
                if audioPlayer.isPlaying {
                    audioPlayer.play(url: fileURL, name: sample.name, sampleId: sample.persistentModelID, pitch: sample.pitchSemitones, trim: sample.trimDb)
                } else {
                    audioPlayer.load(url: fileURL, name: sample.name, sampleId: sample.persistentModelID, pitch: sample.pitchSemitones, trim: sample.trimDb)
                }
            }
        }
        .sheet(isPresented: $showExport) {
            ExportFlowView(samples: exportSamples)
        }
        .alert("Delete \(selection.count) Sample(s)?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSelectedSamples()
            }
        } message: {
            Text("The file(s) will be moved to Trash. Database records will be removed.")
        }
    }

    // MARK: - Selection Helpers

    private var selectedSamples: [Sample] {
        allSamples.filter { selection.contains($0.persistentModelID) }
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .space where keyPress.modifiers.contains(.control):
            if audioPlayer.isPlaying || audioPlayer.isPaused {
                audioPlayer.togglePlayPause()
            } else if let sample = selectedSample {
                playSample(sample)
            }
            return .handled
        case .escape:
            audioPlayer.stop()
            return .handled
        case .upArrow:
            if keyPress.modifiers.contains(.command) && audioPlayer.hasLoadedFile {
                audioPlayer.shiftPitch(by: 1)
                return .handled
            } else if keyPress.modifiers.contains(.shift) && audioPlayer.hasLoadedFile {
                audioPlayer.shiftPitch(by: 12)
                return .handled
            } else if keyPress.modifiers.isEmpty {
                selectAdjacentSample(direction: -1)
                return .handled
            }
            return .ignored
        case .downArrow:
            if keyPress.modifiers.contains(.command) && audioPlayer.hasLoadedFile {
                audioPlayer.shiftPitch(by: -1)
                return .handled
            } else if keyPress.modifiers.contains(.shift) && audioPlayer.hasLoadedFile {
                audioPlayer.shiftPitch(by: -12)
                return .handled
            } else if keyPress.modifiers.isEmpty {
                selectAdjacentSample(direction: 1)
                return .handled
            }
            return .ignored
        default:
            return .ignored
        }
    }

    private func selectAdjacentSample(direction: Int) {
        let samples = displayedSamples
        guard !samples.isEmpty else { return }

        if let currentId = selection.first,
           let currentIndex = samples.firstIndex(where: { $0.persistentModelID == currentId }) {
            let newIndex = min(max(currentIndex + direction, 0), samples.count - 1)
            selection = [samples[newIndex].persistentModelID]
        } else {
            // Nothing selected — select first or last depending on direction
            let sample = direction > 0 ? samples.first! : samples.last!
            selection = [sample.persistentModelID]
        }
    }

    private func playSample(_ sample: Sample) {
        let filename = FilenameEncoder.encode(sample: sample)
        let fileURL = VaultManager.vaultURL(from: vaultPath).appendingPathComponent(filename)
        audioPlayer.play(url: fileURL, name: sample.name, sampleId: sample.persistentModelID, pitch: sample.pitchSemitones, trim: sample.trimDb)
    }

    /// Sync AudioPlayer pitch/trim changes back to the Sample model.
    private func syncAudioSettingsToSample() {
        guard let id = audioPlayer.currentSampleId,
              let sample = allSamples.first(where: { $0.persistentModelID == id }) else { return }
        if sample.pitchSemitones != audioPlayer.semitoneOffset {
            sample.pitchSemitones = audioPlayer.semitoneOffset
        }
        if sample.trimDb != audioPlayer.trimDb {
            sample.trimDb = audioPlayer.trimDb
        }
    }

    /// Samples to export: selected ones if any, otherwise all currently filtered.
    private var exportSamples: [Sample] {
        selection.isEmpty ? displayedSamples : selectedSamples
    }

    // MARK: - Filtering

    private var availableKeys: [String] {
        Array(Set(allSamples.compactMap(\.key))).sorted()
    }

    private var filteredSamples: [Sample] {
        allSamples.filter { sample in
            matchesSearch(sample)
                && matchesKey(sample)
                && matchesTempo(sample)
                && matchesProcessed(sample)
                && matchesTags(sample)
        }
    }

    private var displayedSamples: [Sample] {
        filteredSamples.sorted { a, b in
            let result: Bool
            switch sortField {
            case .name: result = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .key: result = (a.key ?? "") < (b.key ?? "")
            case .tempo: result = (a.tempo ?? Int.max) < (b.tempo ?? Int.max)
            case .pitch: result = a.pitchSemitones < b.pitchSemitones
            case .trim: result = a.trimDb < b.trimDb
            case .tags: result = a.tagCount < b.tagCount
            case .dateImported: result = a.dateImported < b.dateImported
            }
            return sortAscending ? result : !result
        }
    }

    private var selectedSample: Sample? {
        guard selection.count == 1, let id = selection.first else { return nil }
        return allSamples.first { $0.persistentModelID == id }
    }

    private func matchesSearch(_ sample: Sample) -> Bool {
        guard !searchText.isEmpty else { return true }
        let query = searchText.lowercased()
        if sample.name.lowercased().contains(query) { return true }
        if sample.tags.contains(where: { $0.name.lowercased().contains(query) }) { return true }
        return false
    }

    private func matchesKey(_ sample: Sample) -> Bool {
        guard !selectedKeys.isEmpty else { return true }
        guard let key = sample.key else { return false }
        return selectedKeys.contains(key)
    }

    private func matchesTempo(_ sample: Sample) -> Bool {
        switch tempoFilter {
        case .all: return true
        case .freeTime: return sample.tempo == nil
        case .hasTempo: return sample.tempo != nil
        }
    }

    private func matchesProcessed(_ sample: Sample) -> Bool {
        switch processedFilter {
        case .all: return true
        case .processed: return sample.isProcessed
        case .unprocessed: return !sample.isProcessed
        }
    }

    private func matchesTags(_ sample: Sample) -> Bool {
        guard !selectedTagIds.isEmpty else { return true }

        // Group selected tag IDs by their tag group
        var tagIdsByGroup: [UUID: Set<UUID>] = [:]
        for group in tagGroups {
            for tag in group.tags {
                if selectedTagIds.contains(tag.id) {
                    tagIdsByGroup[group.id, default: []].insert(tag.id)
                }
            }
        }

        // AND across groups, OR within each group
        let sampleTagIds = Set(sample.tags.map(\.id))
        for (_, groupTagIds) in tagIdsByGroup {
            if sampleTagIds.isDisjoint(with: groupTagIds) {
                return false
            }
        }
        return true
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search samples and tags...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 12) {
                keyFilterMenu
                tempoFilterPicker
                processedFilterPicker
                tagFilterButton
                browseByMenu

                if hasActiveFilters || browseByPrimary != nil {
                    Button("Clear All") {
                        clearFilters()
                        browseByPrimary = nil
                        browseBySecondary = nil
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var hasActiveFilters: Bool {
        !searchText.isEmpty || !selectedKeys.isEmpty
            || tempoFilter != .all || processedFilter != .all
            || !selectedTagIds.isEmpty
    }

    private func clearFilters() {
        searchText = ""
        selectedKeys.removeAll()
        tempoFilter = .all
        processedFilter = .all
        selectedTagIds.removeAll()
    }

    private var keyFilterMenu: some View {
        Menu {
            Button("All Keys") { selectedKeys.removeAll() }
            if !availableKeys.isEmpty {
                Divider()
                ForEach(availableKeys, id: \.self) { key in
                    Toggle(key, isOn: Binding(
                        get: { selectedKeys.contains(key) },
                        set: { isOn in
                            if isOn { selectedKeys.insert(key) }
                            else { selectedKeys.remove(key) }
                        }
                    ))
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "music.note")
                Text(selectedKeys.isEmpty ? "Key" : "Key (\(selectedKeys.count))")
                    .font(.callout)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
        }
    }

    private var tempoFilterPicker: some View {
        Menu {
            ForEach(TempoFilter.allCases, id: \.self) { filter in
                Button {
                    tempoFilter = filter
                } label: {
                    HStack {
                        Text(filter.rawValue)
                        if tempoFilter == filter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "metronome")
                Text(tempoFilter == .all ? "Tempo" : tempoFilter.rawValue)
                    .font(.callout)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
        }
    }

    private var processedFilterPicker: some View {
        Menu {
            ForEach(ProcessedFilter.allCases, id: \.self) { filter in
                Button {
                    processedFilter = filter
                } label: {
                    HStack {
                        Text(filter.rawValue)
                        if processedFilter == filter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                Text(processedFilter == .all ? "Status" : processedFilter.rawValue)
                    .font(.callout)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
        }
    }

    private var tagFilterButton: some View {
        Button {
            showTagFilterPopover.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "tag")
                Text(selectedTagIds.isEmpty ? "Tags" : "Tags (\(selectedTagIds.count))")
                    .font(.callout)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showTagFilterPopover, arrowEdge: .bottom) {
            tagFilterPopoverContent
        }
    }

    private var tagFilterPopoverContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Filter by Tags")
                    .font(.headline)
                Spacer()
                if !selectedTagIds.isEmpty {
                    Button("Clear") { selectedTagIds.removeAll() }
                        .font(.caption)
                }
            }
            .padding()

            Divider()

            if tagGroups.isEmpty {
                Text("No tag groups created yet.")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(tagGroups) { group in
                            Section {
                                ForEach(group.tags.sorted { $0.name < $1.name }) { tag in
                                    Toggle(isOn: Binding(
                                        get: { selectedTagIds.contains(tag.id) },
                                        set: { isOn in
                                            if isOn { selectedTagIds.insert(tag.id) }
                                            else { selectedTagIds.remove(tag.id) }
                                        }
                                    )) {
                                        HStack {
                                            Text(tag.name)
                                            Spacer()
                                            Text("\(group.code)-\(tag.code)")
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                    .padding(.leading, 8)
                                }
                            } header: {
                                Text("\(group.name) (\(group.code))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }

            Divider()

            Text("OR within groups, AND across groups")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(8)
        }
        .frame(width: 300, height: 350)
    }

    // MARK: - Browse By

    private var browseByMenu: some View {
        Menu {
            Button("Flat List") {
                browseByPrimary = nil
                browseBySecondary = nil
            }
            if !tagGroups.isEmpty {
                Divider()
                ForEach(tagGroups) { group in
                    Menu("Group by \(group.name)") {
                        Button("No subdivision") {
                            browseByPrimary = group.id
                            browseBySecondary = nil
                        }
                        Divider()
                        ForEach(tagGroups.filter { $0.id != group.id }) { secondary in
                            Button("Then by \(secondary.name)") {
                                browseByPrimary = group.id
                                browseBySecondary = secondary.id
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "list.bullet.indent")
                Text(browseByLabel)
                    .font(.callout)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(browseByPrimary != nil ? Color.accentColor.opacity(0.15) : Color.clear, in: Capsule())
            .background(.quaternary, in: Capsule())
        }
    }

    private var browseByLabel: String {
        guard let primaryId = browseByPrimary,
              let primary = tagGroups.first(where: { $0.id == primaryId }) else {
            return "Browse"
        }
        if let secondaryId = browseBySecondary,
           let secondary = tagGroups.first(where: { $0.id == secondaryId }) {
            return "\(primary.name) > \(secondary.name)"
        }
        return primary.name
    }

    private var groupedBrowseView: some View {
        let primaryGroup = tagGroups.first { $0.id == browseByPrimary }
        let secondaryGroup = browseBySecondary.flatMap { secId in tagGroups.first { $0.id == secId } }

        return List(selection: $selection) {
            if let primaryGroup = primaryGroup {
                let primaryTags = primaryGroup.tags.sorted { $0.name < $1.name }

                ForEach(primaryTags) { pTag in
                    let samplesWithTag = displayedSamples.filter { sample in
                        sample.tags.contains { $0.id == pTag.id }
                    }

                    if let secondaryGroup = secondaryGroup {
                        Section(pTag.name) {
                            let secondaryTags = secondaryGroup.tags.sorted { $0.name < $1.name }
                            ForEach(secondaryTags) { sTag in
                                let subSamples = samplesWithTag.filter { sample in
                                    sample.tags.contains { $0.id == sTag.id }
                                }
                                if !subSamples.isEmpty {
                                    DisclosureGroup("\(sTag.name) (\(subSamples.count))") {
                                        ForEach(subSamples) { sample in
                                            sampleRow(sample)
                                        }
                                    }
                                }
                            }

                            let untaggedSub = samplesWithTag.filter { sample in
                                !sample.tags.contains { tag in secondaryGroup.tags.contains { $0.id == tag.id } }
                            }
                            if !untaggedSub.isEmpty {
                                DisclosureGroup("Untagged (\(untaggedSub.count))") {
                                    ForEach(untaggedSub) { sample in
                                        sampleRow(sample)
                                    }
                                }
                            }
                        }
                    } else {
                        Section("\(pTag.name) (\(samplesWithTag.count))") {
                            ForEach(samplesWithTag) { sample in
                                sampleRow(sample)
                            }
                        }
                    }
                }

                // Untagged in primary group
                let untaggedPrimary = displayedSamples.filter { sample in
                    !sample.tags.contains { tag in primaryGroup.tags.contains { $0.id == tag.id } }
                }
                if !untaggedPrimary.isEmpty {
                    Section("Untagged (\(untaggedPrimary.count))") {
                        ForEach(untaggedPrimary) { sample in
                            sampleRow(sample)
                        }
                    }
                }
            }
        }
    }

    private func sampleRow(_ sample: Sample) -> some View {
        let missing = !vaultFileExists(for: sample)
        return HStack(spacing: 8) {
            if missing {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            }
            Text(sample.name)
                .foregroundStyle(missing ? .secondary : .primary)
            Spacer()
            Text(KeyHelper.shortDisplay(for: sample.key))
                .font(.caption)
                .foregroundStyle(.secondary)
            if sample.pitchSemitones != 0 {
                Text("\(sample.pitchSemitones > 0 ? "+" : "")\(sample.pitchSemitones)st")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tag(sample.persistentModelID)
        .contextMenu {
            if missing {
                Button("Locate File...") { locateFile(for: sample) }
            }
            let count = selection.contains(sample.persistentModelID) ? selection.count : 1
            Button("Delete \(count > 1 ? "\(count) Samples" : "Sample")...") {
                if !selection.contains(sample.persistentModelID) {
                    selection = [sample.persistentModelID]
                }
                showDeleteAlert = true
            }
        }
    }

    // MARK: - Table

    private func vaultFileExists(for sample: Sample) -> Bool {
        let filename = FilenameEncoder.encode(sample: sample)
        return VaultManager.fileExistsInVault(filename: filename, vaultPath: vaultPath)
    }

    private func locateFile(for sample: Sample) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Locate the file for \"\(sample.name)\""
        panel.prompt = "Use This File"

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }

        let filename = FilenameEncoder.encode(sample: sample)
        let targetURL = VaultManager.vaultURL(from: vaultPath).appendingPathComponent(filename)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
        } catch {
            // File already exists or other error
        }
    }

    private func deleteSelectedSamples() {
        let vaultDir = VaultManager.vaultURL(from: vaultPath)
        for sample in allSamples where selection.contains(sample.persistentModelID) {
            let filename = FilenameEncoder.encode(sample: sample)
            let fileURL = vaultDir.appendingPathComponent(filename)
            try? FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
            modelContext.delete(sample)
        }
        selection.removeAll()
    }

    @ViewBuilder
    private func sortHeader(_ field: SortField, width: CGFloat = 0, flex: Bool = false) -> some View {
        let button = Button {
            if sortField == field { sortAscending.toggle() }
            else { sortField = field; sortAscending = true }
        } label: {
            HStack(spacing: 2) {
                Text(field.rawValue)
                if sortField == field {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .imageScale(.small)
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(sortField == field ? .primary : .secondary)
        }
        .buttonStyle(.plain)

        if flex {
            button.frame(maxWidth: .infinity, alignment: .leading)
        } else {
            button.frame(width: width, alignment: .leading)
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            sortHeader(.name, flex: true)
            sortHeader(.key, width: 70)
            sortHeader(.tempo, width: 70)
            sortHeader(.tags, width: 100)
            sortHeader(.pitch, width: 50)
            sortHeader(.trim, width: 55)
            sortHeader(.dateImported, width: 90)
        }
        .padding(.leading, 28)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }

    private var sampleTable: some View {
        VStack(spacing: 0) {
            columnHeader
            Divider()
            List(selection: $selection) {
                ForEach(displayedSamples) { sample in
                    let missing = !vaultFileExists(for: sample)
                    HStack(spacing: 0) {
                        HStack(spacing: 4) {
                            if missing {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                                    .help("Vault file missing")
                            }
                            Text(sample.name)
                                .foregroundStyle(missing ? .secondary : .primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.tail)

                        Text(KeyHelper.shortDisplay(for: sample.key))
                            .foregroundStyle(sample.key == nil ? .tertiary : .primary)
                            .frame(width: 70, alignment: .leading)
                        Text(sample.tempo.map { "\($0)" } ?? "Free")
                            .foregroundStyle(sample.tempo == nil ? .tertiary : .primary)
                            .frame(width: 70, alignment: .leading)
                        Text(tagSummary(for: sample))
                            .foregroundStyle(sample.tags.isEmpty ? .tertiary : .secondary)
                            .frame(width: 100, alignment: .leading)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(sample.pitchSemitones != 0 ? "\(sample.pitchSemitones > 0 ? "+" : "")\(sample.pitchSemitones)st" : "—")
                            .foregroundStyle(sample.pitchSemitones == 0 ? .tertiary : .primary)
                            .frame(width: 50, alignment: .leading)
                        Text(sample.trimDb != 0 ? String(format: "%+.0fdB", sample.trimDb) : "—")
                            .foregroundStyle(sample.trimDb == 0 ? .tertiary : .primary)
                            .frame(width: 55, alignment: .leading)
                        Text(sample.dateImported, style: .date)
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .leading)
                    }
                    .font(.callout)
                    .tag(sample.persistentModelID)
                    .contextMenu {
                        if missing {
                            Button("Locate File...") { locateFile(for: sample) }
                        }
                        let count = selection.contains(sample.persistentModelID) ? selection.count : 1
                        Button("Delete \(count > 1 ? "\(count) Samples" : "Sample")...") {
                            if !selection.contains(sample.persistentModelID) {
                                selection = [sample.persistentModelID]
                            }
                            showDeleteAlert = true
                        }
                    }
                }
            }
        }
    }

    private func tagSummary(for sample: Sample) -> String {
        guard !sample.tags.isEmpty else { return "—" }
        let names = sample.tags
            .sorted { $0.name < $1.name }
            .map(\.name)
        if names.count <= 3 {
            return names.joined(separator: ", ")
        }
        return names.prefix(2).joined(separator: ", ") + " +\(names.count - 2)"
    }
}

