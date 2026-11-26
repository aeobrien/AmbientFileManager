import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID
    var name: String
    var code: String

    var group: TagGroup?

    @Relationship(inverse: \Sample.tags)
    var samples: [Sample] = []

    init(name: String, code: String, group: TagGroup? = nil) {
        self.id = UUID()
        self.name = name
        self.code = code
        self.group = group
    }
}
