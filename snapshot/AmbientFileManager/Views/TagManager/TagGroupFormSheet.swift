import SwiftUI
import SwiftData

struct TagGroupFormSheet: View {
    enum Mode {
        case create
        case edit(TagGroup)
    }

    let mode: Mode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TagGroup.name) private var allGroups: [TagGroup]

    @State private var name: String
    @State private var code: String
    @State private var validationError: String?

    private let originalCode: String?

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _code = State(initialValue: "")
            originalCode = nil
        case .edit(let group):
            _name = State(initialValue: group.name)
            _code = State(initialValue: group.code)
            originalCode = group.code
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && code.count >= 2 && code.count <= 3
    }

    private var codeChanged: Bool {
        guard let original = originalCode else { return false }
        return code.uppercased() != original.uppercased()
    }

    private var affectedSampleCount: Int {
        guard case .edit(let group) = mode else { return 0 }
        var ids = Set<UUID>()
        for tag in group.tags {
            for sample in tag.samples {
                ids.insert(sample.id)
            }
        }
        return ids.count
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Rename Tag Group" : "New Tag Group")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("e.g. Sound Bath", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Code (2-3 characters)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("e.g. SB", text: $code)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: code) { _, newValue in
                            let filtered = String(newValue.prefix(3))
                                .uppercased()
                                .filter { $0.isLetter || $0.isNumber }
                            if filtered != code {
                                code = filtered
                            }
                        }
                }
            }

            if isEditing && codeChanged {
                let count = affectedSampleCount
                Text("Changing the code will update filenames for \(count) sample(s).")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Create") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    private func save() {
        validationError = nil
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedCode = code.trimmingCharacters(in: .whitespaces).uppercased()

        guard !trimmedName.isEmpty else {
            validationError = "Name cannot be empty."
            return
        }

        guard trimmedCode.count >= 2, trimmedCode.count <= 3 else {
            validationError = "Code must be 2-3 characters."
            return
        }

        guard trimmedCode.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            validationError = "Code must contain only letters and numbers."
            return
        }

        let editingId: UUID? = if case .edit(let group) = mode { group.id } else { nil }
        let isDuplicate = allGroups.contains { group in
            group.code.uppercased() == trimmedCode && group.id != editingId
        }

        if isDuplicate {
            validationError = "A tag group with code \"\(trimmedCode)\" already exists."
            return
        }

        switch mode {
        case .create:
            let group = TagGroup(name: trimmedName, code: trimmedCode)
            modelContext.insert(group)
            try? modelContext.save()
        case .edit(let group):
            let codeIsChanging = group.code.uppercased() != trimmedCode
            var oldFilenames: [PersistentIdentifier: String] = [:]

            if codeIsChanging {
                // Capture old filenames for all affected samples before changing the code
                let affectedSamples = group.tags.flatMap(\.samples)
                for sample in affectedSamples {
                    oldFilenames[sample.persistentModelID] = FilenameEncoder.encode(sample: sample)
                }
            }

            group.name = trimmedName
            group.code = trimmedCode

            if codeIsChanging {
                let vaultPath = UserDefaults.standard.string(forKey: "vaultPath") ?? ""
                let affectedSamples = group.tags.flatMap(\.samples)
                BatchOperations.regenerateFilenames(for: affectedSamples, oldFilenames: oldFilenames, vaultPath: vaultPath)
            }
            try? modelContext.save()
        }

        dismiss()
    }
}
