import SwiftUI

struct ContentView: View {

    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            MachinesList(model: model)
        } detail: {
//            CNCMainView()
            if let machine = model.selectedMachine {
                MachineDetailView(machine: machine)
            } else {
                VStack {
                    Text("Select a machine")
                        .foregroundStyle(.secondary)
                    Button("Try with a mock machine") {
                        model.selectedMachine = MakeraMachine(name: "MockMachine", ip: "00.00.00.00", port: 0, busy: false)
                    }
                }
            }
        }
        .onChange(of: model.selectedMachine) { _, newValue in
            // Once we're actually talking to a machine over TCP, stop the UDP
            // broadcast listener — leaving it running alongside an active
            // connection is what triggers the repeated NECP "File exists"
            // flow-churn errors in Console.
            if newValue != nil {
                model.discovery.stopScanning()
            }
        }
    }
}

//#Preview {
//    ContentView()
//}
