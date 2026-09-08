import Foundation

enum FilenameEncoder {
    /// Generate an encoded filename from a Sample's current state.
    static func encode(sample: Sample) -> String {
        let tagCodes: [(groupCode: String, tagCode: String)] = sample.tags.compactMap { tag in
            guard let group = tag.group else { return nil }
            return (groupCode: group.code, tagCode: tag.code)
        }
        return encode(
            name: sample.name,
            key: sample.key,
            tempo: sample.tempo,
            tagCodes: tagCodes,
            version: sample.version,
            fileExtension: sample.fileExtension
        )
    }

    /// Generate an encoded filename from individual components.
    static func encode(
        name: String,
        key: String?,
        tempo: Int?,
        tagCodes: [(groupCode: String, tagCode: String)],
        version: Int,
        fileExtension: String
    ) -> String {
        var parts: [String] = []

        parts.append(sanitizeName(name))

        if let key = key, !key.isEmpty {
            parts.append(key)
        }

        if let tempo = tempo {
            parts.append("\(tempo)bpm")
        }

        let sortedTags = tagCodes.sorted { a, b in
            if a.groupCode == b.groupCode {
                return a.tagCode < b.tagCode
            }
            return a.groupCode < b.groupCode
        }
        for tag in sortedTags {
            parts.append("\(tag.groupCode)-\(tag.tagCode)")
        }

        parts.append(String(format: "v%02d", version))

        let stem = parts.joined(separator: "_")
        let filename = "\(stem).\(fileExtension)"

        if filename.count > 255 {
            // The filename exceeds the OS limit — this is surfaced to the user elsewhere.
            // We still return it so the caller can detect and warn.
        }

        return filename
    }

    /// Sanitize a name for use in filenames.
    /// Replaces spaces and underscores with hyphens, strips non-alphanumeric characters
    /// (except hyphens), collapses consecutive hyphens, and trims leading/trailing hyphens.
    static func sanitizeName(_ name: String) -> String {
        var result = name
        result = result.replacingOccurrences(of: " ", with: "-")
        result = result.replacingOccurrences(of: "_", with: "-")
        result = String(result.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == "-"
        }.map { Character($0) })
        while result.contains("--") {
            result = result.replacingOccurrences(of: "--", with: "-")
        }
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if result.isEmpty {
            result = "Untitled"
        }
        return result
    }
}
