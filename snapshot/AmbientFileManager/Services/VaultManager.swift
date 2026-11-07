import Foundation

enum VaultManager {
    static let supportedExtensions: Set<String> = ["wav", "aiff", "aif", "mp3", "m4a", "caf", "flac"]

    static func vaultURL(from path: String) -> URL {
        URL(fileURLWithPath: path)
    }

    /// Recursively discover audio files from a list of file and folder URLs.
    static func discoverAudioFiles(from urls: [URL]) -> [URL] {
        var result: [URL] = []
        let fm = FileManager.default

        for url in urls {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                if let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for case let fileURL as URL in enumerator {
                        if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                            result.append(fileURL)
                        }
                    }
                }
            } else if supportedExtensions.contains(url.pathExtension.lowercased()) {
                result.append(url)
            }
        }

        return result
    }

    /// Check if a file with the given name exists in the vault.
    static func fileExistsInVault(filename: String, vaultPath: String) -> Bool {
        let target = vaultURL(from: vaultPath).appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: target.path)
    }

    /// Copy a source file into the vault with the given filename.
    @discardableResult
    static func copyToVault(from sourceURL: URL, filename: String, vaultPath: String) throws -> URL {
        let target = vaultURL(from: vaultPath).appendingPathComponent(filename)
        try FileManager.default.copyItem(at: sourceURL, to: target)
        return target
    }

    /// Rename a file in the vault.
    static func renameInVault(from oldFilename: String, to newFilename: String, vaultPath: String) throws {
        let vaultDir = vaultURL(from: vaultPath)
        let oldURL = vaultDir.appendingPathComponent(oldFilename)
        let newURL = vaultDir.appendingPathComponent(newFilename)
        try FileManager.default.moveItem(at: oldURL, to: newURL)
    }

    /// Check whether a URL points to a supported audio file.
    static func isAudioFile(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }
}
