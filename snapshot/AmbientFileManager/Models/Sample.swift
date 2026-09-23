import Foundation
import SwiftData

@Model
final class Sample {
    var id: UUID
    var name: String
    var originalFilename: String
    var key: String?
    var tempo: Int?
    var version: Int
    var isProcessed: Bool
    var dateImported: Date
    var fileExtension: String

    var trimDb: Double = 0
    var pitchSemitones: Int = 0

    var tags: [Tag] = []

    // Computed properties for Table sorting (non-optional wrappers)
    var keySortable: String { key ?? "" }
    var tempoSortable: Int { tempo ?? Int.max }
    var tagCount: Int { tags.count }

    init(
        name: String,
        originalFilename: String,
        key: String? = nil,
        tempo: Int? = nil,
        version: Int = 1,
        isProcessed: Bool = false,
        fileExtension: String
    ) {
        self.id = UUID()
        self.name = name
        self.originalFilename = originalFilename
        self.key = key
        self.tempo = tempo
        self.version = version
        self.isProcessed = isProcessed
        self.dateImported = Date()
        self.fileExtension = fileExtension
    }
}
