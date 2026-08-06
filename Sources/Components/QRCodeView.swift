import SwiftUI
import CoreImage.CIFilterBuiltins

/// Renders a QR code for the given string using CoreImage.
struct QRCodeView: View {
    let string: String
    var size: CGFloat = 200

    var body: some View {
        if let image = Self.makeQR(from: string) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(.quaternary)
                .frame(width: size, height: size)
        }
    }

    static func makeQR(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
