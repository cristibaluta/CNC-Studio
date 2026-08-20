import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Standalone NC/G-code file viewer with a lightweight toolpath navigator.
///
/// The G-code itself remains in a real NSTableView for large-file performance.
/// The left sidebar is SwiftUI and contains the toolpaths detected from the
/// currently loaded lines. Selecting a toolpath asks the NSTableView to jump
/// to its first G-code line.
struct NCFileViewerView: View {
    @StateObject private var document = NCFileDocument()
    @State private var isImporterPresented = false
    @State private var selectedToolpathID: UUID?
    @State private var requestedLine: Int?
    @State private var analyzedLineCount = -1

    var highlightedLine: Int? = nil

    private var toolpaths: [GCodeToolpath] {
        GCodeToolpathAnalyzer.analyze(document.lines.map { (id: $0.id, text: $0.text) })
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if document.lines.isEmpty {
                emptyState
            } else {
                VStack {
                    MetalView()
                        .frame(height: 600)

                    HStack(spacing: 0) {
                        toolpathSidebar
                            .frame(minWidth: 230, idealWidth: 270, maxWidth: 340)

                        Divider()

                        GCodeTableView(
                            document: document,
                            highlightedLine: highlightedLine,
                            requestedLine: requestedLine
                        )
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    document.load(from: url)
                    selectedToolpathID = nil
                    requestedLine = nil
                    analyzedLineCount = -1
                }
            case .failure(let error):
                document.lastError = error.localizedDescription
            }
        }
        .onChange(of: document.lines.count) { _, newCount in
            if analyzedLineCount != newCount {
                analyzedLineCount = newCount
                selectedToolpathID = nil
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        VStack(spacing: 4) {
            HStack {
                Button {
                    isImporterPresented = true
                } label: {
                    Label("Load NC File…", systemImage: "folder")
                }

                Spacer()

                if document.isLoaded {
                    Text(document.fileName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text("\(document.lines.count) lines")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text("\(toolpaths.count) toolpaths")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Button {
                        document.clear()
                        selectedToolpathID = nil
                        requestedLine = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Close file")
                }
            }

            if let error = document.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(8)
    }

    // MARK: - Toolpaths

    private var toolpathSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Toolpaths")
                    .font(.headline)

                Spacer()

                Text("\(toolpaths.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if toolpaths.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No cutting toolpaths detected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(selection: $selectedToolpathID) {
                    ForEach(toolpaths) { toolpath in
                        ToolpathRow(toolpath: toolpath)
                            .tag(toolpath.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedToolpathID = toolpath.id
                                requestedLine = toolpath.startLine
                            }
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: selectedToolpathID) { _, newID in
                    guard let newID,
                          let toolpath = toolpaths.first(where: { $0.id == newID }) else { return }
                    requestedLine = toolpath.startLine
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No NC file loaded")
                .font(.headline)
            Text("Load a .nc, .ngc, .gcode, .cnc, or .tap file to view it here.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                isImporterPresented = true
            } label: {
                Label("Load NC File…", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - File types

    private var allowedContentTypes: [UTType] {
        var types: [UTType] = [.plainText]
        for ext in ["nc", "ngc", "gcode", "cnc", "tap"] {
            if let type = UTType(filenameExtension: ext) {
                types.append(type)
            }
        }
        return types
    }
}

// MARK: - Toolpath model / analyzer

struct GCodeToolpath: Identifiable, Hashable {
    let id = UUID()
    let toolNumber: Int?
    let operation: String
    let startLine: Int
    let endLine: Int
    let motionCount: Int

    var lineRangeText: String {
        startLine == endLine ? "line \(startLine)" : "lines \(startLine)–\(endLine)"
    }
}

struct GCodeToolpathAnalyzer {
    private static let codeRegex = try! NSRegularExpression(pattern: #"(?i)(?:^|\s)([GMT])\s*([0-9]+(?:\.[0-9]+)?)"#)
    private static let toolRegex = try! NSRegularExpression(pattern: #"(?i)(?:^|\s)T\s*([0-9]+)"#)

    static func analyze(_ lines: [(id: Int, text: String)]) -> [GCodeToolpath] {
        var result: [GCodeToolpath] = []
        var currentTool: Int?
        var currentOperation = "Motion"
        var currentStart: Int?
        var currentEnd: Int?
        var motionCount = 0
        var currentKind: OperationKind?

        func finishCurrent() {
            guard let start = currentStart, let end = currentEnd, motionCount > 0 else {
                currentStart = nil
                currentEnd = nil
                motionCount = 0
                currentKind = nil
                return
            }

            result.append(
                GCodeToolpath(
                    toolNumber: currentTool,
                    operation: currentOperation,
                    startLine: start,
                    endLine: end,
                    motionCount: motionCount
                )
            )

            currentStart = nil
            currentEnd = nil
            motionCount = 0
            currentKind = nil
        }

        for line in lines {
            let text = stripComments(line.text)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            let codes = extractCodes(from: text)

            // Tool changes define a hard boundary between machining tools.
            if let tool = extractToolNumber(from: text), containsM6(codes) {
                finishCurrent()
                currentTool = tool
                currentOperation = "Tool \(tool)"
                continue
            }

            // Explicit drilling cycles are treated as their own operation.
            if let cycle = drillingCycle(in: codes) {
                if currentKind != .drilling {
                    finishCurrent()
                    currentOperation = "Drilling (G\(cycle))"
                    currentKind = .drilling
                }
                if currentStart == nil { currentStart = line.id }
                currentEnd = line.id
                motionCount += 1
                continue
            }

            // Cancelled canned cycle: close the drilling group.
            if containsCode(0, in: codes, letter: "G"), currentKind == .drilling {
                finishCurrent()
            }

            if let motion = motionCode(in: codes) {
                let kind: OperationKind = motion == 0 ? .rapid : .cutting

                // Split when the semantic motion type changes, while keeping
                // consecutive cutting moves together as one toolpath.
                if currentKind != kind {
                    finishCurrent()
                    currentKind = kind
                    currentOperation = kind == .rapid ? "Rapid" : "Cutting"
                }

                // Rapid moves are useful for context but are not called a
                // machining toolpath unless they contain an actual move.
                if currentStart == nil { currentStart = line.id }
                currentEnd = line.id
                motionCount += 1
            }
        }

        finishCurrent()

        // Rapid-only sections are generally setup/repositioning rather than
        // toolpaths. Keep them only when there is no cutting/drilling result.
        let machining = result.filter { $0.operation != "Rapid" }
        return machining.isEmpty ? result : machining
    }

    private enum OperationKind: Equatable {
        case rapid
        case cutting
        case drilling
    }

    private static func stripComments(_ text: String) -> String {
        var output = text

        if let semicolon = output.firstIndex(of: ";") {
            output = String(output[..<semicolon])
        }

        while let start = output.firstIndex(of: "(") {
            guard let end = output[start...].firstIndex(of: ")") else {
                output = String(output[..<start])
                break
            }
            output.removeSubrange(start...end)
        }

        return output
    }

    private static func extractCodes(from text: String) -> [(letter: String, value: Int)] {
        let range = NSRange(text.startIndex..., in: text)
        return codeRegex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges >= 3,
                  let letterRange = Range(match.range(at: 1), in: text),
                  let valueRange = Range(match.range(at: 2), in: text),
                  let value = Double(text[valueRange]) else { return nil }
            return (String(text[letterRange]).uppercased(), Int(value))
        }
    }

    private static func extractToolNumber(from text: String) -> Int? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = toolRegex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text) else { return nil }
        return Int(text[valueRange])
    }

    private static func containsM6(_ codes: [(letter: String, value: Int)]) -> Bool {
        codes.contains { $0.letter == "M" && $0.value == 6 }
    }

    private static func motionCode(in codes: [(letter: String, value: Int)]) -> Int? {
        codes.last(where: { $0.letter == "G" && [0, 1, 2, 3].contains($0.value) })?.value
    }

    private static func drillingCycle(in codes: [(letter: String, value: Int)]) -> Int? {
        codes.last(where: { $0.letter == "G" && (81...89).contains($0.value) })?.value
    }

    private static func containsCode(_ value: Int, in codes: [(letter: String, value: Int)], letter: String) -> Bool {
        codes.contains { $0.letter == letter && $0.value == value }
    }
}

private struct ToolpathRow: View {
    let toolpath: GCodeToolpath

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .frame(width: 18)
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(toolpath.operation)
                        .font(.subheadline)
                        .lineLimit(1)

                    if let tool = toolpath.toolNumber {
                        Text("T\(tool)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Text("\(toolpath.lineRangeText) · \(toolpath.motionCount) moves")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .help("Jump to \(toolpath.lineRangeText)")
    }

    private var iconName: String {
        if toolpath.operation.hasPrefix("Drilling") { return "arrow.down.to.line" }
        if toolpath.operation == "Rapid" { return "arrow.triangle.turn.up.right.diamond" }
        return "scribble.variable"
    }

    private var iconColor: Color {
        if toolpath.operation.hasPrefix("Drilling") { return .orange }
        if toolpath.operation == "Rapid" { return .secondary }
        return .accentColor
    }
}

// MARK: - NSTableView bridge

private extension NSUserInterfaceItemIdentifier {
    static let lineNumberColumn = NSUserInterfaceItemIdentifier("lineNumberColumn")
    static let lineTextColumn = NSUserInterfaceItemIdentifier("lineTextColumn")
}

/// Wraps a real NSTableView in an NSScrollView. Rows are addressed by integer
/// index and cell views are reused, keeping the G-code viewer suitable for
/// very large files.
struct GCodeTableView: NSViewRepresentable {
    @ObservedObject var document: NCFileDocument
    var highlightedLine: Int?
    var requestedLine: Int?

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = NSTableView()
        tableView.style = .plain
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.gridStyleMask = []
        tableView.headerView = nil
        tableView.intercellSpacing = NSSize(width: 4, height: 0)
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.rowHeight = 20
        tableView.usesAutomaticRowHeights = false

        let lineNumberColumn = NSTableColumn(identifier: .lineNumberColumn)
        lineNumberColumn.width = 56
        lineNumberColumn.minWidth = 40
        lineNumberColumn.maxWidth = 90
        lineNumberColumn.resizingMask = []
        tableView.addTableColumn(lineNumberColumn)

        let textColumn = NSTableColumn(identifier: .lineTextColumn)
        textColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(textColumn)
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        context.coordinator.tableView = tableView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.document = document

        if coordinator.lastRowCount != document.lines.count {
            coordinator.lastRowCount = document.lines.count
            coordinator.tableView?.reloadData()
        }

        if coordinator.lastHighlightedLine != highlightedLine {
            let previous = coordinator.lastHighlightedLine
            coordinator.lastHighlightedLine = highlightedLine

            var rowsToReload = IndexSet()
            if let previous, previous >= 1, previous <= document.lines.count {
                rowsToReload.insert(previous - 1)
            }
            if let current = highlightedLine, current >= 1, current <= document.lines.count {
                rowsToReload.insert(current - 1)
                coordinator.tableView?.scrollRowToVisible(current - 1)
            }
            if !rowsToReload.isEmpty, let tableView = coordinator.tableView {
                tableView.reloadData(
                    forRowIndexes: rowsToReload,
                    columnIndexes: IndexSet(integersIn: 0..<tableView.tableColumns.count)
                )
            }
        }

        // A toolpath selection requests a one-time jump to the toolpath's
        // first G-code line. This is deliberately separate from
        // highlightedLine, which may be driven by a running CNC job.
        if coordinator.lastRequestedLine != requestedLine {
            coordinator.lastRequestedLine = requestedLine
            if let line = requestedLine, line >= 1, line <= document.lines.count {
                coordinator.tableView?.scrollRowToVisible(line - 1)
                coordinator.selectRow(line - 1)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document)
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
        var document: NCFileDocument
        weak var tableView: NSTableView?
        var lastRowCount = -1
        var lastHighlightedLine: Int?
        var lastRequestedLine: Int?

        init(document: NCFileDocument) {
            self.document = document
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            document.lines.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row >= 0, row < document.lines.count, let columnID = tableColumn?.identifier else {
                return nil
            }

            let line = document.lines[row]
            let cellID = NSUserInterfaceItemIdentifier("cell-\(columnID.rawValue)")

            let textField: NSTextField
            if let reused = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTextField {
                textField = reused
            } else {
                textField = NSTextField(string: "")
                textField.identifier = cellID
                textField.isBordered = false
                textField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                textField.lineBreakMode = .byTruncatingTail
                textField.focusRingType = .none
            }

            let isHighlighted = (line.id == lastHighlightedLine)

            if columnID == .lineNumberColumn {
                textField.stringValue = "\(line.id)"
                textField.alignment = .right
                textField.textColor = .secondaryLabelColor
                textField.isEditable = false
                textField.isSelectable = false
                textField.delegate = nil
                textField.tag = -1
            } else {
                textField.stringValue = line.text
                textField.alignment = .left
                textField.textColor = .labelColor
                textField.isEditable = true
                textField.isSelectable = true
                textField.delegate = self
                textField.tag = row
            }

            textField.drawsBackground = isHighlighted
            textField.backgroundColor = isHighlighted
                ? NSColor.controlAccentColor.withAlphaComponent(0.18)
                : .clear

            return textField
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField, textField.tag >= 0 else { return }
            document.updateLine(at: textField.tag, text: textField.stringValue)
        }

        func selectRow(_ row: Int) {
            guard let tableView, row >= 0, row < tableView.numberOfRows else { return }
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
    }
}

#Preview {
    NCFileViewerView()
        .frame(width: 800, height: 500)
}
