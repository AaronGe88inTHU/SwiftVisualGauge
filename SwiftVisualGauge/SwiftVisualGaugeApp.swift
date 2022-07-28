//
//  SwiftVisualGaugeApp.swift
//  SwiftVisualGauge
//
//  Created by Aaron Ge on 2022/7/26.
//

import SwiftUI

@main
struct SwiftVisualGaugeApp: App {
//    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
//                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
