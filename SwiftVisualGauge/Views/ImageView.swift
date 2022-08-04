//
//  ImageView.swift
//  SwiftVisualGauge
//
//  Created by Aaron Ge on 2022/8/2.
//

import SwiftUI

struct ImageView: View {
    var image: CGImage?
    
    //    private let label = Text("Video feed")
    @Binding var tracks : [TrackedPolyRect]
    
    

    
   
    
    var body: some View {
        if let image = image {
            GeometryReader { geometry in
                Image(image, scale: 1, orientation: .up, label: Text(""))
//                Image(uiImage: image, orientation: .upMirrored)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height,
                        alignment: .center)
                    .clipped()
                    .coordinateSpace(name: "Image")
                    
                
            }
        } else {
            EmptyView()
        }
    }
    

   
}
