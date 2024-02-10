//
//  ContentView.swift
//  tennispose
//
//  Created by Pradeep Banavara on 07/02/24.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var frameModel = FrameHandler()
    var body: some View {
        FrameView(image: frameModel.frame).ignoresSafeArea()
    }
    
    
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
