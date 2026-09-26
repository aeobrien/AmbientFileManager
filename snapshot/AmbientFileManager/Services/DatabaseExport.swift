import Foundation
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// JSON-based database export and import, independent of SQLite.
enum DatabaseExport {

    // MARK: - Export

    struct ExportedDatabase: Codable {
        var exportDate: Date
        var appVersion: String = "1.0"
        var tagGroups: [ExportedTagGroup]
        var samples: [ExportedSample]
    }

    struct ExportedTagGroup: Codable {
        var id: UUID
        var name: String
        var code: String
        var tags: [ExportedTag]
    }

    struct ExportedTag: Codable {
        var id: UUID
        var name: String
        var code: String
    }

    struct ExportedSample: Codable {
        var id: UUID
        var name: String
        var originalFilename: String
        var key: String?
        var tempo: Int?
        var version: Int
        var isProcessed: Bool
        var dateImported: Date
        var fileExtension: String
        var trimDb: Double
        var pitchSemitones: Int
        var tagIds: [UUID]
    }

    /// Export all data to a JSON file.
    static func exportToJSON(modelContext: ModelContext) throws -> Data {
        let allGroups = try modelContext.fetch(FetchDescriptor<TagGroup>(sortBy: [SortDescriptor(\.name)]))
        let allSamples = try modelContext.fetch(FetchDescriptor<Sample>(sortBy: [SortDescriptor(\.name)]))

        let exportedGroups = allGroups.map { group in
            ExportedTagGroup(
                id: group.id,
                name: group.name,
                code: group.code,
                tags: group.tags.sorted(by: { $0.name < $1.name }).map { tag in
                    ExportedTag(id: tag.id, name: tag.name, code: tag.code)
                }
            )
        }

        let exportedSamples = allSamples.map { sample in
            ExportedSample(
                id: sample.id,
                name: sample.name,
                originalFilename: sample.originalFilename,
                key: sample.key,
                tempo: sample.tempo,
                version: sample.version,
                isProcessed: sample.isProcessed,
                dateImported: sample.dateImported,
                fileExtension: sample.fileExtension,
                trimDb: sample.trimDb,
                pitchSemitones: sample.pitchSemitones,
                tagIds: sample.tags.map(\.id)
            )
        }

        let db = ExportedDatabase(
            exportDate: Date(),
            tagGroups: exportedGroups,
            samples: exportedSamples
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(db)
    }

    /// Export to a user-chosen file.
    static func exportToFile(modelContext: ModelContext) throws -> URL? {
        let data = try exportToJSON(modelContext: modelContext)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "AmbientFileManager-backup.json"
        panel.prompt = "Export"
        panel.message = "Export database as JSON"

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        try data.write(to: url)
        return url
    }

    // MARK: - Import

    /// Import from a JSON file, merging with existing data.
    /// New tag groups/tags are created. Existing ones (matched by UUID) are updated.
    /// New samples are created. Existing ones (matched by UUID) are updated.
    static func importFromFile(modelContext: ModelContext) throws -> (groups: Int, samples: Int)? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        panel.message = "Import database from JSON backup"

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let data = try Data(contentsOf: url)
        return try importFromJSON(data: data, modelContext: modelContext)
    }

    static func importFromJSON(data: Data, modelContext: ModelContext) throws -> (groups: Int, samples: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let db = try decoder.decode(ExportedDatabase.self, from: data)

        // Fetch existing data
        let existingGroups = try modelContext.fetch(FetchDescriptor<TagGroup>())
        let existingSamples = try modelContext.fetch(FetchDescriptor<Sample>())
        let existingTags = try modelContext.fetch(FetchDescriptor<Tag>())

        let existingGroupMap = Dictionary(uniqueKeysWithValues: existingGroups.map { ($0.id, $0) })
        let existingSampleMap = Dictionary(uniqueKeysWithValues: existingSamples.map { ($0.id, $0) })
        var tagMap: [UUID: Tag] = Dictionary(uniqueKeysWithValues: existingTags.map { ($0.id, $0) })

        var groupCount = 0
        var sampleCount = 0

        // Import tag groups and tags
        for exportedGroup in db.tagGroups {
            let group: TagGroup
            if let existing = existingGroupMap[exportedGroup.id] {
                existing.name = exportedGroup.name
                existing.code = exportedGroup.code
                group = existing
            } else {
                group = TagGroup(name: exportedGroup.name, code: exportedGroup.code)
                group.id = exportedGroup.id
                modelContext.insert(group)
                groupCount += 1
            }

            for exportedTag in exportedGroup.tags {
                if let existingTag = tagMap[exportedTag.id] {
                    existingTag.name = exportedTag.name
                    existingTag.code = exportedTag.code
                    existingTag.group = group
                } else {
                    let tag = Tag(name: exportedTag.name, code: exportedTag.code, group: group)
                    tag.id = exportedTag.id
                    modelContext.insert(tag)
                    group.tags.append(tag)
                    tagMap[tag.id] = tag
                }
            }
        }

        // Import samples
        for exportedSample in db.samples {
            let sample: Sample
            if let existing = existingSampleMap[exportedSample.id] {
                existing.name = exportedSample.name
                existing.originalFilename = exportedSample.originalFilename
                existing.key = exportedSample.key
                existing.tempo = exportedSample.tempo
                existing.version = exportedSample.version
                existing.isProcessed = exportedSample.isProcessed
                existing.dateImported = exportedSample.dateImported
                existing.fileExtension = exportedSample.fileExtension
                existing.trimDb = exportedSample.trimDb
                existing.pitchSemitones = exportedSample.pitchSemitones
                sample = existing
            } else {
                sample = Sample(
                    name: exportedSample.name,
                    originalFilename: exportedSample.originalFilename,
                    key: exportedSample.key,
                    tempo: exportedSample.tempo,
                    version: exportedSample.version,
                    isProcessed: exportedSample.isProcessed,
                    fileExtension: exportedSample.fileExtension
                )
                sample.id = exportedSample.id
                sample.dateImported = exportedSample.dateImported
                sample.trimDb = exportedSample.trimDb
                sample.pitchSemitones = exportedSample.pitchSemitones
                modelContext.insert(sample)
                sampleCount += 1
            }

            // Restore tag associations
            sample.tags.removeAll()
            for tagId in exportedSample.tagIds {
                if let tag = tagMap[tagId] {
                    sample.tags.append(tag)
                }
            }
        }

        try modelContext.save()
        return (groups: groupCount, samples: sampleCount)
    }
}
