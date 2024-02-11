//
//  FrameHandler.swift
//  tennispose
//
//  Created by Pradeep Banavara on 07/02/24.
//

import Foundation
import AVFoundation
import CoreImage
import CoreML


struct Prediction {
    var labelIndex: Int
    var confidence: Float
    var boundingBox: CGRect
    var points: NSMutableArray
}

class FrameHandler: NSObject, ObservableObject{
    @Published var frame: CGImage?
    private let captureSession = AVCaptureSession()
    private var permissionGranted = false
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private let context = CIContext()
    
    override init() {
        super.init()
        checkPermission()
        sessionQueue.async { [unowned self] in
            self.setupCaptureSession()
            self.captureSession.startRunning()
        }
    }
    
    func setupCaptureSession() {
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey) : kCVPixelFormatType_32BGRA ]
        guard permissionGranted else { return }
        guard let videoDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) else { return }
        NSLog("Device acquired")
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        guard captureSession.canAddInput(videoDeviceInput) else { return }
        captureSession.addInput(videoDeviceInput)
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sampleBufferForQueue"))
        captureSession.addOutput(videoOutput)
        videoOutput.connection(with: .video)?.videoRotationAngle = 90
    }
    
    func checkPermission() {
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            
        case .notDetermined:
            requestPermission()
        
        default:
            permissionGranted = false
            
        }
    }
    
    func requestPermission() {
        NSLog("request permissions called")
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            permissionGranted = granted
            NSLog(permissionGranted.description)
        }
    }
    
    
}

extension FrameHandler: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cgImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        DispatchQueue.main.async { [unowned self] in
            self.frame = cgImage
        }
    }
    
    func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        var predictions: NSMutableArray = NSMutableArray()
        
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
        let pointer  = baseAddress!.assumingMemoryBound( to: UInt8.self )
        let height   = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let cropWidth = 640
        let cropHeight = 640
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let options: NSDictionary = [:]
        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        var targetBuffer: CVPixelBuffer?
        let results = CVPixelBufferCreateWithBytes(
            kCFAllocatorDefault,
            cropWidth,
            cropHeight,
            kCVPixelFormatType_32BGRA,
            pointer,
            bytesPerRow,
            nil,
            nil,
            options,
            &targetBuffer
        )
        NSLog("Pixel buffer resizing results", results)
        
        let model = try? yolov8n_pose()
        let output = try? model!.prediction(image: targetBuffer!)
        let features = output?.featureValue(for: "var_1035")
        let features_val = features?.multiArrayValue
        print (features_val?.shape)
        let new_predictions = processFeaturesMultiArray(features: features_val!, predictions: predictions)
        
        return nil
    }
    
    func processFeaturesMultiArray(features: MLMultiArray, predictions:NSMutableArray) -> NSMutableArray{
        /**
         This function takes in a  MLMultiArray of shape ( 1, 56, 8500 ) and converts that array into keypoints for overlay on images
         */
        let gridWidth = features.shape[2].intValue
        let gridHeight = features.shape[1].intValue
        let keypointsNum = 17 // keypoints
        let keypointsDim = 3 // Dimension
        let classesNum = gridHeight - 4 - (keypointsNum * keypointsDim)
        let threshold:Float = 0.25
        let inputWidth:Float = 640.0
        for j in stride(from: 0, to: gridWidth, by: 1) {
            var classIndex = -1
            var maxScore: Float = 0.0
            for i in stride(from: 4, to:  4 + classesNum, by: 1){
                let score = (features[(i * gridWidth) + j]).floatValue
                if (score > maxScore) {
                    classIndex = i - 4
                    maxScore = score
                }
            }
            if (maxScore > threshold) {
                var x = features[(0 * gridWidth) + j].floatValue
                var y = features[(1 * gridWidth) + j].floatValue
                let w = features[(2 * gridWidth) + j].floatValue
                let h = features[(3 * gridWidth) + j].floatValue
                x -= w/2
                y -= h/2
                let rectWidth = x/inputWidth
                let rectHeight = 1.0 - (y + h)/inputWidth
                let rect = CGRectMake(CGFloat(rectWidth), CGFloat(rectHeight), CGFloat(w)/CGFloat(inputWidth), CGFloat(h)/CGFloat(inputWidth))
                let pointsArray = NSMutableArray()
                let visibleArray = NSMutableArray()
                
                for k in stride(from: 4 + classesNum, to: gridHeight, by: 3){
                    var x = features[((k + 0) * gridWidth) + j]
                    var y = features[((k + 1) * gridWidth) + j]
                    var v = features[((k + 2) * gridWidth) + j]
                    var point:CGPoint = CGPointMake(CGFloat(x) / CGFloat(inputWidth), 1.0 - CGFloat(y) / CGFloat(inputWidth))
                    pointsArray.add(point)
                }
                var prediction:Prediction = Prediction(labelIndex: classIndex, confidence: maxScore, boundingBox: rect, points: pointsArray)
                predictions.add(prediction)
                
            }
            
            
        }
        return predictions
        
    }
    
}
