//
//  tennisposeApp.swift
//  tennispose
//
//  Created by Pradeep Banavara on 07/02/24.
//

import SwiftUI

@main
struct tennisposeApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
