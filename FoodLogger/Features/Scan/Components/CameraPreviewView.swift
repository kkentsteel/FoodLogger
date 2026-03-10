import SwiftUI
import AVFoundation

/// UIViewControllerRepresentable that displays the AVCaptureSession preview.
struct CameraPreviewView: UIViewControllerRepresentable {
    let captureSession: AVCaptureSession

    func makeUIViewController(context: Context) -> CameraPreviewViewController {
        let controller = CameraPreviewViewController()
        controller.captureSession = captureSession
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraPreviewViewController, context: Context) {}
}

final class CameraPreviewViewController: UIViewController {
    var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupPreviewLayer()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupPreviewLayer() {
        guard let session = captureSession else { return }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }
}
