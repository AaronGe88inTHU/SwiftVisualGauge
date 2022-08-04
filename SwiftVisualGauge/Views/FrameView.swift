//
//  FrameView.swift
//  SwiftVisualGauge
//
//  Created by Aaron Ge on 2022/8/2.
//


import SwiftUI

struct FrameView: View {
    var image: CGImage?
    var count: Int?
    
    @Binding var captured: Bool
    @Binding var tracking: Bool
    
    @Binding var tracks : [TrackedPolyRect]
//    var tracks = [TrackedPolyRect]()
    
    private let label = Text("Video feed")
    
    
    @State private var imageAreaRect: CGRect = .zero
    
    @GestureState var rubberbandingStart: CGPoint = .zero
    @GestureState var rubberbandingVector : CGSize = .zero
    
//    @State private var rubberbandingRects = [CGRect]()
    @State private var rectMoreThanTwo = false
    
    var drageGesture: some Gesture{
        DragGesture(coordinateSpace: .named("Image"))
            .updating($rubberbandingStart){ value, state, action in
                state = value.startLocation
            }
            .updating($rubberbandingVector){ value, state, action in
                state = value.translation
            }
            .onEnded { value in
                if captured{
                    let pt1 = value.startLocation
                    let pt2 = value.location
                    let rect = CGRect(x: min(pt1.x, pt2.x),
                                      y: min(pt1.y, pt2.y),
                                      width: abs(pt1.x - pt2.x),
                                      height: abs(pt1.y - pt2.y))
                    //                rubberbandingRects.append(rect)
                    let normalizedRect = rubberBandingRectNormalized(rect)
                    tracks.append(TrackedPolyRect(cgRect: normalizedRect,
                                                  color: TrackedObjectsPalette.color(atIndex: tracks.count+1)))
                }
            }
               
    }
    
    var body: some View {
        if let image = image {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading){
                    Image(image, scale: 1.0, orientation: .up, label: label)
                        .resizable()
                        .scaledToFill()
                    
                    
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height,
                            alignment: .center)
                        .clipped()
                        .gesture(drageGesture)
                        .overlay {
                            if captured,
                               let start = rubberbandingStart,
                               let vector = rubberbandingVector{
                                Path{ path in
                                    path.addRect(CGRect(origin: start, size: vector))
                                }
                                .foregroundColor(.purple)
                                .opacity(0.3)
                            }
                            
                            
//                            if captured ,
//                               !tracks.isEmpty{
//                                Path{path in
//                                    path.addRects(rubberbandingRects.map{ rect in
//                                        rect.b
//                                    })
//                                }
//                                .foregroundColor(.red)
//                                .opacity(0.2)
//                            }
                            
                            if tracking || captured,
                               !tracks.isEmpty{
                                ForEach(0..<tracks.count, id: \.self) { index in
                                    Path{path in
//                                        path.stroke(style: <#T##StrokeStyle#>)
                                        path.move(to: scale(tracks[index].topLeft))
                                        path.addLine(to: scale(tracks[index].topRight))
                                        path.addLine(to: scale(tracks[index].bottomRight))
                                        path.addLine(to: scale(tracks[index].bottomLeft))
                                        path.addLine(to: scale(tracks[index].topLeft))
                                    }
                                    .stroke(style: StrokeStyle(lineWidth: tracks[index].style == .solid ? 3 : 1))
                                    .stroke(Color(uiColor: tracks[index].color))
                                    
                                 
                                }
                                
                                
                            }
                            
                        }
                        .onChange(of: tracks.count, perform: { newValue in
                            if newValue > 2{
                                rectMoreThanTwo = true
                                tracks.removeLast()
                            }
                        })
                        .sheet(isPresented: $rectMoreThanTwo) {
                            Text("More than two rects ")
                        }
                        .coordinateSpace(name: "Frame")
                        .task {
//                            tracks.removeAll()
                            imageAreaRect = geometry.frame(in: .named("Frame"))
                        }
                    
                    
                        
                        
                    if let count{
                        Text("\(count)")
                            .frame(width: geometry.size.width / 5)
                            .padding(.top, 40)
                            .font(.caption)
                        
                            .fontWeight(.heavy)
                            .foregroundColor(.mint)
                    }
                }
                
            }
            
            
            
        } else {
            EmptyView()
        }
    }
    
//    private func scaledRect(rect: CGRect, toImageViewPointInViewRect viewRect: CGRect) -> CGRect {
//
////        let pointY = 1.0 - point.y
////        let scaleFactor = self.imageAreaRect.size
//
////        return CGPoint(x: point.x * scaleFactor.width + self.imageAreaRect.origin.x, y: pointY * scaleFactor.height + self.imageAreaRect.origin.y)
////        return CGRect(origin: .init(x: rect.origin.x * viewRect.width, y: (1-rect.origin.y) * viewRect.height) , size: .init(width: rect.width * viewRect.width, height: rect.height * viewRect.height))
//
//        var rect = rect
//
//        rect.origin.y = 1.0 - rect.origin.y - rect.size.height
//
//        rect.size.width *= viewRect.size.width
//        rect.size.height *= viewRect.size.height
//
//        rect.origin.y = (rect.origin.y - viewRect.origin.y) * viewRect.size.height
//        rect.origin.x = (rect.origin.x - viewRect.origin.x) * self.imageAreaRect.size.width
//        return rect
//    }
    
    private func rubberBandingRectNormalized(_ rect: CGRect) -> CGRect{
        guard imageAreaRect.size.width > 0 && imageAreaRect.size.height > 0 else {
            return CGRect.zero
        }
        // Make it relative to imageAreaRect
        var rect = rect
        rect.origin.x = (rect.origin.x - self.imageAreaRect.origin.x) / self.imageAreaRect.size.width
        rect.origin.y = (rect.origin.y - self.imageAreaRect.origin.y) / self.imageAreaRect.size.height
        rect.size.width /= self.imageAreaRect.size.width
        rect.size.height /= self.imageAreaRect.size.height
        // Adjust to Vision.framework input requrement - origin at LLC
        rect.origin.y = 1.0 - rect.origin.y - rect.size.height
        
        return rect
    }
    
    private func scale(_ point: CGPoint) -> CGPoint {
        // Adjust bBox from Vision.framework coordinate system (origin at LLC) to imageView coordinate system (origin at ULC)
        let pointY = 1.0 - point.y
        let scaleFactor = self.imageAreaRect.size
        
        return CGPoint(x: point.x * scaleFactor.width + self.imageAreaRect.origin.x, y: pointY * scaleFactor.height + self.imageAreaRect.origin.y)
    }
    
}

//struct CameraView_Previews: PreviewProvider {
//    static var previews: some View {
//        FrameView(image: nil)
//    }
//}
