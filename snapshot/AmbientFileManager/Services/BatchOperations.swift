import Foundation
import SwiftData

// MARK: - Undo Support

struct SampleSnapshot {
    let persistentId: PersistentIdentifier
    let name: String
    let key: String?
    let tempo: Int?
    let isProcessed: Bool
    let tagIds: Set<UUID>
    let vaultFilename: String
}

struct UndoOperation {
    let description: String
    let snapshots: [SampleSnapshot]
    let vaultPath: String
}

@Observable
class AppUndoManager {
    private var stack: [UndoOperation] = []
    private let maxDepth = 20

    var canUndo: Bool { !stack.isEmpty }
    var undoDescription: String { stack.last?.description ?? "" }

    func record(_ operation: UndoOperation) {
        stack.append(operation)
        if stack.count > maxDepth {
            stack.removeFirst()
        }
    }

    func undo(modelContext: ModelContext) {
        guard let op = stack.popLast() else { return }

        // Fetch all samples and tags fresh from the context
        let allSamples = (try? modelContext.fetch(FetchDescriptor<Sample>())) ?? []
        let allTags = (try? modelContext.fetch(FetchDescriptor<Tag>())) ?? []

        for snapshot in op.snapshots {
            guard let sample = allSamples.first(where: { $0.persistentModelID == snapshot.persistentId }) else { continue }

            // Capture current filename before reverting
            let currentFilename = FilenameEncoder.encode(sample: sample)

            // Restore all properties
            sample.name = snapshot.name
            sample.key = snapshot.key
            sample.tempo = snapshot.tempo
            sample.isProcessed = snapshot.isProcessed

            // Restore tags: clear and re-add from snapshot
            let currentTagIds = Set(sample.tags.map(\.id))
            let snapshotTagIds = snapshot.tagIds

            // Remove tags not in snapshot
            for tagId in currentTagIds where !snapshotTagIds.contains(tagId) {
                sample.tags.removeAll { $0.id == tagId }
            }
            // Add tags in snapshot but not currently present
            for tagId in snapshotTagIds where !currentTagIds.contains(tagId) {
                if let tag = allTags.first(where: { $0.id == tagId }) {
                    sample.tags.append(tag)
                }
            }

            // Rename vault file back
            let restoredFilename = snapshot.vaultFilename
            if currentFilename != restoredFilename {
                try? VaultManager.renameInVault(from: currentFilename, to: restoredFilename, vaultPath: op.vaultPath)
            }
        }

        try? modelContext.save()
    }
}

// MARK: - Batch Operations

enum BatchOperations {

    static func captureSnapshots(for samples: [Sample]) -> [SampleSnapshot] {
        samples.map { sample in
            SampleSnapshot(
                persistentId: sample.persistentModelID,
                name: sample.name,
                key: sample.key,
                tempo: sample.tempo,
                isProcessed: sample.isProcessed,
                tagIds: Set(sample.tags.map(\.id)),
                vaultFilename: FilenameEncoder.encode(sample: sample)
            )
        }
    }

    static func applyTags(_ tags: [Tag], to samples: [Sample], vaultPath: String, undoManager: AppUndoManager) {
        let snapshots = captureSnapshots(for: samples)
        undoManager.record(UndoOperation(description: "Apply Tags", snapshots: snapshots, vaultPath: vaultPath))

        for sample in samples {
            for tag in tags {
                if !sample.tags.contains(where: { $0.id == tag.id }) {
                    sample.tags.append(tag)
                }
            }
            regenerateFilename(for: sample, vaultPath: vaultPath, oldFilename: snapshots.first { $0.persistentId == sample.persistentModelID }?.vaultFilename)
        }
    }

    static func removeTags(_ tags: [Tag], from samples: [Sample], vaultPath: String, undoManager: AppUndoManager) {
        let snapshots = captureSnapshots(for: samples)
        undoManager.record(UndoOperation(description: "Remove Tags", snapshots: snapshots, vaultPath: vaultPath))

        let removeIds = Set(tags.map(\.id))
        for sample in samples {
            sample.tags.removeAll { removeIds.contains($0.id) }
            regenerateFilename(for: sample, vaultPath: vaultPath, oldFilename: snapshots.first { $0.persistentId == sample.persistentModelID }?.vaultFilename)
        }
    }

    static func setKey(_ key: String?, on samples: [Sample], vaultPath: String, undoManager: AppUndoManager) {
        let snapshots = captureSnapshots(for: samples)
        undoManager.record(UndoOperation(description: "Set Key", snapshots: snapshots, vaultPath: vaultPath))

        for sample in samples {
            sample.key = key
            regenerateFilename(for: sample, vaultPath: vaultPath, oldFilename: snapshots.first { $0.persistentId == sample.persistentModelID }?.vaultFilename)
        }
    }

    static func setTempo(_ tempo: Int?, on samples: [Sample], vaultPath: String, undoManager: AppUndoManager) {
        let snapshots = captureSnapshots(for: samples)
        undoManager.record(UndoOperation(description: "Set Tempo", snapshots: snapshots, vaultPath: vaultPath))

        for sample in samples {
            sample.tempo = tempo
            regenerateFilename(for: sample, vaultPath: vaultPath, oldFilename: snapshots.first { $0.persistentId == sample.persistentModelID }?.vaultFilename)
        }
    }

    static func markAsProcessed(_ samples: [Sample], vaultPath: String, undoManager: AppUndoManager) {
        let snapshots = captureSnapshots(for: samples)
        undoManager.record(UndoOperation(description: "Mark as Processed", snapshots: snapshots, vaultPath: vaultPath))

        for sample in samples {
            sample.isProcessed = true
            regenerateFilename(for: sample, vaultPath: vaultPath, oldFilename: snapshots.first { $0.persistentId == sample.persistentModelID }?.vaultFilename)
        }
    }

    /// Regenerate the vault filename for a sample after metadata/tag changes.
    /// If oldFilename is provided and differs from the new filename, renames the file on disk.
    static func regenerateFilename(for sample: Sample, vaultPath: String, oldFilename: String?) {
        let newFilename = FilenameEncoder.encode(sample: sample)
        guard let oldFilename = oldFilename, oldFilename != newFilename else { return }
        do {
            try VaultManager.renameInVault(from: oldFilename, to: newFilename, vaultPath: vaultPath)
        } catch {
            // Per-file failure: the DB is updated but the vault file has the old name.
            // This is surfaced via the missing-file indicator in the library.
        }
    }

    /// Rename vault files for all samples affected by a tag or group code change.
    static func regenerateFilenames(for samples: [Sample], oldFilenames: [PersistentIdentifier: String], vaultPath: String) {
        for sample in samples {
            let oldFilename = oldFilenames[sample.persistentModelID]
            regenerateFilename(for: sample, vaultPath: vaultPath, oldFilename: oldFilename)
        }
    }
}
