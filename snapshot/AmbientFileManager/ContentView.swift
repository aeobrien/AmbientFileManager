import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum SidebarItem: String, CaseIterable, Identifiable {
    case library = "Library"
    case inbox = "Inbox"
    case tagManager = "Tag Manager"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .library: return "music.note.list"
        case .inbox: return "tray"
        case .tagManager: return "tag"
        }
    }
}

struct ImportRequest: Identifiable {
    let id = UUID()
    let urls: [URL]
}

struct ContentView: View {
    @AppStorage("vaultPath") private var vaultPath: String = ""
    @Query(filter: #Predicate<Sample> { !$0.isProcessed }) private var unprocessedSamples: [Sample]
    @State private var selectedItem: SidebarItem? = .library
    @State private var showingVaultSetup = false
    @State private var importRequest: ImportRequest?
    @State private var isDropTargeted = false

    private var vaultIsAccessible: Bool {
        guard !vaultPath.isEmpty else { return false }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: vaultPath, isDirectory: &isDir) && isDir.boolValue
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                ForEach(SidebarItem.allCases) { item in
                    Label {
                        HStack {
                            Text(item.rawValue)
                            Spacer()
                            if item == .inbox && unprocessedSamples.count > 0 {
                                Text("\(unprocessedSamples.count)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(.red, in: Capsule())
                            }
                        }
                    } icon: {
                        Image(systemName: item.systemImage)
                    }
                    .tag(item)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            if vaultPath.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Vault Configured")
                        .font(.title2)
                    Text("Choose a folder to use as your sample vault.")
                        .foregroundStyle(.secondary)
                    Button("Choose Vault Folder...") {
                        showingVaultSetup = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !vaultIsAccessible {
                VStack(spacing: 16) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    Text("Vault Unavailable")
                        .font(.title2)
                    Text("The vault directory could not be found:\n\(vaultPath)")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    HStack {
                        Button("Change Vault Folder...") {
                            showingVaultSetup = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    detailView
                    AudioPlayerView()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openFilePicker()
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("i", modifiers: .command)
                .disabled(vaultPath.isEmpty)
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
            return true
        }
        .sheet(isPresented: $showingVaultSetup) {
            VaultSettingsView()
                .interactiveDismissDisabled(vaultPath.isEmpty)
        }
        .sheet(item: $importRequest) { request in
            ImportFlowView(sourceURLs: request.urls)
        }
        .onAppear {
            if vaultPath.isEmpty {
                showingVaultSetup = true
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .library:
            LibraryView()
        case .inbox:
            InboxView()
        case .tagManager:
            TagManagerView()
        case nil:
            Text("Select an item from the sidebar")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Select audio files or folders to import"
        panel.prompt = "Import"

        if panel.runModal() == .OK {
            importRequest = ImportRequest(urls: panel.urls)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    var resolved: URL?

                    if let url = item as? URL {
                        resolved = url
                    } else if let data = item as? Data {
                        resolved = URL(dataRepresentation: data, relativeTo: nil)
                        if resolved == nil,
                           let str = String(data: data, encoding: .utf8)?
                            .trimmingCharacters(in: .controlCharacters) {
                            resolved = URL(string: str) ?? URL(fileURLWithPath: str)
                        }
                    } else if let str = item as? String {
                        resolved = URL(string: str) ?? URL(fileURLWithPath: str)
                    }

                    if let url = resolved {
                        lock.lock()
                        urls.append(url)
                        lock.unlock()
                    }
                }
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty && !vaultPath.isEmpty {
                importRequest = ImportRequest(urls: urls)
            }
        }
    }
}
