//
//  JogView.swift
//  CNC Studio
//
//  Created by Cristian Baluta on 21.08.2026.
//

import SwiftUI

struct JogView: View {

    @State private var selectedJogStep: Double = 1.0
    var onJog: ((Double?, Double?, Double?, Double?) -> Void)?

    var body: some View {
        GroupBox("Jog") {
            VStack(spacing: 8) {
                HStack {
                    Text("Step")
                        .font(.caption)

                    Spacer()

                    Picker(
                        "Step",
                        selection: $selectedJogStep
                    ) {
                        Text("0.01 mm").tag(0.01)
                        Text("0.1 mm").tag(0.1)
                        Text("1 mm").tag(1.0)
                        Text("10 mm").tag(10.0)
                        Text("100 mm").tag(100.0)
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }

                HStack(spacing: 5) {
                    Spacer()

                    jogButton(
                        "arrow.up",
                        help: "Y+"
                    ) {
                        jog(y: selectedJogStep)
                    }

                    Spacer()
                }

                HStack(spacing: 5) {
                    jogButton(
                        "arrow.left",
                        help: "X-"
                    ) {
                        jog(x: -selectedJogStep)
                    }

                    Button {
                        jog(x: 0, y: 0)
                    } label: {
                        Image(systemName: "scope")
                            .frame(
                                width: 36,
                                height: 30
                            )
                    }
                    .help("Move X/Y to zero")

                    jogButton(
                        "arrow.right",
                        help: "X+"
                    ) {
                        jog(x: selectedJogStep)
                    }
                }

                HStack(spacing: 5) {
                    Spacer()

                    jogButton(
                        "arrow.down",
                        help: "Y-"
                    ) {
                        jog(y: -selectedJogStep)
                    }

                    Spacer()
                }

                Divider()

                HStack {
                    jogButton(
                        "arrow.up.to.line",
                        help: "Z+"
                    ) {
                        jog(z: selectedJogStep)
                    }

                    Text("Z")
                        .font(.caption)
                        .frame(maxWidth: .infinity)

                    jogButton(
                        "arrow.down.to.line",
                        help: "Z-"
                    ) {
                        jog(z: -selectedJogStep)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func jogButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(minWidth: 36, minHeight: 30)
        }
        .help(help)
    }

    private func jog(x: Double? = nil, y: Double? = nil, z: Double? = nil, a: Double? = nil) {
        onJog?(x, y, z, nil)
    }
}
