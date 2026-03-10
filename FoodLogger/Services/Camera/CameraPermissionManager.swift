import AVFoundation
import Foundation

@Observable
@MainActor
final class CameraPermissionManager {
    var authorizationStatus: AVAuthorizationStatus = .notDetermined

    init() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func requestPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authorizationStatus = granted ? .authorized : .denied
    }
}
