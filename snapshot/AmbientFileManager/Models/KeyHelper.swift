import SwiftUI

// MARK: - Root Note

enum RootNote: String, CaseIterable, Identifiable {
    case C, Cs, D, Eb, E, F, Fs, G, Ab, A, Bb, B

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .C: "C"
        case .Cs: "C#"
        case .D: "D"
        case .Eb: "Eb"
        case .E: "E"
        case .F: "F"
        case .Fs: "F#"
        case .G: "G"
        case .Ab: "Ab"
        case .A: "A"
        case .Bb: "Bb"
        case .B: "B"
        }
    }

    var filenameCode: String {
        switch self {
        case .C: "C"
        case .Cs: "Cs"
        case .D: "D"
        case .Eb: "Eb"
        case .E: "E"
        case .F: "F"
        case .Fs: "Fs"
        case .G: "G"
        case .Ab: "Ab"
        case .A: "A"
        case .Bb: "Bb"
        case .B: "B"
        }
    }
}

// MARK: - Scale Type

enum ScaleType: String, CaseIterable, Identifiable {
    case major, minor, dorian, phrygian, lydian, mixolydian, locrian, majorPentatonic, minorPentatonic, fifths, atonal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .major: "Major (Ionian)"
        case .minor: "Minor (Aeolian)"
        case .dorian: "Dorian"
        case .phrygian: "Phrygian"
        case .lydian: "Lydian"
        case .mixolydian: "Mixolydian"
        case .locrian: "Locrian"
        case .majorPentatonic: "Major Pentatonic"
        case .minorPentatonic: "Minor Pentatonic"
        case .fifths: "Single Note / Fifths"
        case .atonal: "Atonal"
        }
    }

    var filenameCode: String {
        switch self {
        case .major: "maj"
        case .minor: "min"
        case .dorian: "dor"
        case .phrygian: "phr"
        case .lydian: "lyd"
        case .mixolydian: "mix"
        case .locrian: "loc"
        case .majorPentatonic: "majp"
        case .minorPentatonic: "minp"
        case .fifths: "5th"
        case .atonal: ""
        }
    }
}

// MARK: - Key Helper

enum KeyHelper {
    /// Parse a stored key string into root note and scale components.
    static func parse(_ key: String?) -> (root: RootNote?, scale: ScaleType?) {
        guard let key = key, !key.isEmpty else { return (nil, nil) }

        // Try each root note, longest display name first to match "Eb" before "E"
        let sortedRoots = RootNote.allCases.sorted { $0.displayName.count > $1.displayName.count }

        for root in sortedRoots {
            // Check both display name ("F#") and filename code ("Fs")
            let prefixes = Set([root.displayName, root.filenameCode])
            for prefix in prefixes {
                if key.hasPrefix(prefix) {
                    let remainder = String(key.dropFirst(prefix.count)).lowercased()
                    if remainder.isEmpty {
                        return (root, nil)
                    }
                    for scale in ScaleType.allCases {
                        if scale.filenameCode == remainder {
                            return (root, scale)
                        }
                    }
                    return (root, nil)
                }
            }
        }
        return (nil, nil)
    }

    /// Compose a key string from root note and scale for storage and filenames.
    static func compose(root: RootNote?, scale: ScaleType?) -> String? {
        guard let root = root else { return nil }
        let scaleCode = scale?.filenameCode ?? ""
        let result = root.filenameCode + scaleCode
        return result.isEmpty ? nil : result
    }

    /// Human-readable display string.
    static func displayString(for key: String?) -> String {
        let (root, scale) = parse(key)
        guard let root = root else { return "—" }
        if let scale = scale, scale != .atonal {
            return "\(root.displayName) \(scale.displayName)"
        }
        return root.displayName
    }

    /// Short display for table columns.
    static func shortDisplay(for key: String?) -> String {
        let (root, scale) = parse(key)
        guard let root = root else { return "—" }
        if let scale = scale, !scale.filenameCode.isEmpty {
            return "\(root.displayName)\(scale.filenameCode)"
        }
        return root.displayName
    }
}

// MARK: - Reusable Key Picker View

struct KeyPicker: View {
    @Binding var keyString: String?
    var onChanged: (() -> Void)? = nil

    @State private var rootNote: RootNote?
    @State private var scaleType: ScaleType?
    @State private var didLoad = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Picker("Root", selection: $rootNote) {
                    Text("No Key").tag(Optional<RootNote>.none)
                    ForEach(RootNote.allCases) { note in
                        Text(note.displayName).tag(Optional.some(note))
                    }
                }
                .frame(width: 90)

                Picker("Scale", selection: $scaleType) {
                    Text("—").tag(Optional<ScaleType>.none)
                    ForEach(ScaleType.allCases) { scale in
                        Text(scale.displayName).tag(Optional.some(scale))
                    }
                }
                .disabled(rootNote == nil)
            }
        }
        .onAppear {
            let (r, s) = KeyHelper.parse(keyString)
            rootNote = r
            scaleType = s
            didLoad = true
        }
        .onChange(of: keyString) { _, newValue in
            // External change (e.g. sample switched) — re-parse
            let (r, s) = KeyHelper.parse(newValue)
            if r != rootNote || s != scaleType {
                didLoad = false
                rootNote = r
                scaleType = s
                didLoad = true
            }
        }
        .onChange(of: rootNote) { _, _ in
            guard didLoad else { return }
            compose()
        }
        .onChange(of: scaleType) { _, _ in
            guard didLoad else { return }
            compose()
        }
    }

    private func compose() {
        keyString = KeyHelper.compose(root: rootNote, scale: scaleType)
        onChanged?()
    }
}
