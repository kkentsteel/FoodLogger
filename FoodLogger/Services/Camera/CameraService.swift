import AVFoundation
import UIKit

/// Manages AVCaptureSession for barcode scanning and photo capture.
final class CameraService: NSObject, @unchecked Sendable {
    let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private var photoContinuation: CheckedContinuation<UIImage, Error>?

    var isSessionRunning: Bool {
        captureSession.isRunning
    }

    /// Configures the capture session for barcode detection.
    func configureBarcodeScanning() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        captureSession.sessionPreset = .high

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.noCameraAvailable
        }

        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        guard captureSession.canAddInput(videoInput) else {
            throw CameraError.cannotAddInput
        }
        captureSession.addInput(videoInput)
        videoDeviceInput = videoInput

        // Enable auto-focus for barcode readability
        if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
            try videoDevice.lockForConfiguration()
            videoDevice.focusMode = .continuousAutoFocus
            videoDevice.unlockForConfiguration()
        }
    }

    /// Configures the capture session for photo capture (nutrition label scanning).
    func configurePhotoCapture() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        captureSession.sessionPreset = .photo

        // Add camera input if not already present
        if videoDeviceInput == nil {
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                throw CameraError.noCameraAvailable
            }

            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            guard captureSession.canAddInput(videoInput) else {
                throw CameraError.cannotAddInput
            }
            captureSession.addInput(videoInput)
            videoDeviceInput = videoInput
        }

        // Add photo output
        guard captureSession.canAddOutput(photoOutput) else {
            throw CameraError.cannotAddOutput
        }
        captureSession.addOutput(photoOutput)
    }

    /// Captures a photo and returns a UIImage.
    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    /// Adds a metadata output for barcode detection.
    func addMetadataOutput(_ output: AVCaptureMetadataOutput) throws {
        guard captureSession.canAddOutput(output) else {
            throw CameraError.cannotAddOutput
        }
        captureSession.addOutput(output)
    }

    func startSession() {
        guard !captureSession.isRunning else { return }
        captureSession.startRunning()
    }

    func stopSession() {
        guard captureSession.isRunning else { return }
        captureSession.stopRunning()
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            photoContinuation?.resume(throwing: error)
            photoContinuation = nil
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            photoContinuation?.resume(throwing: CameraError.cannotCapturePhoto)
            photoContinuation = nil
            return
        }

        photoContinuation?.resume(returning: image)
        photoContinuation = nil
    }
}

// MARK: - Errors

enum CameraError: LocalizedError {
    case noCameraAvailable
    case cannotAddInput
    case cannotAddOutput
    case cannotCapturePhoto

    var errorDescription: String? {
        switch self {
        case .noCameraAvailable:
            return "No camera available on this device"
        case .cannotAddInput:
            return "Unable to use camera input"
        case .cannotAddOutput:
            return "Unable to configure camera output"
        case .cannotCapturePhoto:
            return "Failed to capture photo"
        }
    }
}
