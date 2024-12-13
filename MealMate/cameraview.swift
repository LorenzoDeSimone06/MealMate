//
//  cameraview.swift
//  MealMate
//
//  Created by Lorenzo De Simone on 10/12/24.
//

import SwiftUI
import AVFoundation

// The main view that displays the camera preview and a button to start/stop the camera
struct CameraView: View {
    // Observes the camera's state and updates the UI when changes occur
    @ObservedObject var viewModel = CameraViewModel()
    
    // Tracks whether the camera is currently running
    @State private var isCameraRunning = false

    var body: some View {
        ZStack {
            // Display the camera preview when running
            if isCameraRunning {
                CameraPreview(session: viewModel.captureSession)
                    .edgesIgnoringSafeArea(.all)
            } else {
                // Placeholder text when the camera is not running
                Text("Press 'Start Camera' to begin")
                    .font(.headline)
                    .foregroundColor(.gray)
            }

            // Vertical stack for the UI
            VStack {
                Spacer() // Push UI elements to the bottom
                
                // List detected barcodes (binds to view model's array)
                if !viewModel.detectedBarcodes.isEmpty {
                    DetectedBarcodesList(barcodes: $viewModel.detectedBarcodes)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                        .padding()
                }

                // Button to start/stop the camera
                Button(action: {
                    if !isCameraRunning {
                        isCameraRunning = true
                        viewModel.startSession()
                    }
                }) {
                    Text(isCameraRunning ? "Camera Running" : "Start Camera")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isCameraRunning ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                }
            }
        }
    }
}

// List view for displaying detected barcodes
struct DetectedBarcodesList: View {
    @Binding var barcodes: [String]

    var body: some View {
        VStack {
            Text("Detected Barcodes")
                .font(.headline)
            List(barcodes, id: \.self) { barcode in
                Text(barcode)
            }
            .frame(height: 200) // Limit height
        }
    }
}

// A UIViewRepresentable for displaying the camera feed in SwiftUI
struct CameraPreview: UIViewRepresentable {
    var session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Update preview layer's frame on the main thread
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer else {
            print("Failed to retrieve preview layer")
            return
        }

        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
        }
    }
}

