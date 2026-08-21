//
//  MachineRow.swift
//  CNC Studio
//
//  Created by Cristian Baluta on 21.08.2026.
//

import SwiftUI

struct MachineRow: View {

    let machine: DummyMachine

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 5
        ) {

            HStack(spacing: 7) {

                Image(systemName: machine.state.symbol)
                    .foregroundStyle(machine.state.color)
                    .font(.system(size: 10))

                Text(machine.name)
                    .font(.headline)
            }

            HStack {

                Text(machine.state.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if machine.state == .running {
                    Text("\(Int(machine.progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if let program = machine.program {

                Text(program)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if machine.state == .running {

                ProgressView(value: machine.progress)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 5)
    }
}
