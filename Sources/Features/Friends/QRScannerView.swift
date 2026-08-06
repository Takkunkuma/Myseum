import SwiftUI
import VisionKit

/// Camera QR scanner (VisionKit DataScanner). Works on a physical device only —
/// the Simulator has no camera, so it shows an unavailable state there.
struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (URL) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    DataScannerRepresentable { url in
                        onScan(url)
                        dismiss()
                    }
                    .ignoresSafeArea()
                } else {
                    ContentUnavailableView(
                        "Camera unavailable",
                        systemImage: "camera.fill",
                        description: Text("QR scanning needs a real device with a camera. On the Simulator, use an invite link instead.")
                    )
                }
            }
            .navigationTitle("Scan QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onURL: (URL) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        try? scanner.startScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onURL: onURL) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onURL: (URL) -> Void
        private var handled = false

        init(onURL: @escaping (URL) -> Void) { self.onURL = onURL }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            handle(addedItems)
        }

        private func handle(_ items: [RecognizedItem]) {
            guard !handled else { return }
            for item in items {
                if case let .barcode(barcode) = item,
                   let string = barcode.payloadStringValue,
                   let url = URL(string: string),
                   InviteLink.userID(from: url) != nil {
                    handled = true
                    onURL(url)
                    return
                }
            }
        }
    }
}
