import SwiftUI

struct VaultSettingsView: View {
    @AppStorage("vaultPath") private var vaultPath: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Vault Location")
                .font(.title2)
                .fontWeight(.semibold)

            if vaultPath.isEmpty {
                Text("Choose a folder to store your audio samples.\nFiles will be copied here on import.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else {
                GroupBox {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.blue)
                        Text(vaultPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }

            HStack(spacing: 12) {
                Button(vaultPath.isEmpty ? "Choose Vault Folder..." : "Change Vault Folder...") {
                    chooseVaultFolder()
                }

                if !vaultPath.isEmpty {
                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(30)
        .frame(minWidth: 450)
    }

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
}
