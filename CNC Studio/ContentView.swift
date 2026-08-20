import SwiftUI

struct ContentView: View {
    @StateObject private var discovery = MachineDiscovery()
    @State private var selectedMachine: MakeraMachine?

    var body: some View {
        NavigationSplitView {
            List(discovery.machines, selection: $selectedMachine) { machine in
                HStack {
                    Circle()
                        .fill(machine.busy ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(machine.name)
                            .font(.headline)
                        Text("\(machine.ip):\(machine.port)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(machine.busy ? "Busy" : "Idle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .tag(machine)
            }
            .navigationTitle("Makera Machines")
            .toolbar {
                ToolbarItem {
                    Button {
                        if discovery.isScanning {
                            discovery.stopScanning()
                        } else {
                            discovery.startScanning()
                        }
                    } label: {
                        Label(
                            discovery.isScanning ? "Stop" : "Scan",
                            systemImage: discovery.isScanning ? "stop.circle" : "arrow.clockwise"
                        )
                    }
                }
            }
            .overlay {
                if discovery.machines.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "wifi")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(discovery.isScanning ? "Scanning for machines…" : "No machines found")
                            .font(.headline)
                        Text(discovery.lastError ?? "Make sure your Mac and Makera are on the same network.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
            }
            .onAppear { discovery.startScanning() }
            .onDisappear { discovery.stopScanning() }
        } content: {
            NCFileViewerView()
        } detail: {
            if let selectedMachine {
                MachineDetailView(machine: selectedMachine)
            } else {
                VStack {
                    Text("Select a machine")
                        .foregroundStyle(.secondary)
                    Button("Try with a mock machine") {
                        selectedMachine = MakeraMachine(name: "MockMachine", ip: "00.00.00.00", port: 0, busy: false)
                    }
                }
            }
        }
        .onChange(of: selectedMachine) { _, newValue in
            // Once we're actually talking to a machine over TCP, stop the UDP
            // broadcast listener — leaving it running alongside an active
            // connection is what triggers the repeated NECP "File exists"
            // flow-churn errors in Console.
            if newValue != nil {
                discovery.stopScanning()
            }
        }
    }
}

#Preview {
    ContentView()
}
