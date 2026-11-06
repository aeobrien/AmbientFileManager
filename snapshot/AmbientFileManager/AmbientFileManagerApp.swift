import SwiftUI
import SwiftData

@main
struct AmbientFileManagerApp: App {
    @State private var audioPlayer = AudioPlayer()
    @State private var appUndoManager = AppUndoManager()

    init() {
        // Back up the database before SwiftData opens it (and potentially migrates)
        DatabaseBackup.backupOnLaunch()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(audioPlayer)
                .environment(appUndoManager)
        }
        .modelContainer(for: [Sample.self, TagGroup.self, Tag.self])

        Settings {
            SettingsView()
                .frame(minWidth: 500, minHeight: 400)
        }
        .modelContainer(for: [Sample.self, TagGroup.self, Tag.self])
    }
}
