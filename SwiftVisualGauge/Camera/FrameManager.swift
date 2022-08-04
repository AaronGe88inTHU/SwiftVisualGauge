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

import AVFoundation
import Vision


enum VisionTrackerError: Error {
    case readerInitializationFailed
    case firstFrameReadFailed
    case objectTrackingFailed
    case rectangleDetectionFailed
}


class FrameManager: NSObject, ObservableObject {
    static let shared = FrameManager()
    
    @Published var current: CVPixelBuffer?
//    @Published var time: CMTime?
    @Published var photoData: Data?
    
    @Published var frameCount: Int = 0
//    @Published var state: State = .stopped
    @Published var isTracking = false
    
    
    @Published var error: VisionTrackerError?
    @Published var trackingLevel = VNRequestTrackingLevel.accurate
    @Published var inputObservations = [UUID: VNDetectedObjectObservation]()
    @Published var trackedObjects = [UUID: TrackedPolyRect]()

    var orientation: CGImagePropertyOrientation = .up
    private var cancelRequested = false
    private let trackHandler = VNSequenceRequestHandler()
   
    
    
    private let videoOutputQueue = DispatchQueue(
        label: "VideoOutputQ",
        qos: .userInitiated,
        attributes: [],
        autoreleaseFrequency: .workItem)
    
    private var trackQueue = DispatchQueue(label: "VisionTrackerQ", qos: .userInitiated)
    
    private override init() {
        super.init()
        CameraManager.shared.set(self, queue: videoOutputQueue)
    }
    
    
    public func prepareTrack(_ objectsToTrack: [TrackedPolyRect]) {
        
//        var inputObservation = VNDetectedObjectObservation(boundingBox: boundingBox)
        
//        inputObservations = boundingBoxs.map{
//            VNDetectedObjectObservation(boundingBox: $0)
//        }
        
        inputObservations.removeAll()
        
        for rect in objectsToTrack{
            let inputObservation = VNDetectedObjectObservation(boundingBox: rect.boundingBox)
            inputObservations[inputObservation.uuid] = inputObservation
            trackedObjects[inputObservation.uuid] = rect
        }
        
        frameCount = 0
        
        
    }
        
    
}


extension FrameManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if let buffer = sampleBuffer.imageBuffer {
            if !isTracking || inputObservations.isEmpty{
                DispatchQueue.main.async {
                    self.current = buffer
                }
            }
            
            else{
//                trackQueue.async {
                    let requests = self.inputObservations.map {
                        let request = VNTrackObjectRequest(detectedObjectObservation: $0.value)
                        request.trackingLevel = trackingLevel
                        return request
                    }
                    
                    do{
                        
                        try self.trackHandler.perform(requests, on: buffer)
                        
//                        let observations = requests.map { request in
//                            request.results!.first! as! VNDetectedObjectObservation
//                        }
                        
                        let objRects: [(VNDetectedObjectObservation, TrackedPolyRect)] = requests.compactMap { request in
                            guard let results = request.results
                            else{
                                return nil
                            }
                            
                            guard let observation = results.first as? VNDetectedObjectObservation
                            else{
                                return nil
                            }
                            
                            let rectStyle: TrackedPolyRectStyle = observation.confidence > 0.5 ? .solid : .dashed
                            print(observation.confidence)
                            let knowRect = trackedObjects[observation.uuid]!
                            
                            return (observation, TrackedPolyRect(observation: observation,
                                                   color: knowRect.color,
                                                   style: rectStyle))
                            
                        }
//                        DispatchQueue.main.async {
                        
                        for objRect in objRects {
                            self.inputObservations[objRect.0.uuid] = objRect.0
                            self.trackedObjects[objRect.0.uuid] = objRect.1
                        }
                       
//                            print(observations)
//                        }
                        
//                        print  (self.inputObservations.count)
                    }
                    catch{
                        self.error = VisionTrackerError.objectTrackingFailed
//                        return
//                    }
                }
                
                DispatchQueue.main.async {
                    self.current = buffer
                    self.frameCount = self.frameCount + 1
//                    self.time = CMTimeMakeWithSeconds(<#T##seconds: Float64##Float64#>, preferredTimescale: <#T##Int32#>)
                }
                
                
            }
        }
    }
}

extension FrameManager: AVCapturePhotoCaptureDelegate{
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        } else {
            photoData = photo.fileDataRepresentation()
        }
    }
}

