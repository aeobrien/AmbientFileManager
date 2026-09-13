import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("vaultPath") private var vaultPath: String = ""

    @State private var exportMessage: String?
    @State private var importMessage: String?
    @State private var showImportConfirm = false
    @State private var backups: [(name: String, date: Date, url: URL)] = []

    var body: some View {
        TabView {
            vaultTab
                .tabItem { Label("Vault", systemImage: "folder") }
            dataTab
                .tabItem { Label("Data", systemImage: "externaldrive") }
        }
        .onAppear {
            backups = DatabaseBackup.listBackups()
        }
    }

    // MARK: - Vault Tab

    private var vaultTab: some View {
        Form {
            Section("Vault Location") {
                if vaultPath.isEmpty {
                    Text("No vault folder selected")
                        .foregroundStyle(.secondary)
                } else {
                    LabeledContent("Path") {
                        Text(vaultPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }
                Button(vaultPath.isEmpty ? "Choose Vault Folder..." : "Change Vault Folder...") {
                    chooseVaultFolder()
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Data Tab

    private var dataTab: some View {
        Form {
            Section("JSON Export / Import") {
                Text("Export the full database (samples, tags, metadata) as a human-readable JSON file. Use this to back up your data or transfer it between machines.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Export Database to JSON...") {
                        exportJSON()
                    }
                    Button("Import Database from JSON...") {
                        showImportConfirm = true
                    }
                }

                if let msg = exportMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                if let msg = importMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Section("Automatic Backups") {
                Text("A copy of the SQLite database is saved automatically each time the app launches. The 10 most recent backups are kept.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if backups.isEmpty {
                    Text("No backups found.")
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(backups, id: \.name) { backup in
                        HStack {
                            Text(backup.name)
                                .font(.system(.caption, design: .monospaced))
                            Spacer()
                            Text(backup.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button("Show Backups in Finder") {
                    NSWorkspace.shared.open(DatabaseBackup.backupDirectory)
                }
            }
        }
        .formStyle(.grouped)
        .alert("Import Database?", isPresented: $showImportConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Import") { importJSON() }
        } message: {
            Text("This will merge the imported data with your existing database. Existing records with matching IDs will be updated. New records will be added. No data will be deleted.")
        }
    }

    // MARK: - Actions

    private func chooseVaultFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Select a folder to use as your sample vault."

        if panel.runModal() == .OK, let url = panel.url {
            vaultPath = url.path(percentEncoded: false)
        }
    }

    private func exportJSON() {
        do {
            if let url = try DatabaseExport.exportToFile(modelContext: modelContext) {
                exportMessage = "Exported to \(url.lastPathComponent)"
            }
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importJSON() {
        do {
            if let result = try DatabaseExport.importFromFile(modelContext: modelContext) {
                importMessage = "Imported \(result.groups) new group(s), \(result.samples) new sample(s)"
            }
        } catch {
            importMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}
