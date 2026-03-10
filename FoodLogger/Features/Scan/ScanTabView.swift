import SwiftUI

struct ScanTabView: View {
    @State private var scanMode: ScanMode = .barcode

    enum ScanMode: String, CaseIterable {
        case barcode = "Barcode"
        case nutritionLabel = "Nutrition Label"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Scan Mode", selection: $scanMode) {
                    ForEach(ScanMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch scanMode {
                case .barcode:
                    BarcodeScannerView()
                case .nutritionLabel:
                    NutritionLabelScanView()
                }
            }
            .navigationTitle("Scan")
        }
    }

}
