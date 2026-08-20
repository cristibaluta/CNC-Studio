import Foundation

/// One line of a loaded G-code/NC program.
///
/// `id` is the 1-based line number — stable, unique within a file, and
/// exactly the value the machine's status report ("P:" field) refers to
/// when it tells you which line is currently executing.
struct GCodeLine: Identifiable, Hashable {
    let id: Int
    var text: String
}

/// Holds a loaded NC/G-code file: its lines, source URL, and load state.
///
/// Kept independent of any specific view so it can be reused — e.g. shared
/// between a file browser, a "currently executing line" highlighter fed by
/// live machine status, and (eventually) whatever sends an edited file back
/// to the machine.
@MainActor
final class NCFileDocument: ObservableObject {
    @Published private(set) var fileURL: URL?
    @Published private(set) var fileName: String = "No file loaded"
    @Published var lines: [GCodeLine] = []
    @Published var lastError: String?

    var isLoaded: Bool { fileURL != nil }

    func load(from url: URL) {
        lastError = nil

        // NC files typically live outside the app's sandbox container
        // (Downloads, an external drive, a CAM output folder) — this starts
        // a security-scoped access session so reading is actually permitted.
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let contents = try String(contentsOf: url, encoding: .utf8)

            var newLines: [GCodeLine] = []
            newLines.reserveCapacity(contents.utf8.count / 20) // rough average line length guess
            var lineNumber = 0
            contents.enumerateLines { text, _ in
                lineNumber += 1
                newLines.append(GCodeLine(id: lineNumber, text: text))
            }

            lines = newLines
            fileURL = url
            fileName = url.lastPathComponent
        } catch {
            lastError = "Couldn't read file: \(error.localizedDescription)"
        }
    }

    /// Updates a single line's text by array index — O(1), and touches
    /// nothing else in the array. Prefer this over mutating `lines`
    /// wholesale when only one row changed (e.g. after inline editing).
    func updateLine(at index: Int, text: String) {
        guard index >= 0, index < lines.count else { return }
        guard lines[index].text != text else { return } // avoid a no-op publish
        lines[index].text = text
    }

    func clear() {
        fileURL = nil
        fileName = "No file loaded"
        lines = []
        lastError = nil
    }
}
