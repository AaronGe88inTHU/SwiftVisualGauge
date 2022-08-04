/// Copyright (c) 2021 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import SwiftUI

struct ContentView: View {
    @ObservedObject private var model = ContentViewModel()
    @State private var orientation: UIDeviceOrientation = .portrait
    
//    @State var tracking = false
    @State var captured = false
    //    @State var rects = [CGRect] ()
    
    var body: some View {
        ZStack {
            //            if captured{
            //                ImageView(image: model.image, tracks: $model.trackPolyRect)
            //                    .edgesIgnoringSafeArea(.all)
            //            }
            //            else{
            if captured{
                FrameView(image: model.image,
                          count: 0,
                          captured: $captured,
                          tracking: $model.frameManager.isTracking,
                          tracks: $model.trackPolyRect)
                .edgesIgnoringSafeArea(.all)
            }
            else{
                FrameView(image: model.frame,
                          count: model.frameCount,
                          captured: $captured,
                          tracking: $model.frameManager.isTracking,
                          tracks: $model.trackPolyRect)
                .edgesIgnoringSafeArea(.all)
            }
           
            //            }
            
            ErrorView(error: model.error)
            ControlView(model: model,
                        captured: $captured)
            .padding(.horizontal, 20)
            
        }
        .detectOrientation($orientation)
        .onChange(of: orientation) { newValue in
            model.cameraManager.cameraOrient = getAVCaptureOrientation(newValue: newValue)
            model.cameraManager.changeOrientation()
        }
        .task {
            orientation = UIDevice.current.orientation
            model.cameraManager.cameraOrient = getAVCaptureOrientation(newValue: orientation)
            model.cameraManager.changeOrientation()
            //            model.cameraManager.cameraOrient = getAVCaptureOrientation(newValue: UIDeviceOrientation(rawValue: newValue)))
        }
        //        .sheet(isPresented: $captured) {
        //            if let image = model.image{
        //                Image(uiImage: image)
        //                    .resizable()
        //                    .scaledToFit()
        //            }
        //
        //        }
    }
    
    private func getAVCaptureOrientation(newValue: UIDeviceOrientation)->Int{
        
        switch newValue{
        case .portrait, .faceUp, .faceDown, .unknown:
            return 1
        case .portraitUpsideDown:
            return 2
        case .landscapeLeft:
            return 3
        case .landscapeRight:
            return 4
        @unknown default:
            return 1
        }
        
        
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
