import SwiftUI
import SwiftData
import PhotosUI

struct NutritionLabelScanView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = NutritionLabelScanViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showResult = false

    var body: some View {
        ZStack {
            if viewModel.permissionManager.isAuthorized {
                cameraContent
            } else if viewModel.permissionManager.isDenied {
                permissionDeniedView
            } else {
                requestPermissionView
            }
        }
        .task {
            if viewModel.permissionManager.authorizationStatus == .notDetermined {
                await viewModel.permissionManager.requestPermission()
            }
            if viewModel.permissionManager.isAuthorized {
                viewModel.setupCamera()
                viewModel.startSession()
            }
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .onChange(of: selectedPhoto) {
            if let selectedPhoto {
                Task {
                    if let data = try? await selectedPhoto.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await viewModel.processPickedImage(image)
                    }
                }
                self.selectedPhoto = nil
            }
        }
        .sheet(isPresented: $showResult) {
            if let nutrition = viewModel.parsedNutrition {
                OCRResultView(
                    nutrition: nutrition,
                    capturedImage: viewModel.capturedImage,
                    onSave: { name, brand, cal, pro, carb, fat, fib in
                        viewModel.saveFoodItem(name: name, brand: brand, calories: cal, protein: pro, carbs: carb, fat: fat, fiber: fib, context: modelContext)
                        viewModel.resetForNewScan()
                    },
                    onSaveAndLog: { name, brand, cal, pro, carb, fat, fib in
                        viewModel.saveAndLogFoodItem(name: name, brand: brand, calories: cal, protein: pro, carbs: carb, fat: fat, fiber: fib, context: modelContext)
                        viewModel.resetForNewScan()
                    },
                    onRetake: {
                        viewModel.resetForNewScan()
                    }
                )
            }
        }
        .onChange(of: viewModel.scanState) {
            showResult = viewModel.scanState == .result
        }
    }

    // MARK: - Camera Content

    private var cameraContent: some View {
        ZStack {
            CameraPreviewView(captureSession: viewModel.cameraService.captureSession)
                .ignoresSafeArea()

            VStack {
                Spacer()

                if viewModel.scanState == .processing {
                    processingOverlay
                } else if viewModel.scanState == .error {
                    errorOverlay
                }

                Spacer()

                // Bottom controls
                bottomControls
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Nutrition label scanner camera view")
    }

    private var bottomControls: some View {
        HStack(spacing: 40) {
            // Photo picker
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Choose photo from library")

            // Capture button
            Button {
                Task { await viewModel.captureAndProcess() }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 70, height: 70)
                    Circle()
                        .stroke(.white, lineWidth: 3)
                        .frame(width: 80, height: 80)
                }
            }
            .disabled(viewModel.scanState == .capturing || viewModel.scanState == .processing)
            .accessibilityLabel("Capture nutrition label photo")
            .accessibilityHint("Takes a photo to scan for nutrition information")

            // Placeholder for symmetry
            Color.clear
                .frame(width: 50, height: 50)
                .accessibilityHidden(true)
        }
        .padding(.bottom, 40)
    }

    private var processingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
            Text("Reading nutrition label...")
                .font(.subheadline)
                .foregroundStyle(.white)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Processing nutrition label")
    }

    private var errorOverlay: some View {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(viewModel.errorMessage ?? "An error occurred"). Double tap to try again.")
    }

    // MARK: - Permission Views

    private var requestPermissionView: some View {
        ContentUnavailableView {
            Label("Camera Access", systemImage: "camera")
        } description: {
            Text("FoodLogger needs camera access to scan nutrition labels.")
        } actions: {
            Button("Grant Access") {
                Task {
                    await viewModel.permissionManager.requestPermission()
                    if viewModel.permissionManager.isAuthorized {
                        viewModel.setupCamera()
                        viewModel.startSession()
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
            Text("Camera access was denied. Enable it in Settings to scan labels.")
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
