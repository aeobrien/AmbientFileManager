import Foundation

enum FolderGrouping {
    case flat
    case byTagGroup(TagGroup)
}

enum AudioExportMode {
    case original           // Copy files as-is
    case applyAdjustments   // Render with trim and pitch baked in
}

struct ExportConfiguration {
    var destinationPath: URL
    var folderGrouping: FolderGrouping
    var includeCodebook: Bool
    var audioMode: AudioExportMode = .original
}

struct ExportResult {
    var exportedCount: Int
    var failedCount: Int
    var errors: [String]
}

enum ExportService {

    static func export(samples: [Sample], tagGroups: [TagGroup], config: ExportConfiguration, vaultPath: String) -> ExportResult {
        let fm = FileManager.default
        var exported = 0
        var failed = 0
        var errors: [String] = []

        // Create destination directory if needed
        do {
            try fm.createDirectory(at: config.destinationPath, withIntermediateDirectories: true)
        } catch {
            return ExportResult(exportedCount: 0, failedCount: samples.count, errors: ["Could not create destination directory: \(error.localizedDescription)"])
        }

        let vaultDir = VaultManager.vaultURL(from: vaultPath)

        for sample in samples {
            let filename = FilenameEncoder.encode(sample: sample)
            let sourceURL = vaultDir.appendingPathComponent(filename)

            guard fm.fileExists(atPath: sourceURL.path) else {
                failed += 1
                errors.append("Missing vault file: \(filename)")
                continue
            }

            // Determine target directory
            let targetDir: URL
            switch config.folderGrouping {
            case .flat:
                targetDir = config.destinationPath

            case .byTagGroup(let group):
                let folderName = folderForSample(sample, inGroup: group)
                targetDir = config.destinationPath.appendingPathComponent(folderName)
            }

            // Create subdirectory if needed
            do {
                try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
            } catch {
                failed += 1
                errors.append("Could not create folder for \(filename): \(error.localizedDescription)")
                continue
            }

            let targetURL = targetDir.appendingPathComponent(filename)

            // Skip if file already exists at target
            if fm.fileExists(atPath: targetURL.path) {
                failed += 1
                errors.append("File already exists at destination: \(filename)")
                continue
            }

            do {
                let needsRendering = config.audioMode == .applyAdjustments
                    && (sample.pitchSemitones != 0 || sample.trimDb != 0)

                if needsRendering {
                    let rate = pow(2.0, Float(sample.pitchSemitones) / 12.0)
                    let volume = Float(pow(10.0, sample.trimDb / 20.0))
                    try AudioPlayer.renderToFile(inputURL: sourceURL, outputURL: targetURL, rate: rate, volume: volume)
                } else {
                    try fm.copyItem(at: sourceURL, to: targetURL)
                }
                exported += 1
            } catch {
                failed += 1
                errors.append("Failed to export \(filename): \(error.localizedDescription)")
            }
        }

        // Codebook
        if config.includeCodebook {
            let codebook = generateCodebook(tagGroups: tagGroups)
            let codebookURL = config.destinationPath.appendingPathComponent("codebook.json")
            do {
                let data = try JSONSerialization.data(withJSONObject: codebook, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: codebookURL)
            } catch {
                errors.append("Failed to write codebook.json: \(error.localizedDescription)")
            }
        }

        return ExportResult(exportedCount: exported, failedCount: failed, errors: errors)
    }

    private static func folderForSample(_ sample: Sample, inGroup group: TagGroup) -> String {
        let matchingTags = sample.tags
            .filter { $0.group?.id == group.id }
            .sorted { $0.code < $1.code }

        if let first = matchingTags.first {
            return "\(group.code)-\(first.code)"
        }
        return "Ungrouped"
    }

    private static func generateCodebook(tagGroups: [TagGroup]) -> [[String: Any]] {
        tagGroups.sorted { $0.name < $1.name }.map { group in
            [
                "name": group.name,
                "code": group.code,
                "tags": group.tags.sorted { $0.name < $1.name }.map { tag in
                    ["name": tag.name, "code": tag.code]
                }
            ] as [String: Any]
        }
    }
}
