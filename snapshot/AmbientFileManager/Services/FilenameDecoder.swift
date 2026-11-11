import Foundation

/// Result of decoding an encoded filename back into its components.
struct DecodedFilename {
    var name: String
    var key: String?
    var tempo: Int?
    var tagCodes: [(groupCode: String, tagCode: String)]
    var version: Int
    var fileExtension: String

    /// Tag codes that were found in the filename but don't match any known tags.
    var unrecognizedTagCodes: [(groupCode: String, tagCode: String)] = []
}

enum FilenameDecoder {

    // Patterns that match known non-tag underscore-separated segments.
    private static let tempoPattern = /^(\d+)bpm$/
    private static let versionPattern = /^v(\d+)$/
    // A tag code segment looks like "XX-YY" or "XXX-YY" or "XX-YYY" (2-3 char group, 2-3 char tag).
    private static let tagCodePattern = /^([A-Z0-9]{2,3})-([A-Z0-9]{2,3})$/

    /// Decode an encoded filename (with or without extension) into its components.
    static func decode(_ filename: String) -> DecodedFilename {
        let url = URL(fileURLWithPath: filename)
        let ext = url.pathExtension.lowercased()
        let stem: String
        if ext.isEmpty {
            stem = filename
        } else {
            stem = String(filename.dropLast(ext.count + 1))
        }

        let parts = stem.split(separator: "_", omittingEmptySubsequences: false).map(String.init)

        guard !parts.isEmpty else {
            return DecodedFilename(name: filename, tagCodes: [], version: 1, fileExtension: ext)
        }

        // Work backwards from the end to identify structured segments.
        var version: Int = 1
        var tempo: Int?
        var key: String?
        var tagCodes: [(groupCode: String, tagCode: String)] = []
        var nameEndIndex = parts.count // exclusive — everything before this is the name

        // Pass 1: Check last part for version
        if let last = parts.last, let match = last.wholeMatch(of: versionPattern) {
            version = Int(match.1) ?? 1
            nameEndIndex = parts.count - 1
        }

        // Pass 2: Scan backwards from nameEndIndex to find tag codes, tempo, and key
        var i = nameEndIndex - 1
        while i >= 1 {
            let part = parts[i]

            if let match = part.wholeMatch(of: tagCodePattern) {
                tagCodes.insert((groupCode: String(match.1), tagCode: String(match.2)), at: 0)
                i -= 1
                continue
            }

            if tempo == nil, let match = part.wholeMatch(of: tempoPattern) {
                tempo = Int(match.1)
                i -= 1
                continue
            }

            if key == nil {
                let (root, _) = KeyHelper.parse(part)
                if root != nil {
                    key = part
                    i -= 1
                    continue
                }
            }

            // This part doesn't match any known pattern — it's part of the name
            break
        }

        nameEndIndex = i + 1

        // Everything up to nameEndIndex is the name (rejoin with underscores, undo hyphen-for-space)
        let nameParts = parts[0..<nameEndIndex]
        var name = nameParts.joined(separator: "_")
        // The encoder replaces spaces/underscores with hyphens, so convert back
        name = name.replacingOccurrences(of: "-", with: " ")
        if name.isEmpty {
            name = "Untitled"
        }

        return DecodedFilename(
            name: name,
            key: key,
            tempo: tempo,
            tagCodes: tagCodes,
            version: version,
            fileExtension: ext
        )
    }

    /// Decode a filename and resolve tag codes against existing tags.
    /// Populates `unrecognizedTagCodes` for any codes not found in the provided tag groups.
    static func decodeAndResolve(_ filename: String, tagGroups: [TagGroup]) -> DecodedFilename {
        var result = decode(filename)

        // Build a lookup: "GROUPCODE-TAGCODE" → true
        var knownCodes: Set<String> = []
        for group in tagGroups {
            for tag in group.tags {
                knownCodes.insert("\(group.code.uppercased())-\(tag.code.uppercased())")
            }
        }

        var recognized: [(groupCode: String, tagCode: String)] = []
        var unrecognized: [(groupCode: String, tagCode: String)] = []

        for tc in result.tagCodes {
            let lookup = "\(tc.groupCode.uppercased())-\(tc.tagCode.uppercased())"
            if knownCodes.contains(lookup) {
                recognized.append(tc)
            } else {
                unrecognized.append(tc)
            }
        }

        result.tagCodes = recognized
        result.unrecognizedTagCodes = unrecognized
        return result
    }

    /// Find Tag objects matching decoded tag codes from the provided tag groups.
    static func resolveTags(from tagCodes: [(groupCode: String, tagCode: String)], in tagGroups: [TagGroup]) -> [Tag] {
        var result: [Tag] = []
        for tc in tagCodes {
            for group in tagGroups where group.code.uppercased() == tc.groupCode.uppercased() {
                if let tag = group.tags.first(where: { $0.code.uppercased() == tc.tagCode.uppercased() }) {
                    result.append(tag)
                }
            }
        }
        return result
    }
}
