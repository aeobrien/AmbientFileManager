import SwiftUI
import SwiftData

struct TagFormSheet: View {
    enum Mode {
        case create(group: TagGroup)
        case edit(Tag)
    }

    let mode: Mode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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
        case .edit(let tag):
            _name = State(initialValue: tag.name)
            _code = State(initialValue: tag.code)
            originalCode = tag.code
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

    private var parentGroup: TagGroup? {
        switch mode {
        case .create(let group): return group
        case .edit(let tag): return tag.group
        }
    }

    private var codeChanged: Bool {
        guard let original = originalCode else { return false }
        return code.uppercased() != original.uppercased()
    }

    private var affectedSampleCount: Int {
        guard case .edit(let tag) = mode else { return 0 }
        return tag.samples.count
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Rename Tag" : "New Tag")
                .font(.headline)

            if let group = parentGroup {
                Text("Group: \(group.name) (\(group.code))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("e.g. Arrival", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Code (2-3 characters)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("e.g. AR", text: $code)
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

        guard let group = parentGroup else {
            validationError = "No parent group found."
            return
        }

        let editingId: UUID? = if case .edit(let tag) = mode { tag.id } else { nil }
        let isDuplicate = group.tags.contains { tag in
            tag.code.uppercased() == trimmedCode && tag.id != editingId
        }

        if isDuplicate {
            validationError = "A tag with code \"\(trimmedCode)\" already exists in this group."
            return
        }

        switch mode {
        case .create(let group):
            let tag = Tag(name: trimmedName, code: trimmedCode, group: group)
            modelContext.insert(tag)
            group.tags.append(tag)
            try? modelContext.save()
        case .edit(let tag):
            let codeIsChanging = tag.code.uppercased() != trimmedCode
            var oldFilenames: [PersistentIdentifier: String] = [:]

            if codeIsChanging {
                for sample in tag.samples {
                    oldFilenames[sample.persistentModelID] = FilenameEncoder.encode(sample: sample)
                }
            }

            tag.name = trimmedName
            tag.code = trimmedCode

            if codeIsChanging {
                let vaultPath = UserDefaults.standard.string(forKey: "vaultPath") ?? ""
                BatchOperations.regenerateFilenames(for: tag.samples, oldFilenames: oldFilenames, vaultPath: vaultPath)
            }
            try? modelContext.save()
        }

        dismiss()
    }
}
