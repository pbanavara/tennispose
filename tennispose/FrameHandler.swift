//
//  FrameHandler.swift
//  tennispose
//
//  Created by Pradeep Banavara on 07/02/24.
//

import Foundation
import AVFoundation
import CoreImage


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

        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
        let pointer  = baseAddress!.assumingMemoryBound( to: UInt8.self )
        let height   = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let pixBytes = height * bytesPerRow
        let cropWidth = 640
        let cropHeight = 640
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let options: NSDictionary = [:]

        let context = CGContext(data: baseAddress, width: cropWidth, height: cropHeight, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
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
        
        
        let model = try? yolov8n_pose()
        let output = try? model!.prediction(image: targetBuffer!)
        let features = output?.featureValue(for: "var_1035")
        let features_val = features?.multiArrayValue
        print (features_val?.shape)
        return nil
    }
    
}
