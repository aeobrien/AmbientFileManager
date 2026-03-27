import SwiftUI
import SwiftData

struct TagManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TagGroup.name) private var tagGroups: [TagGroup]

    @State private var activeSheet: TagManagerSheet?
    @State private var groupToDelete: TagGroup?
    @State private var tagToDelete: Tag?
    @State private var showDeleteGroupAlert = false
    @State private var showDeleteTagAlert = false

    enum TagManagerSheet: Identifiable {
        case createGroup
        case editGroup(TagGroup)
        case createTag(group: TagGroup)
        case editTag(Tag)

        var id: String {
            switch self {
            case .createGroup: return "createGroup"
            case .editGroup(let g): return "editGroup-\(g.id)"
            case .createTag(let g): return "createTag-\(g.id)"
            case .editTag(let t): return "editTag-\(t.id)"
            }
        }
    }

    var body: some View {
        Group {
            if tagGroups.isEmpty {
                ContentUnavailableView {
                    Label("No Tag Groups", systemImage: "tag")
                } description: {
                    Text("Create a tag group to start organising your samples.")
                } actions: {
                    Button("Create Tag Group") {
                        activeSheet = .createGroup
                    }
                }
            } else {
                List {
                    ForEach(tagGroups) { group in
                        Section {
                            ForEach(sortedTags(for: group)) { tag in
                                HStack {
                                    Text(tag.name)
                                    Spacer()
                                    Text(tag.code)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                .contextMenu {
                                    Button("Rename...") { activeSheet = .editTag(tag) }
                                    Divider()
                                    Button("Delete...") {
                                        tagToDelete = tag
                                        showDeleteTagAlert = true
                                    }
                                }
                            }

                            Button {
                                activeSheet = .createTag(group: group)
                            } label: {
                                Label("Add Tag", systemImage: "plus")
                            }
                            .buttonStyle(.borderless)
                        } header: {
                            HStack {
                                Text(group.name)
                                Text(group.code)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    activeSheet = .createTag(group: group)
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                            }
                            .contextMenu {
                                Button("Rename Group...") { activeSheet = .editGroup(group) }
                                Button("Add Tag...") { activeSheet = .createTag(group: group) }
                                Divider()
                                Button("Delete Group...") {
                                    groupToDelete = group
                                    showDeleteGroupAlert = true
                                }
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    activeSheet = .createGroup
                } label: {
                    Label("New Tag Group", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Tag Manager")
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .createGroup:
                TagGroupFormSheet(mode: .create)
            case .editGroup(let group):
                TagGroupFormSheet(mode: .edit(group))
            case .createTag(let group):
                TagFormSheet(mode: .create(group: group))
            case .editTag(let tag):
                TagFormSheet(mode: .edit(tag))
            }
        }
        .alert("Delete Tag Group?", isPresented: $showDeleteGroupAlert) {
            Button("Cancel", role: .cancel) { groupToDelete = nil }
            Button("Delete", role: .destructive) {
                if let group = groupToDelete {
                    deleteGroup(group)
                    groupToDelete = nil
                }
            }
        } message: {
            if let group = groupToDelete {
                let tagCount = group.tags.count
                let sampleCount = countAffectedSamples(for: group)
                if tagCount == 0 {
                    Text("This will delete the group \"\(group.name)\".")
                } else if sampleCount > 0 {
                    Text("This will delete \"\(group.name)\" and its \(tagCount) tag(s). \(sampleCount) sample(s) will have their filenames updated.")
                } else {
                    Text("This will delete \"\(group.name)\" and its \(tagCount) tag(s).")
                }
            }
        }
        .alert("Delete Tag?", isPresented: $showDeleteTagAlert) {
            Button("Cancel", role: .cancel) { tagToDelete = nil }
            Button("Delete", role: .destructive) {
                if let tag = tagToDelete {
                    deleteTag(tag)
                    tagToDelete = nil
                }
            }
        } message: {
            if let tag = tagToDelete {
                let sampleCount = tag.samples.count
                if sampleCount > 0 {
                    Text("This will remove the tag \"\(tag.name)\" from \(sampleCount) sample(s) and update their filenames.")
                } else {
                    Text("This will delete the tag \"\(tag.name)\".")
                }
            }
        }
    }

    private func sortedTags(for group: TagGroup) -> [Tag] {
        group.tags.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func deleteGroup(_ group: TagGroup) {
        modelContext.delete(group)
    }

    private func deleteTag(_ tag: Tag) {
        modelContext.delete(tag)
    }

    private func countAffectedSamples(for group: TagGroup) -> Int {
        var sampleIds = Set<UUID>()
        for tag in group.tags {
            for sample in tag.samples {
                sampleIds.insert(sample.id)
            }
        }
        return sampleIds.count
    }
}
