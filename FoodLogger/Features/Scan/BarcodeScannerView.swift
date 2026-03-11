import SwiftUI
import SwiftData

struct BarcodeScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = BarcodeScannerViewModel()

    var body: some View {
        ZStack {
            if viewModel.permissionManager.isAuthorized {
                cameraView
            } else if viewModel.permissionManager.isDenied {
                permissionDeniedView
            } else {
                requestPermissionView
            }
        }
        .task {
            viewModel.modelContext = modelContext
            if viewModel.permissionManager.authorizationStatus == .notDetermined {
                await viewModel.permissionManager.requestPermission()
            }
            if viewModel.permissionManager.isAuthorized {
                viewModel.setupCamera()
                viewModel.startScanning()
            }
        }
        .onDisappear {
            viewModel.stopScanning()
        }
        .sheet(isPresented: showResultSheet) {
            if let food = viewModel.scannedFood {
                ScanResultView(
                    result: Binding(
                        get: { viewModel.scannedFood ?? food },
                        set: { viewModel.scannedFood = $0 }
                    ),
                    isNewFood: viewModel.scanState == .notFound,
                    networkError: viewModel.networkErrorOccurred,
                    onSave: {
                        viewModel.saveFood(context: modelContext)
                        viewModel.resetForNewScan()
                    },
                    onSaveAndLog: {
                        viewModel.saveAndLogFood(context: modelContext)
                        viewModel.resetForNewScan()
                    },
                    onDiscard: {
                        viewModel.resetForNewScan()
                    },
                    onRetryLookup: {
                        viewModel.retryLookup()
                    }
                )
            }
        }
    }

    private var showResultSheet: Binding<Bool> {
        Binding(
            get: { viewModel.scanState == .found || viewModel.scanState == .notFound },
            set: { if !$0 { viewModel.resetForNewScan() } }
        )
    }

    // MARK: - Camera View

    private var cameraView: some View {
        ZStack {
            CameraPreviewView(captureSession: viewModel.cameraService.captureSession)
                .ignoresSafeArea()

            ScanOverlayView(
                instruction: overlayInstruction,
                isScanning: viewModel.scanState == .scanning
            )

            // Top-right torch toggle
            VStack {
                HStack {
                    Spacer()
                    torchButton
                }
                .padding(.top, 8)
                .padding(.trailing, 16)
                Spacer()
            }

            if viewModel.isLookingUp {
                VStack {
                    Spacer()
                    lookupIndicator
                    Spacer().frame(height: 120)
                }
            }

            if viewModel.scanState == .error {
                VStack {
                    Spacer()
                    barcodeErrorOverlay
                    Spacer().frame(height: 120)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Barcode scanner camera view")
    }

    private var barcodeErrorOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.orange)
            Text(viewModel.errorMessage ?? "An error occurred")
                .font(.subheadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                viewModel.resetForNewScan()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var torchButton: some View {
        Button {
            viewModel.toggleTorch()
        } label: {
            Image(systemName: viewModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(viewModel.isTorchOn ? "Turn off flashlight" : "Turn on flashlight")
    }

    private var overlayInstruction: String {
        if viewModel.isLookingUp {
            return "Looking up barcode..."
        }
        if let barcode = viewModel.detectedBarcode {
            return "Found: \(barcode)"
        }
        return "Point camera at a barcode"
    }

    private var lookupIndicator: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text("Looking up \(viewModel.detectedBarcode ?? "barcode")...")
                .font(.subheadline)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Looking up barcode")
    }

    // MARK: - Permission Views

    private var requestPermissionView: some View {
        ContentUnavailableView {
            Label("Camera Access", systemImage: "camera")
        } description: {
            Text("FoodLogger needs camera access to scan barcodes.")
        } actions: {
            Button("Grant Access") {
                Task {
                    await viewModel.permissionManager.requestPermission()
                    if viewModel.permissionManager.isAuthorized {
                        viewModel.setupCamera()
                        viewModel.startScanning()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var permissionDeniedView: some View {
        ContentUnavailableView {
            Label("Camera Denied", systemImage: "camera.slash")
        } description: {
            Text("Camera access was denied. Please enable it in Settings to scan barcodes.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
