import SwiftUI
import Combine
import AVFoundation
import UIKit

final class CameraEngine: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    @Published var capturedImage: UIImage?
    @Published var isAuthorized = false
    @Published var permissionDenied = false
    @Published var isCapturing = false
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.chromaroom.camera.session")
    private var configured = false
    private var ready = false

    func requestAccessAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.isAuthorized = true }
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { self.isAuthorized = granted; self.permissionDenied = !granted }
                if granted { self.configureAndStart() }
            }
        default:
            DispatchQueue.main.async { self.isAuthorized = false; self.permissionDenied = true }
        }
    }

    private func configureAndStart() {
        sessionQueue.async {
            if self.configured {
                if !self.session.isRunning { self.session.startRunning() }
                return
            }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input), self.session.canAddOutput(self.output) else {
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)
            self.session.addOutput(self.output)
            self.output.isHighResolutionCaptureEnabled = true
            self.session.commitConfiguration()
            self.configured = true
            self.session.startRunning()
            DispatchQueue.main.async { self.ready = true }
        }
    }

    func capture() {
        guard isAuthorized, ready, !isCapturing else { return }
        isCapturing = true
        sessionQueue.async {
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image: UIImage?
        if let error { print("CHROMA ROOM capture error: \(error.localizedDescription)"); image = nil }
        else if let data = photo.fileDataRepresentation() { image = UIImage(data: data) }
        else { image = nil }
        DispatchQueue.main.async { if let image { self.capturedImage = image }; self.isCapturing = false }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: CameraPreviewView, context: Context) { uiView.previewLayer.session = session }
}

final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
