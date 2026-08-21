//
//  MainModel.swift
//  CNC Studio
//
//  Created by Cristian Baluta on 21.08.2026.
//

import SwiftUI

@MainActor
class AppModel: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var discovery = MachineDiscovery()
    @Published var selectedMachine: MakeraMachine?

}
