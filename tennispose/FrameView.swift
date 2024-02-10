//
//  FrameView.swift
//  tennispose
//
//  Created by Pradeep Banavara on 07/02/24.
//

import SwiftUI

struct FrameView: View {
    var image: CGImage?
    private let label = Text("Frame")
    var body: some View {
        if let image = image {
            Image(image, scale: 1.0, orientation: .up, label: label)
        } else {
            Color.black
            
        }
    }
}

#Preview {
    FrameView()
}
