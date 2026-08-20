import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Standalone NC/G-code file viewer.
///
/// Prompts to load a file, then displays it line-by-line in a real
/// `NSTableView` (via `GCodeTableView` below) rather than SwiftUI's `List`.
/// `List` + `ForEach(Binding<[Element]>)` does an id-based linear scan per
/// row binding and re-diffs the whole array on any edit — fine at hundreds
/// of rows, rough at 100k+. `NSTableView` addresses rows by plain integer
/// index and reuses cell views directly, which is what stays smooth here.
///
/// To follow along with a running job, pass `highlightedLine` — e.g. bound
/// to the machine status's "P:" field (played_lines) once that's wired up —
/// and this view will highlight and auto-scroll to that line.
struct NCFileViewerView: View {
    @StateObject private var document = NCFileDocument()
    @State private var isImporterPresented = false

    var highlightedLine: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if document.lines.isEmpty {
                emptyState
            } else {
                GCodeTableView(document: document, highlightedLine: highlightedLine)
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
                }
            case .failure(let error):
                document.lastError = error.localizedDescription
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

                    Button {
                        document.clear()
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

// MARK: - NSTableView bridge

private extension NSUserInterfaceItemIdentifier {
    static let lineNumberColumn = NSUserInterfaceItemIdentifier("lineNumberColumn")
    static let lineTextColumn = NSUserInterfaceItemIdentifier("lineTextColumn")
}

/// Wraps a real `NSTableView` in an `NSScrollView`. Rows are addressed by
/// integer index (not by Identifiable id), and cell views are reused via
/// `makeView(withIdentifier:owner:)` — the same mechanism Xcode's own
/// console/log views use for very large row counts.
struct GCodeTableView: NSViewRepresentable {
    @ObservedObject var document: NCFileDocument
    var highlightedLine: Int?

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = NSTableView()
        tableView.style = .plain
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.gridStyleMask = []
        tableView.headerView = nil
        tableView.intercellSpacing = NSSize(width: 4, height: 0)
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        // Fixed row height (set below, no per-row delegate callback) keeps
        // NSTableView on its fast uniform-row-height layout path — critical
        // at 100k rows. Implementing tableView(_:heightOfRow:) would force
        // a delegate call per row on every layout pass instead.
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

        // Full reload only on an actual row-count change (new file loaded).
        // A single edited line does NOT hit this path — see
        // Coordinator.controlTextDidEndEditing, which updates the model
        // directly without forcing a reload here at all.
        if coordinator.lastRowCount != document.lines.count {
            coordinator.lastRowCount = document.lines.count
            coordinator.tableView?.reloadData()
        }

        // Move the highlight by reloading only the two affected rows —
        // not the whole table.
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
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document)
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
        var document: NCFileDocument
        weak var tableView: NSTableView?
        var lastRowCount = -1
        var lastHighlightedLine: Int?

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

        // Commits an edited line back into the document by index — O(1),
        // no array-wide diffing and no SwiftUI re-render of other rows.
        func controlTextDidEndEditing(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField, textField.tag >= 0 else { return }
            document.updateLine(at: textField.tag, text: textField.stringValue)
        }
    }
}

#Preview {
    NCFileViewerView()
        .frame(width: 500, height: 400)
}
