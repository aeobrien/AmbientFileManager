import Foundation
import SwiftData

enum DatabaseBackup {

    /// The directory where automatic backups are stored.
    static var backupDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("AmbientFileManager/Backups")
    }

    /// Copy the current SQLite database files to a timestamped backup.
    /// Call this early in app launch, before any schema migration runs.
    static func backupOnLaunch() {
        let fm = FileManager.default

        // Find the SwiftData SQLite file
        guard let dbURL = findDatabaseURL() else { return }

        // Create backup directory
        let backupDir = backupDirectory
        try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)

        // Timestamped backup name
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let backupName = "backup_\(timestamp)"
        let backupFolder = backupDir.appendingPathComponent(backupName)
        try? fm.createDirectory(at: backupFolder, withIntermediateDirectories: true)

        // Copy all SQLite-related files (.sqlite, .sqlite-wal, .sqlite-shm)
        let dbDir = dbURL.deletingLastPathComponent()
        let dbName = dbURL.lastPathComponent

        for suffix in ["", "-wal", "-shm"] {
            let source = dbDir.appendingPathComponent(dbName + suffix)
            let dest = backupFolder.appendingPathComponent(dbName + suffix)
            if fm.fileExists(atPath: source.path) {
                try? fm.copyItem(at: source, to: dest)
            }
        }

        // Prune old backups — keep the most recent 10
        pruneBackups(keeping: 10)
    }

    /// Find the SwiftData SQLite database URL.
    static func findDatabaseURL() -> URL? {
        let fm = FileManager.default
        // SwiftData stores in Application Support by default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }

        // Look for .store files in the app support directory
        let candidates = [
            appSupport.appendingPathComponent("default.store"),
            // SwiftData may also use the container
        ]

        for url in candidates {
            if fm.fileExists(atPath: url.path) {
                return url
            }
        }

        // Search for any .store file in app support
        if let contents = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
            for url in contents {
                if url.pathExtension == "store" {
                    return url
                }
            }
        }

        return nil
    }

    /// Remove old backups, keeping the most recent N.
    private static func pruneBackups(keeping count: Int) {
        let fm = FileManager.default
        let backupDir = backupDirectory

        guard let contents = try? fm.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.creationDateKey]) else { return }

        let sorted = contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let dateB = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return dateA > dateB
            }

        for old in sorted.dropFirst(count) {
            try? fm.removeItem(at: old)
        }
    }

    /// List available backups with their dates.
    static func listBackups() -> [(name: String, date: Date, url: URL)] {
        let fm = FileManager.default
        let backupDir = backupDirectory

        guard let contents = try? fm.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.creationDateKey]) else { return [] }

        return contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .compactMap { url in
                let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return (name: url.lastPathComponent, date: date, url: url)
            }
            .sorted { $0.date > $1.date }
    }
}
