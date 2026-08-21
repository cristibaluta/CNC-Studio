import SwiftUI

#if os(macOS)
import AppKit
#endif

// MARK: - Machine Detail View

struct MachineDetailView: View {

    let machine: MakeraMachine

    @StateObject private var connection = MachineConnection()

    @State private var mdiInput = ""
    @State private var commandHistory: [String] = []
    @State private var historyIndex: Int?

    @State private var selectedFeedOverride: Int = 100
    @State private var spindleRPM = "12000"

    @State private var isShowingCommandPalette = false
    @State private var isLightOn = false
    @State private var terminalAutoScroll = true

    @FocusState private var commandFieldFocused: Bool

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
//            header
//
//            Divider()

            toolpathView

            gCodeView

            VStack {
                JogView() { x, y, z, a in
                    sendCommand( CNC.rapidMove.with(x: x, y: y, z: z) )
                }
                .disabled(!connection.isConnected)

//                leftControlPanel
//

                terminalPanel
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                commandBar
            }
            .frame(width: 280)
        }
        .padding(14)
        .frame(
            minWidth: 900,
            maxWidth: .infinity,
            minHeight: 650,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            connection.connect(to: machine)
            commandFieldFocused = true
        }
        .onDisappear {
            connection.disconnect()
        }
        .onChange(of: machine) {
            connection.disconnect()
            connection.connect(to: machine)
        }
        .overlay {
            if isShowingCommandPalette {
                commandPalette
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(machine.name)
                    .font(.title2)
                    .bold()

                Text("\(machine.ip):\(machine.port)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let status = connection.status {
                statusSummary(status)
            }

            connectionIndicator

            Button {
                toggleLight()
            } label: {
                Image(
                    systemName: isLightOn
                        ? "lightbulb.fill"
                        : "lightbulb"
                )
                .foregroundStyle(
                    isLightOn
                        ? .yellow
                        : .secondary
                )
            }
            .buttonStyle(.borderless)
            .help(
                isLightOn
                    ? "Turn light off"
                    : "Turn light on"
            )
            .disabled(!connection.isConnected)

            Button {
                connection.connect(to: machine)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Reconnect")
            .buttonStyle(.borderless)
        }
    }

    private var connectionIndicator: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(
                    connection.isConnected
                        ? Color.green
                        : Color.red
                )
                .frame(width: 9, height: 9)

            VStack(alignment: .trailing, spacing: 2) {
                Text(
                    connection.isConnected
                        ? "Connected"
                        : "Disconnected"
                )
                .font(.caption)

                if let proto = connection.wireProtocol {
                    Text(proto.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func statusSummary(
        _ status: MakeraMachineStatus
    ) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(status.state)
                .font(.caption)
                .bold()

            Text(
                String(
                    format: "X %.3f  Y %.3f  Z %.3f",
                    status.workPosition.x,
                    status.workPosition.y,
                    status.workPosition.z
                )
            )
            .font(
                .system(
                    .caption2,
                    design: .monospaced
                )
            )
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - G code view

    private var toolpathView: some View {
        NCFileViewerView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var gCodeView: some View {
        Text("G-CODE")
    }

    // MARK: - Left Control Panel

    private var leftControlPanel: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                positionPanel

                Divider()

                spindlePanel

                Divider()

                coordinatePanel

                Divider()

                probePanel

                Divider()

                machinePanel
            }
        }
        .scrollIndicators(.automatic)
    }

    // MARK: - Position

    private var positionPanel: some View {
        GroupBox("Position") {
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                if let status = connection.status {
                    positionRow(
                        title: "Machine",
                        x: status.machinePosition.x,
                        y: status.machinePosition.y,
                        z: status.machinePosition.z
                    )

                    positionRow(
                        title: "Work",
                        x: status.workPosition.x,
                        y: status.workPosition.y,
                        z: status.workPosition.z
                    )

                    Text("State: \(status.state)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Waiting for status…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func positionRow(
        title: String,
        x: Double,
        y: Double,
        z: Double
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 2
        ) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(
                String(
                    format: "X %8.3f  Y %8.3f  Z %8.3f",
                    x,
                    y,
                    z
                )
            )
            .font(
                .system(
                    .caption,
                    design: .monospaced
                )
            )
        }
    }

    

    // MARK: - Spindle

    private var spindlePanel: some View {
        GroupBox("Spindle") {
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                HStack {
                    Text("RPM")
                        .font(.caption)

                    TextField(
                        "RPM",
                        text: $spindleRPM
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                }

                HStack(spacing: 6) {
                    Button {
                        let rpm =
                            Int(spindleRPM) ?? 12000

                        sendCommand(
                            CNC.spindleOn.with(
                                rpm: rpm
                            )
                        )
                    } label: {
                        Label(
                            "Start",
                            systemImage: "play.fill"
                        )
                    }
                    .disabled(!connection.isConnected)

                    Button {
                        sendCommand(
                            CNC.spindleOff
                        )
                    } label: {
                        Label(
                            "Stop",
                            systemImage: "stop.fill"
                        )
                    }
                    .disabled(!connection.isConnected)
                }
                // Note: the firmware only implements M3 (on) / M5 (off) —
                // there's no M4/CCW support, so no separate CW/CCW toggle exists.
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Coordinates

    private var coordinatePanel: some View {
        GroupBox("Work Coordinates") {
            VStack(spacing: 6) {
                HStack {
                    Text("Zero")
                        .font(.caption)

                    Spacer()

                    Button("X") {
                        sendRawCommand(
                            zeroCommand(x: true)
                        )
                    }

                    Button("Y") {
                        sendRawCommand(
                            zeroCommand(y: true)
                        )
                    }

                    Button("Z") {
                        sendRawCommand(
                            zeroCommand(z: true)
                        )
                    }
                }

                Button {
                    sendRawCommand(
                        zeroCommand(x: true, y: true, z: true)
                    )
                } label: {
                    Label(
                        "Set XYZ Zero",
                        systemImage: "scope"
                    )
                    .frame(maxWidth: .infinity)
                }
                .disabled(!connection.isConnected)

                Button {
                    connection.requestStatus()
                } label: {
                    Label(
                        "Get Coordinates",
                        systemImage: "location"
                    )
                    .frame(maxWidth: .infinity)
                }
                .disabled(!connection.isConnected)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Probe

    private var probePanel: some View {
        GroupBox("Probe") {
            VStack(spacing: 6) {
                Button {
                    sendCommand(
                        CNC.probe.with(
                            z: -10,
                            feed: 50
                        )
                    )
                } label: {
                    Label(
                        "Probe Z",
                        systemImage: "arrow.down.to.line"
                    )
                    .frame(maxWidth: .infinity)
                }
                .disabled(!connection.isConnected)

                HStack {
                    Button("Probe X") {
                        sendCommand(
                            CNC.probe.with(
                                x: 10,
                                feed: 50
                            )
                        )
                    }

                    Button("Probe Y") {
                        sendCommand(
                            CNC.probe.with(
                                y: 10,
                                feed: 50
                            )
                        )
                    }
                }
                .disabled(!connection.isConnected)

                Button {
                    sendCommand(
                        CNC.probe.with(
                            z: -10,
                            feed: 50
                        )
                    )
                } label: {
                    Label(
                        "Auto Z",
                        systemImage: "wand.and.stars"
                    )
                    .frame(maxWidth: .infinity)
                }
                .disabled(!connection.isConnected)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Machine

    private var machinePanel: some View {
        GroupBox("Machine") {
            VStack(spacing: 6) {
                Button {
                    sendRawCommand(
                        homeCommand
                    )
                } label: {
                    Label(
                        "Home",
                        systemImage: "house"
                    )
                    .frame(maxWidth: .infinity)
                }
                .disabled(!connection.isConnected)

                Button {
                    sendRawCommand(
                        unlockCommand
                    )
                } label: {
                    Label(
                        "Unlock",
                        systemImage: "lock.open"
                    )
                    .frame(maxWidth: .infinity)
                }
                .disabled(!connection.isConnected)

                Button {
                    connection.requestStatus()
                } label: {
                    Label(
                        "Machine Status",
                        systemImage: "info.circle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .disabled(!connection.isConnected)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Terminal

    private var terminalPanel: some View {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            HStack {
                Text("Raw responses")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Toggle(
                    "Auto-scroll",
                    isOn: $terminalAutoScroll
                )
                .toggleStyle(.checkbox)
                .font(.caption)

                Button {
                    clearTerminal()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Clear terminal")
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: 2
                    ) {
                        ForEach(
                            Array(
                                connection.rawLog.enumerated()
                            ),
                            id: \.offset
                        ) { index, line in
                            terminalLine(line)
                                .id(index)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("terminal-bottom")
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding(10)
                }
                .onChange(
                    of: connection.rawLog.count
                ) {
                    guard terminalAutoScroll else {
                        return
                    }

                    withAnimation(
                        .easeOut(duration: 0.12)
                    ) {
                        proxy.scrollTo(
                            "terminal-bottom",
                            anchor: .bottom
                        )
                    }
                }
                .onAppear {
                    proxy.scrollTo(
                        "terminal-bottom",
                        anchor: .bottom
                    )
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
            .background(
                Color.black.opacity(0.08)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 7
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 7
                )
                .stroke(
                    Color.primary.opacity(0.08)
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }

    private func terminalLine(
        _ line: String
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: 6
        ) {
            if line.hasPrefix("> ") {
                Text(">")
                    .foregroundStyle(.blue)

                Text(
                    String(line.dropFirst(2))
                )
                .foregroundStyle(.primary)
            } else {
                Text("<")
                    .foregroundStyle(.green)

                Text(line)
                    .foregroundStyle(.primary)
            }
        }
        .font(
            .system(
                .caption,
                design: .monospaced
            )
        )
        .textSelection(.enabled)
    }

    // MARK: - Command Bar

    private var commandBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)

            TextField(
                "Send a command…",
                text: $mdiInput
            )
            .textFieldStyle(.plain)
            .font(
                .system(
                    .body,
                    design: .monospaced
                )
            )
            .focused(
                $commandFieldFocused
            )
            .onSubmit {
                sendMDI()
            }
            .onKeyPress(.upArrow) {
                historyPrevious()
                return .handled
            }
            .onKeyPress(.downArrow) {
                historyNext()
                return .handled
            }
            .onKeyPress(.escape) {
                mdiInput = ""
                historyIndex = nil
                return .handled
            }

            if !mdiInput.isEmpty {
                Button {
                    mdiInput = ""
                    historyIndex = nil
                } label: {
                    Image(
                        systemName:
                            "xmark.circle.fill"
                    )
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }

            Button {
                sendMDI()
            } label: {
                Text("Send")
                    .frame(minWidth: 50)
            }
            .keyboardShortcut(
                .return,
                modifiers: []
            )
            .disabled(
                !connection.isConnected ||
                mdiInput
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty
            )

            Button {
                isShowingCommandPalette = true
            } label: {
                Image(systemName: "command")
            }
            .help("Command palette")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Color.primary.opacity(0.05)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 7
            )
        )
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 8) {
            feedOverride

            Spacer()

            if let error = connection.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                sendRawCommand("!")
            } label: {
                Label(
                    "Pause",
                    systemImage: "pause.fill"
                )
            }
            .disabled(!connection.isConnected)

            Button {
                sendRawCommand("~")
            } label: {
                Label(
                    "Resume",
                    systemImage: "play.fill"
                )
            }
            .disabled(!connection.isConnected)

            Button(role: .destructive) {
                sendCommand(
                    CNC.spindleOff
                )

                sendRawCommand("!")
            } label: {
                Label(
                    "Stop",
                    systemImage: "stop.fill"
                )
            }
            .disabled(!connection.isConnected)

            Button(role: .destructive) {
                sendRawCommand("\u{18}")
            } label: {
                Label(
                    "Reset",
                    systemImage: "xmark.octagon.fill"
                )
            }
            .disabled(!connection.isConnected)
        }
    }

    private var feedOverride: some View {
        HStack(spacing: 5) {
            Text("Feed")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(
                "Feed",
                selection: $selectedFeedOverride
            ) {
                Text("25%").tag(25)
                Text("50%").tag(50)
                Text("75%").tag(75)
                Text("100%").tag(100)
                Text("125%").tag(125)
                Text("150%").tag(150)
            }
            .labelsHidden()
            .frame(width: 80)
            .onChange(of: selectedFeedOverride) {
                sendCommand(
                    CNC.feedOverride.with(
                        percent: selectedFeedOverride
                    )
                )
            }
        }
    }

    // MARK: - Command Palette

    private var commandPalette: some View {
        ZStack {
            Color.black
                .opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    isShowingCommandPalette = false
                }

            VStack(
                alignment: .leading,
                spacing: 0
            ) {
                HStack {
                    Image(systemName: "command")

                    Text("Command Palette")
                        .font(.headline)

                    Spacer()

                    Button {
                        isShowingCommandPalette = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(12)

                Divider()

                ScrollView {
                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {
                        paletteSection(
                            title: "Favorites",
                            commands: favoriteCommands
                        )

                        paletteSection(
                            title: "Machine",
                            commands: [
                                PaletteCommand(
                                    title: "Home",
                                    rawCommand: homeCommand
                                ),
                                PaletteCommand(
                                    title: "Unlock",
                                    rawCommand: unlockCommand
                                ),
                                PaletteCommand(
                                    title: "Get status",
                                    rawCommand: statusCommand
                                ),
                                PaletteCommand(
                                    title: "Turn light on",
                                    command: CNC.lightOn
                                ),
                                PaletteCommand(
                                    title: "Turn light off",
                                    command: CNC.lightOff
                                )
                            ]
                        )

                        paletteSection(
                            title: "Spindle",
                            commands: [
                                PaletteCommand(
                                    title: "Spindle stop",
                                    command: CNC.spindleOff
                                ),
                                PaletteCommand(
                                    title: "Spindle on",
                                    command:
                                        CNC.spindleOn.with(
                                            rpm:
                                                Int(spindleRPM)
                                                ?? 12000
                                        )
                                )
                                // Note: firmware only implements M3/M5 — no
                                // M4/CCW support exists to offer here.
                            ]
                        )

                        paletteSection(
                            title: "Coordinates",
                            commands: [
                                PaletteCommand(
                                    title: "Set X zero",
                                    rawCommand: zeroCommand(x: true)
                                ),
                                PaletteCommand(
                                    title: "Set Y zero",
                                    rawCommand: zeroCommand(y: true)
                                ),
                                PaletteCommand(
                                    title: "Set Z zero",
                                    rawCommand: zeroCommand(z: true)
                                ),
                                PaletteCommand(
                                    title: "Set XYZ zero",
                                    rawCommand: zeroCommand(x: true, y: true, z: true)
                                )
                            ]
                        )

                        paletteSection(
                            title: "Recent",
                            commands:
                                commandHistory
                                    .reversed()
                                    .prefix(10)
                                    .map {
                                        PaletteCommand(
                                            title: $0,
                                            rawCommand: $0
                                        )
                                    }
                        )
                    }
                    .padding(10)
                }
            }
            .frame(
                width: 500,
                height: 500
            )
            .background(
                Color(nsColor: .windowBackgroundColor)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 10
                )
            )
            .shadow(radius: 30)
        }
    }

    private func paletteSection<S: Sequence>(
        title: String,
        commands: S
    ) -> some View
    where S.Element == PaletteCommand {
        let commands = Array(commands)

        if commands.isEmpty {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.top, 6)

                ForEach(commands) { item in
                    Button {
                        sendPaletteCommand(item)
                        isShowingCommandPalette = false
                    } label: {
                        HStack {
                            Text(item.title)

                            Spacer()

                            Text(item.rawCommand)
                                .font(
                                    .system(
                                        .caption,
                                        design: .monospaced
                                    )
                                )
                                .foregroundStyle(.secondary)
                        }
                        .padding(7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        )
    }

    private var favoriteCommands: [PaletteCommand] {
        [
            PaletteCommand(
                title: "Get status",
                rawCommand: statusCommand
            ),
            PaletteCommand(
                title: "Spindle stop",
                command: CNC.spindleOff
            ),
            PaletteCommand(
                title: "Home",
                rawCommand: homeCommand
            ),
            PaletteCommand(
                title: "Set XYZ zero",
                rawCommand: zeroCommand(x: true, y: true, z: true)
            ),
            PaletteCommand(
                title: "Light on",
                command: CNC.lightOn
            ),
            PaletteCommand(
                title: "Light off",
                command: CNC.lightOff
            )
        ]
    }

    // MARK: - Raw commands not modeled by CNCCommand

    /// Grbl/Smoothieware-style homing command. Confirmed against
    /// Carvera_Controller/carveracontroller/Controller.py -> home().
    private let homeCommand = "$H"

    /// Grbl/Smoothieware-style alarm-clear/unlock command. Confirmed against
    /// Controller.py -> unlock().
    private let unlockCommand = "$X"

    /// Realtime status query byte — handled specially in sendRawCommand(),
    /// since it needs the protocol-aware realtime path, not a queued line.
    private let statusCommand = "?"

    /// Builds a "set current axis position as zero" command. Matches the
    /// reference app's wcs_set(): G10 L20 P0 sets the active work coordinate
    /// system offset so the machine's *current* physical position reads as
    /// the given value (0) on the specified axes. (CNCCommand doesn't model
    /// this yet — G92 would only be a temporary offset, not equivalent.)
    private func zeroCommand(x: Bool = false, y: Bool = false, z: Bool = false) -> String {
        var command = "G10L20P0"
        if x { command += "X0" }
        if y { command += "Y0" }
        if z { command += "Z0" }
        return command
    }

    // MARK: - Sending Commands

    private func toggleLight() {
        let command =
            isLightOn
            ? CNC.lightOff
            : CNC.lightOn

        sendCommand(command)
        isLightOn.toggle()
    }

    private func sendMDI() {
        let command = mdiInput
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !command.isEmpty else {
            return
        }

        sendRawCommand(command)

        mdiInput = ""
        historyIndex = nil
    }

    private func sendCommand(
        _ command: CNCCommand
    ) {
        sendRawCommand(command.command)
    }

    private func sendPaletteCommand(
        _ paletteCommand: PaletteCommand
    ) {
        if let command = paletteCommand.command {
            sendCommand(command)
        } else {
            sendRawCommand(
                paletteCommand.rawCommand
            )
        }
    }

    private func sendRawCommand(
        _ command: String
    ) {
        let command = command
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !command.isEmpty else {
            return
        }

        guard connection.isConnected else {
            return
        }

        // "?" is a realtime status-query byte, not a queued line/frame —
        // route it through the protocol-aware realtime path so it works
        // correctly under both the plain-text and framed wire protocols.
        if command == statusCommand {
            connection.requestStatus()
            return
        }

        addToHistory(command)
        connection.send(command)
    }

    // MARK: - Command History

    private func addToHistory(
        _ command: String
    ) {
        if commandHistory.last == command {
            return
        }

        commandHistory.removeAll {
            $0 == command
        }

        commandHistory.append(command)

        if commandHistory.count > 10 {
            commandHistory.removeFirst(
                commandHistory.count - 10
            )
        }
    }

    private func historyPrevious() {
        guard !commandHistory.isEmpty else {
            return
        }

        if let index = historyIndex {
            historyIndex = max(
                0,
                index - 1
            )
        } else {
            historyIndex =
                commandHistory.count - 1
        }

        if let index = historyIndex {
            mdiInput = commandHistory[index]
        }
    }

    private func historyNext() {
        guard let index = historyIndex else {
            return
        }

        if index + 1 < commandHistory.count {
            historyIndex = index + 1
            mdiInput = commandHistory[
                index + 1
            ]
        } else {
            historyIndex = nil
            mdiInput = ""
        }
    }

    // MARK: - Terminal

    private func clearTerminal() {
        connection.clearLogs()
    }
}
