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

import CoreImage
import UIKit

class ContentViewModel: ObservableObject {
    @Published var error: Error?
    @Published var frame: CGImage?
    @Published var image: CGImage?
//    @Published var rects = [CGRect]()
    @Published var frameCount = 0
    @Published var trackPolyRect = [TrackedPolyRect]()
    
//    @Published var devicePosition: AVCaptureDevice.Position = .back
    @Published var cameraManager = CameraManager.shared
    @Published var frameManager = FrameManager.shared
    
    
    private let context = CIContext()
    
   
    
    init() {
      
        setupSubscriptions()
    }
    
    func setupSubscriptions() {
        // swiftlint:disable:next array_init
        cameraManager.$error
            .receive(on: RunLoop.main)
            .map { $0 }
            .assign(to: &$error)
        
        frameManager.$error
            .receive(on: RunLoop.main)
            .map{$0}
            .assign(to: &$error)
        
        
        frameManager.$frameCount
            .receive(on: RunLoop.main)
            .compactMap { count in
                count
            }
            .assign(to: &$frameCount)
            
        frameManager.$current
            .receive(on: RunLoop.main)
            .compactMap { buffer in
                guard let image = CGImage.create(from: buffer) else {
                    return nil
                }
                var ciImage = CIImage(cgImage: image)
//                ciImage.
                
                //                if self.comicFilter {
                //                    ciImage = ciImage.applyingFilter("CIComicEffect")
                //                }
                //
                //                if self.monoFilter {
                //                    ciImage = ciImage.applyingFilter("CIPhotoEffectNoir")
                //                }
                //
                //                if self.crystalFilter {
                //                    ciImage = ciImage.applyingFilter("CICrystallize")
                //                }
                
                return self.context.createCGImage(ciImage, from: ciImage.extent)
            }
            .assign(to: &$frame)
        
        
        frameManager.$inputObservations
            .receive(on: RunLoop.main)
            .compactMap { observations in
                observations.map { observation in
                    TrackedPolyRect(observation: observation.value, color: .green)
                }
            }
            .assign(to: &$trackPolyRect)
        
        frameManager.$photoData
            .receive(on: RunLoop.main)
            .compactMap { photoData in
                guard let photoData,
                      let image = UIImage(data: photoData)
                else{
                    return nil
                }
                
                return image.cgImage
            }
            .assign(to: &$image)
        
        
    }
}
