import Foundation
import SwiftData

@Model
final class TagGroup {
    var id: UUID
    var name: String
    var code: String

    @Relationship(deleteRule: .cascade, inverse: \Tag.group)
    var tags: [Tag] = []

    init(name: String, code: String) {
        self.id = UUID()
        self.name = name
        self.code = code
    }
}
