//
//  DummyMachineState.swift
//  CNC Studio
//
//  Created by Cristian Baluta on 20.08.2026.
//


import SwiftUI
import SceneKit

// MARK: - Dummy Model

enum DummyMachineState {
    case ready
    case running
    case feedHold
    case alarm
    case offline

    var title: String {
        switch self {
        case .ready: "READY"
        case .running: "RUNNING"
        case .feedHold: "FEED HOLD"
        case .alarm: "ALARM"
        case .offline: "OFFLINE"
        }
    }

    var symbol: String {
        switch self {
        case .ready: "circle.fill"
        case .running: "play.circle.fill"
        case .feedHold: "pause.circle.fill"
        case .alarm: "exclamationmark.triangle.fill"
        case .offline: "circle"
        }
    }

    var color: Color {
        switch self {
        case .ready: .green
        case .running: .blue
        case .feedHold: .orange
        case .alarm: .red
        case .offline: .secondary
        }
    }
}

struct DummyMachine: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var state: DummyMachineState
    var program: String?
    var progress: Double
    var x: Double
    var y: Double
    var z: Double
    var feed: Double
    var spindle: Int
}

// MARK: - Main View

struct CNCMainView: View {

    @State private var machines: [DummyMachine] = [

        DummyMachine(
            name: "Haas VF-1",
            state: .ready,
            program: "BRACKET.NC",
            progress: 0.64,
            x: 125.420,
            y: 42.100,
            z: -12.500,
            feed: 850,
            spindle: 12_000
        ),

        DummyMachine(
            name: "Haas VF-2",
            state: .running,
            program: "HOUSING.NC",
            progress: 0.78,
            x: 82.340,
            y: 115.200,
            z: -4.250,
            feed: 1200,
            spindle: 10_500
        ),

        DummyMachine(
            name: "Mill 03",
            state: .alarm,
            program: "PLATE.NC",
            progress: 0.31,
            x: 220.000,
            y: 50.000,
            z: -25.000,
            feed: 0,
            spindle: 0
        ),

        DummyMachine(
            name: "Lathe 01",
            state: .offline,
            program: nil,
            progress: 0,
            x: 0,
            y: 0,
            z: 0,
            feed: 0,
            spindle: 0
        )
    ]

    @State private var selectedMachineID: UUID?

    private var selectedMachine: DummyMachine? {
        guard let id = selectedMachineID else {
            return machines.first
        }

        return machines.first {
            $0.id == id
        }
    }

    var body: some View {

        NavigationSplitView {

            MachineSidebar(
                machines: machines,
                selection: $selectedMachineID
            )

        } detail: {

            if let machine = selectedMachine {

                MachineDashboard(
                    machine: machine
                )

            } else {

                ContentUnavailableView(
                    "No Machine Selected",
                    systemImage: "cpu",
                    description: Text("Select a CNC machine from the sidebar.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            selectedMachineID = machines.first?.id
        }
    }
}


// MARK: - Sidebar




// MARK: - Machine Row




// MARK: - Dashboard

struct MachineDashboard: View {

    let machine: DummyMachine

    @State private var selectedLine = 5

    var body: some View {

        VStack(spacing: 0) {

            MachineHeader(machine: machine)

            Divider()

            HStack(spacing: 0) {

                ToolpathView()

                Divider()

                ProgramPanel(
                    selectedLine: $selectedLine
                )
                .frame(width: 330)

                Divider()

                PositionPanel(machine: machine)
                    .frame(width: 210)
            }

            Divider()

            ControlBar(machine: machine)
        }
        .background(.background)
    }
}


// MARK: - Machine Header

struct MachineHeader: View {

    let machine: DummyMachine

    var body: some View {

        HStack(spacing: 14) {

            Image(systemName: machine.state.symbol)
                .foregroundStyle(machine.state.color)
                .font(.title3)

            VStack(
                alignment: .leading,
                spacing: 2
            ) {

                HStack {

                    Text(machine.name)
                        .font(.title3.weight(.semibold))

                    Text(machine.state.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(machine.state.color)
                }

                if let program = machine.program {

                    Text(program)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if machine.state == .running {

                VStack(
                    alignment: .trailing,
                    spacing: 3
                ) {

                    Text("PROGRAM PROGRESS")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(Int(machine.progress * 100))%")
                        .font(.headline.monospacedDigit())
                }
            }

            Divider()
                .frame(height: 30)

            Text("G54")
                .font(.headline.monospaced())

            Text("\(machine.spindle.formatted()) RPM")
                .font(.headline.monospacedDigit())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}


// MARK: - Toolpath View

struct ToolpathView: View {

    var body: some View {

        ZStack {

            Color(nsColor: .windowBackgroundColor)

            VStack {

                HStack {

                    Label(
                        "Toolpath",
                        systemImage: "cube.transparent"
                    )
                    .font(.headline)

                    Spacer()

                    HStack(spacing: 12) {

                        LegendItem(
                            title: "Cut",
                            style: StrokeStyle(lineWidth: 4)
                        )

                        LegendItem(
                            title: "Rapid",
                            style: StrokeStyle(dash: [10, 10])
                        )
                    }
                }

                .padding()

                Spacer()

                DummyToolpath()

                Spacer()

                HStack {

                    Text("TOP")
                    Text("•")
                    Text("G54")
                    Text("•")
                    Text("MM")

                    Spacer()

                    Text("Scroll to zoom · Drag to rotate")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
            }
        }
    }
}


// MARK: - Dummy Toolpath

struct DummyToolpath: View {

    var body: some View {

        GeometryReader { geometry in

            let w = geometry.size.width
            let h = geometry.size.height

            Path { path in

                let points: [CGPoint] = [

                    CGPoint(x: w * 0.20, y: h * 0.75),
                    CGPoint(x: w * 0.20, y: h * 0.30),
                    CGPoint(x: w * 0.75, y: h * 0.30),
                    CGPoint(x: w * 0.75, y: h * 0.70),
                    CGPoint(x: w * 0.35, y: h * 0.70),
                    CGPoint(x: w * 0.35, y: h * 0.45),
                    CGPoint(x: w * 0.60, y: h * 0.45)
                ]

                path.move(to: points[0])

                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(
                .blue,
                style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round,
                    lineJoin: .round
                )
            )

            // Rapid move

            Path { path in

                let w = geometry.size.width
                let h = geometry.size.height

                path.move(
                    to: CGPoint(
                        x: w * 0.15,
                        y: h * 0.80
                    )
                )

                path.addLine(
                    to: CGPoint(
                        x: w * 0.20,
                        y: h * 0.75
                    )
                )
            }
            .stroke(
                .secondary,
                style: StrokeStyle(
                    lineWidth: 1,
                    dash: [5, 5]
                )
            )

            // Tool

            Circle()
                .fill(.orange)
                .frame(width: 14, height: 14)
                .position(
                    x: w * 0.60,
                    y: h * 0.45
                )
        }
    }
}


// MARK: - Legend

struct LegendItem: View {

    let title: String
    let style: StrokeStyle

    var body: some View {

        HStack(spacing: 5) {

            Rectangle()
                .fill(.secondary)
                .frame(width: 20, height: 2)
                .overlay {
                    Rectangle()
                        .stroke(
                            .secondary,
                            style: style
                        )
                }

            Text(title)
                .font(.caption)
        }
    }
}


// MARK: - Program Panel

struct ProgramPanel: View {

    @Binding var selectedLine: Int

    private let lines = [
        "G21",
        "G90",
        "G0 X0 Y0",
        "M3 S12000",
        "G1 X20 F850",
        "G1 Y20",
        "G2 X50 Y30 I10 J0",
        "G1 X50 Y50",
        "G1 X0 Y50",
        "G0 Z20",
        "M5"
    ]

    var body: some View {

        VStack(spacing: 0) {

            HStack {

                Label(
                    "Program",
                    systemImage: "doc.text"
                )
                .font(.headline)

                Spacer()

                Text("\(lines.count) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            ScrollViewReader { proxy in

                ScrollView {

                    LazyVStack(
                        alignment: .leading,
                        spacing: 0
                    ) {

                        ForEach(
                            Array(lines.enumerated()),
                            id: \.offset
                        ) { index, line in

                            ProgramLine(
                                number: index + 1,
                                text: line,
                                isSelected: selectedLine == index + 1
                            )
                            .id(index + 1)
                            .contentShape(Rectangle())
                            .onTapGesture {

                                selectedLine = index + 1

                                withAnimation {
                                    proxy.scrollTo(
                                        index + 1,
                                        anchor: .center
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


// MARK: - Program Line

struct ProgramLine: View {

    let number: Int
    let text: String
    let isSelected: Bool

    var body: some View {

        HStack(spacing: 0) {

            Text(
                "\(number)"
            )
            .frame(
                width: 48,
                alignment: .trailing
            )
            .foregroundStyle(.secondary)

            Text(text)
                .padding(.leading, 12)
                .foregroundStyle(
                    isSelected
                    ? .primary
                    : .secondary
                )

            Spacer()
        }
        .font(.system(
            size: 12,
            design: .monospaced
        ))
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            isSelected
            ? Color.accentColor.opacity(0.18)
            : Color.clear
        )
    }
}


// MARK: - Position Panel

struct PositionPanel: View {

    let machine: DummyMachine

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 0
        ) {

            Label(
                "Position",
                systemImage: "scope"
            )
            .font(.headline)
            .padding()

            Divider()

            VStack(
                alignment: .leading,
                spacing: 22
            ) {

                Coordinate(
                    axis: "X",
                    value: machine.x
                )

                Coordinate(
                    axis: "Y",
                    value: machine.y
                )

                Coordinate(
                    axis: "Z",
                    value: machine.z
                )

                Divider()

                Coordinate(
                    axis: "F",
                    value: machine.feed,
                    suffix: " mm/min"
                )

                Coordinate(
                    axis: "S",
                    value: Double(machine.spindle),
                    suffix: " RPM"
                )
            }
            .padding(18)

            Spacer()
        }
    }
}


// MARK: - Coordinate

struct Coordinate: View {

    let axis: String
    let value: Double
    var suffix: String = " mm"

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 3
        ) {

            Text(axis)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(
                alignment: .firstTextBaseline,
                spacing: 4
            ) {

                Text(
                    String(
                        format: "%.3f",
                        value
                    )
                )
                .font(
                    .system(
                        size: 21,
                        weight: .medium,
                        design: .monospaced
                    )
                )

                Text(suffix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}


// MARK: - Control Bar

struct ControlBar: View {

    let machine: DummyMachine

    var body: some View {

        HStack(spacing: 10) {

            Button {
                // Dummy
            } label: {
                Label(
                    "Jog",
                    systemImage: "arrow.up.and.down.and.arrow.left.and.right"
                )
            }
            .buttonStyle(.bordered)

            Button {
                // Dummy
            } label: {
                Label(
                    "Setup",
                    systemImage: "slider.horizontal.3"
                )
            }
            .buttonStyle(.bordered)

            Button {
                // Dummy
            } label: {
                Label(
                    "Files",
                    systemImage: "folder"
                )
            }
            .buttonStyle(.bordered)

            Spacer()

            Button {
                // Dummy
            } label: {
                Label(
                    "Feed Hold",
                    systemImage: "pause.fill"
                )
            }
            .buttonStyle(.bordered)

            Button {
                // Dummy
            } label: {
                Label(
                    "Stop",
                    systemImage: "stop.fill"
                )
            }
            .buttonStyle(.bordered)

            Button {
                // Dummy
            } label: {

                Label(
                    machine.state == .running
                    ? "Running"
                    : "Cycle Start",
                    systemImage:
                        machine.state == .running
                        ? "play.fill"
                        : "play.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                machine.state == .offline ||
                machine.state == .alarm
            )
        }
        .padding(12)
    }
}
