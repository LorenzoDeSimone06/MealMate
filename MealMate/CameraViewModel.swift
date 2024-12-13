//
//  CameraViewModel.swift
//  MealMate
//
//  Created by Lorenzo De Simone on 10/12/24.
//

import AVFoundation
import Vision
import SwiftUI

class CameraViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    // Camera Properties
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var lastDetectionTime = Date()

    @Published var detectedBarcodes: [String] = [] // List of detected barcodes
    @Published var nutritionalInfo: NutritionItem? // Store fetched nutritional info
    
    private let nutritionixService = NutritionixService() // Instance of the NutritionixService

    override init() {
        super.init()
        setupCamera()
        observeSessionRuntimeErrors()
    }

    // Start the Camera Session
    func startSession() {
        checkCameraPermissions { granted in
            guard granted else {
                print("Camera access denied.")
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }

    // Camera Configuration
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            print("No video device available.")
            return
        }

        do {
            // Add camera input
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                print("Failed to add camera input.")
            }

            // Add video output
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            } else {
                print("Failed to add video output.")
            }

            captureSession.sessionPreset = .photo
        } catch {
            print("Error setting up camera input: \(error)")
        }
    }

    // Barcode Detection
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let currentTime = Date()
        guard currentTime.timeIntervalSince(lastDetectionTime) > 0.2 else { return }
        lastDetectionTime = currentTime

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let barcodeRequest = VNDetectBarcodesRequest { request, error in
            if let error = error {
                print("Error detecting barcodes: \(error.localizedDescription)")
                return
            }

            guard let results = request.results as? [VNBarcodeObservation] else { return }
            for barcode in results {
                if let payload = barcode.payloadStringValue {
                    DispatchQueue.main.async {
                        if !self.detectedBarcodes.contains(payload) {
                            self.detectedBarcodes.append(payload)
                            self.fetchNutritionalInfo(for: payload) // Fetch nutritional data when a barcode is detected
                        }
                    }
                }
            }
        }

        let orientation = imageOrientationForCurrentDeviceOrientation()
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try requestHandler.perform([barcodeRequest])
        } catch {
            print("Error performing barcode detection: \(error.localizedDescription)")
        }
    }

    // Fetch Nutritional Info from the NutritionixService
    private func fetchNutritionalInfo(for barcode: String) {
        nutritionixService.fetchNutritionData(for: barcode) { result in
            switch result {
            case .success(let nutritionData):
                DispatchQueue.main.async {
                    self.nutritionalInfo = nutritionData // Update the UI with nutritional data
                }
            case .failure(let error):
                print("Failed to fetch nutritional info: \(error.localizedDescription)")
            }
        }
    }

    // Helper Methods for Device Orientation
    private func imageOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        switch UIDevice.current.orientation {
        case .portrait: return .right
        case .landscapeLeft: return .up
        case .landscapeRight: return .down
        case .portraitUpsideDown: return .left
        default: return .right
        }
    }

    private func observeSessionRuntimeErrors() {
        NotificationCenter.default.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: captureSession,
            queue: .main
        ) { notification in
            guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
                print("Unknown runtime error occurred.")
                return
            }
            self.handleSessionError(error)
        }
    }

    private func handleSessionError(_ error: AVError) {
        print("Runtime error: \(error.localizedDescription)")

        if !captureSession.isRunning && error.code == .mediaServicesWereReset {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }

    private func checkCameraPermissions(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }
}

