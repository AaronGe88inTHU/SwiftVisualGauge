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
import UIKit

class CameraManager: ObservableObject {
    enum Status {
        case unconfigured
        case configured
        case unauthorized
        case failed
    }
    
    static let shared = CameraManager()
    
    @Published var error: CameraError?
    @Published var photoQualityPrioritizationMode: AVCapturePhotoOutput.QualityPrioritization = .balanced
    @Published var canChangeCameraOrRotate = true
    @Published var rate: Int = 3
    @Published var minRate : Int = 60
    @Published var maxRate : Int = 3
    
    
    let session = AVCaptureSession()
    
    private let sessionQueue = DispatchQueue(label: "cameraSessionQ")
    
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var movieFileOutput: AVCaptureMovieFileOutput?
    
    private var status = Status.unconfigured
   
    
    private var cameraInput:  AVCaptureDeviceInput? = nil
    
    public var cameraOrient: Int = 1
    
    private init() {
        configure()
    }
    
    private func set(error: CameraError?) {
        DispatchQueue.main.async {
            self.error = error
        }
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { authorized in
                if !authorized {
                    self.status = .unauthorized
                    self.set(error: .deniedAuthorization)
                }
                self.sessionQueue.resume()
            }
        case .restricted:
            status = .unauthorized
            set(error: .restrictedAuthorization)
        case .denied:
            status = .unauthorized
            set(error: .deniedAuthorization)
        case .authorized:
            break
        @unknown default:
            status = .unauthorized
            set(error: .unknownAuthorization)
        }
    }
    
    private func configureCaptureSession() {
        guard status == .unconfigured else {
            return
        }
        
        session.beginConfiguration()
        
        defer {
            session.commitConfiguration()
        }
        
        
        session.sessionPreset = .hd1920x1080
        
        let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back)
        
        guard let camera = device else {
            set(error: .cameraUnavailable)
            status = .failed
            return
        }
        
        var isFPSSupported = false
        
        let videoSupportedFrameRateRanges = camera.activeFormat.videoSupportedFrameRateRanges
        for range in videoSupportedFrameRateRanges {
            if (range.maxFrameRate >= Double(rate) && range.minFrameRate <= Double(rate)) {
                minRate = Int(range.minFrameRate)
                maxRate = Int(range.maxFrameRate)
                isFPSSupported = true
                break
            }
        }
        
        
        
        do {
            
            try camera.lockForConfiguration()
            camera.focusMode = .continuousAutoFocus
            if isFPSSupported{
                camera.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(rate))
                camera.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(rate))
            }
            camera.unlockForConfiguration()
            
            
            cameraInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(cameraInput!) {
                session.addInput(cameraInput!)
            } else {
                set(error: .cannotAddInput)
                status = .failed
                return
            }
        } catch {
            set(error: .createCaptureInput(error))
            status = .failed
            return
        }
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            
            videoOutput.videoSettings =
            [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            
            let videoConnection = videoOutput.connection(with: .video)
            videoConnection?.videoOrientation = AVCaptureVideoOrientation(rawValue: cameraOrient) ?? .portrait
        } else {
            set(error: .cannotAddOutput)
            status = .failed
            return
        }
        
        if session.canAddOutput(photoOutput){
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.isLivePhotoCaptureEnabled = false
            photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliveryEnabled
            photoOutput.maxPhotoQualityPrioritization = .quality
            
        }else{
            set(error: .cannotAddOutput)
            status = .failed
            return
        }
        
        status = .configured
    }
    
    
    
    private func configure() {
        checkPermissions()
        
        
        sessionQueue.async {
            self.configureCaptureSession()
            self.session.startRunning()
        }
    }
    
    
    func set(
        _ delegate: AVCaptureVideoDataOutputSampleBufferDelegate,
        queue: DispatchQueue
    ) {
        sessionQueue.async {
            self.videoOutput.setSampleBufferDelegate(delegate, queue: queue)
        }
    }
    
//    func set(_ delegate: AVCapturePhotoCaptureDelegate)
//    {
//        self.photoOutput.capturePhoto(with: <#T##AVCapturePhotoSettings#>, delegate: T##AVCapturePhotoCaptureDelegate)
//    }
    
    public func capturePhoto(_ delegate: AVCapturePhotoCaptureDelegate){
      
        guard let videoOrientation =  AVCaptureVideoOrientation(rawValue: self.cameraOrient)
        else{
            return
        }
        guard let cameraInput
        else{
            return
        }
        
        sessionQueue.async {
            guard let photoOutputConnection = self.photoOutput.connection(with: .video)
            else{
                return
            }
            
            photoOutputConnection.videoOrientation = videoOrientation
//            if cameraInput.device.position == .front{
//                photoOutputConnection.isVideoMirrored = true
//            }
            
            var photoSettings = AVCapturePhotoSettings()
            
            // Capture HEIF photos when supported. Enable auto-flash and high-resolution photos.
            if  self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            
            
            if cameraInput.device.isFlashAvailable {
                photoSettings.flashMode = .auto
            }
            
            
            photoSettings.isHighResolutionPhotoEnabled = true
            if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
                photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
            }
            
            self.photoOutput.capturePhoto(with: photoSettings, delegate: delegate)
            // Live Photo capture is not supported in movie mode.
//            if self.livePhotoMode == .on && self.photoOutput.isLivePhotoCaptureSupported {
//                let livePhotoMovieFileName = NSUUID().uuidString
//                let livePhotoMovieFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((livePhotoMovieFileName as NSString).appendingPathExtension("mov")!)
//                photoSettings.livePhotoMovieFileURL = URL(fileURLWithPath: livePhotoMovieFilePath)
//            }
            
//            photoSettings.isDepthDataDeliveryEnabled = (self.depthDataDeliveryMode == .on
//                                                        && self.photoOutput.isDepthDataDeliveryEnabled)
//
//            photoSettings.isPortraitEffectsMatteDeliveryEnabled = (self.portraitEffectsMatteDeliveryMode == .on
//                                                                   && self.photoOutput.isPortraitEffectsMatteDeliveryEnabled)
            
//            if photoSettings.isDepthDataDeliveryEnabled {
//                if !self.photoOutput.availableSemanticSegmentationMatteTypes.isEmpty {
//                    photoSettings.enabledSemanticSegmentationMatteTypes = self.selectedSemanticSegmentationMatteTypes
//                }
//            }
            
            photoSettings.photoQualityPrioritization = self.photoQualityPrioritizationMode
            
//            let photoCaptureProcessor = PhotoCaptureProcessor(with: photoSettings, willCapturePhotoAnimation: {
//                // Flash the screen to signal that AVCam took a photo.
//                DispatchQueue.main.async {
//                    self.previewView.videoPreviewLayer.opacity = 0
//                    UIView.animate(withDuration: 0.25) {
//                        self.previewView.videoPreviewLayer.opacity = 1
//                    }
//                }
//            }, livePhotoCaptureHandler: { capturing in
//                self.sessionQueue.async {
//                    if capturing {
//                        self.inProgressLivePhotoCapturesCount += 1
//                    } else {
//                        self.inProgressLivePhotoCapturesCount -= 1
//                    }
//
//                    let inProgressLivePhotoCapturesCount = self.inProgressLivePhotoCapturesCount
//                    DispatchQueue.main.async {
//                        if inProgressLivePhotoCapturesCount > 0 {
//                            self.capturingLivePhotoLabel.isHidden = false
//                        } else if inProgressLivePhotoCapturesCount == 0 {
//                            self.capturingLivePhotoLabel.isHidden = true
//                        } else {
//                            print("Error: In progress Live Photo capture count is less than 0.")
//                        }
//                    }
//                }
//            }, completionHandler: { photoCaptureProcessor in
//                // When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
//                self.sessionQueue.async {
//                    self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
//                }
//            }, photoProcessingHandler: { animate in
//                // Animates a spinner while photo is processing
//                DispatchQueue.main.async {
//                    if animate {
//                        self.spinner.hidesWhenStopped = true
//                        self.spinner.center = CGPoint(x: self.previewView.frame.size.width / 2.0, y: self.previewView.frame.size.height / 2.0)
//                        self.spinner.startAnimating()
//                    } else {
//                        self.spinner.stopAnimating()
//                    }
//                }
//            }
//            )
            
            // Specify the location the photo was taken
//            photoCaptureProcessor.location = self.locationManager.location
            
            // The photo output holds a weak reference to the photo capture delegate and stores it in an array to maintain a strong reference.
//            self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
//            self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
        }
    }
    
    
//    public func recordMovie(){
//        canChangeCameraOrRotate = false
//        sessionQueue.async {
//            let movieFileOutput = AVCaptureMovieFileOutput()
//
//            guard self.session.canAddOutput(movieFileOutput)
//            else{
//                return
//            }
//
//            self.session.beginConfiguration()
//            self.session.addOutput(movieFileOutput)
//            self.session.sessionPreset = .high
//
//        }
//    }
    
    public func changeCamera(){
        guard canChangeCameraOrRotate
        else
        {
            return
        }
        status = .unconfigured
        sessionQueue.async {
            let currentVideoDevice = self.cameraInput!.device
            let currentPosition = currentVideoDevice.position
            
            let backVideoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInDualWideCamera, .builtInWideAngleCamera],
                                                                                   mediaType: .video, position: .back)
            let frontVideoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera, .builtInWideAngleCamera],
                                                                                    mediaType: .video, position: .front)
            var newVideoDevice: AVCaptureDevice? = nil
            
            switch currentPosition {
            case  .front:
                newVideoDevice = backVideoDeviceDiscoverySession.devices.first
                
            case .unspecified,.back:
                newVideoDevice = frontVideoDeviceDiscoverySession.devices.first
                
            @unknown default:
                //                print("Unknown capture position. Defaulting to back, dual-camera.")
                newVideoDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
            }
            
            if let videoDevice = newVideoDevice {
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                    
                    self.session.beginConfiguration()
                    
                    defer{
                        self.session.commitConfiguration()
                    }
                    
                    // Remove the existing device input first, because AVCaptureSession doesn't support
                    // simultaneous use of the rear and front cameras.
                    self.session.removeInput(self.cameraInput!)
                    
                    if self.session.canAddInput(videoDeviceInput) {
                        NotificationCenter.default.removeObserver(self, name: .AVCaptureDeviceSubjectAreaDidChange, object: currentVideoDevice)
                        
                        self.session.addInput(videoDeviceInput)
                        self.cameraInput = videoDeviceInput
                        
                        
                    } else {
                        self.session.addInput(videoDeviceInput)
                    }
                    
                    self.updateOrientation()
                    
                    
                    //                    if let connection = self.movieFileOutput?.connection(with: .video) {
                    //                        self.session.sessionPreset = .high
                    //
                    //                        self.selectedMovieMode10BitDeviceFormat = self.tenBitVariantOfFormat(activeFormat: self.videoDeviceInput.device.activeFormat)
                    //
                    //                        if self.selectedMovieMode10BitDeviceFormat != nil {
                    //                            DispatchQueue.main.async {
                    //                                self.HDRVideoModeButton.isEnabled = true
                    //                            }
                    //
                    //                            if self.HDRVideoMode == .on {
                    //                                do {
                    //                                    try self.videoDeviceInput.device.lockForConfiguration()
                    //                                    self.videoDeviceInput.device.activeFormat = self.selectedMovieMode10BitDeviceFormat!
                    //                                    print("Setting 'x420' format \(String(describing: self.selectedMovieMode10BitDeviceFormat)) for video recording")
                    //                                    self.videoDeviceInput.device.unlockForConfiguration()
                    //                                } catch {
                    //                                    print("Could not lock device for configuration: \(error)")
                    //                                }
                    //                            }
                    //                        }
                    //
                    //                        if connection.isVideoStabilizationSupported {
                    //                            connection.preferredVideoStabilizationMode = .auto
                    //                        }
                    //                    }
                    
                    /*
                     Set Live Photo capture and depth data delivery if it's supported. When changing cameras, the
                     `livePhotoCaptureEnabled` and `depthDataDeliveryEnabled` properties of the AVCapturePhotoOutput
                     get set to false when a video device is disconnected from the session. After the new video device is
                     added to the session, re-enable them on the AVCapturePhotoOutput, if supported.
                     */
                    //                    self.photoOutput.isLivePhotoCaptureEnabled = self.photoOutput.isLivePhotoCaptureSupported
                    //                    self.photoOutput.isDepthDataDeliveryEnabled = self.photoOutput.isDepthDataDeliverySupported
                    //                    self.photoOutput.isPortraitEffectsMatteDeliveryEnabled = self.photoOutput.isPortraitEffectsMatteDeliverySupported
                    //                    self.photoOutput.enabledSemanticSegmentationMatteTypes = self.photoOutput.availableSemanticSegmentationMatteTypes
                    //                    self.selectedSemanticSegmentationMatteTypes = self.photoOutput.availableSemanticSegmentationMatteTypes
                    //                    self.photoOutput.maxPhotoQualityPrioritization = .quality
                    //
                    //                    self.session.commitConfiguration()
                } catch {
                    print("Error occurred while creating video device input: \(error)")
                    self.set(error: CameraError.cannotAddInput)
                }
            }
            
            //            DispatchQueue.main.async {
            //                self.cameraButton.isEnabled = true
            //                self.recordButton.isEnabled = self.movieFileOutput != nil
            //                self.photoButton.isEnabled = true
            //                self.livePhotoModeButton.isEnabled = true
            //                self.captureModeControl.isEnabled = true
            //                self.depthDataDeliveryButton.isEnabled = self.photoOutput.isDepthDataDeliveryEnabled
            //                self.portraitEffectsMatteDeliveryButton.isEnabled = self.photoOutput.isPortraitEffectsMatteDeliveryEnabled
            //                self.semanticSegmentationMatteDeliveryButton.isEnabled = (self.photoOutput.availableSemanticSegmentationMatteTypes.isEmpty || self.depthDataDeliveryMode == .off) ? false : true
            //                self.photoQualityPrioritizationSegControl.isEnabled = true
            
            //            }
            
            self.status = .configured
        }
        
        
    }
    
    public func changeOrientation(){
        guard canChangeCameraOrRotate
        else
        {
            return
        }
        
        
        status = .unconfigured
        sessionQueue.async {
            
            self.session.beginConfiguration()
            
            defer{
                self.session.commitConfiguration()
            }

            self.updateOrientation()
            self.status = .configured
        
        }
    }
    
    private func updateOrientation(){
      
        self.session.removeOutput(self.videoOutput)
        
        if self.session.canAddOutput(self.videoOutput) {
            self.session.addOutput(self.videoOutput)
            
            self.videoOutput.videoSettings =
            [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            
            
            if let videoConnection = self.videoOutput.connection(with: .video){
                videoConnection.videoOrientation = AVCaptureVideoOrientation(rawValue: self.cameraOrient) ?? .portrait
                
                let currentVideoDevice = self.cameraInput!.device
                let currentPosition = currentVideoDevice.position
                if currentPosition == .front{
                    if videoConnection.isVideoMirroringSupported{
                        videoConnection.automaticallyAdjustsVideoMirroring = false
                        videoConnection.isVideoMirrored = true
                    }
                }
            }
                
        } else {
            self.set(error: .cannotAddOutput)
            self.status = .failed
            return
        }
    }
    
}
