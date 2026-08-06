import SwiftUI

/// Circular avatar that loads a remote image, falling back to a person glyph.
struct AvatarView: View {
    let urlString: String?
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        ZStack { placeholder; ProgressView() }
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .id(urlString ?? "placeholder")   // reload AsyncImage when the URL changes
    }

    private var placeholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.tint)
    }
}
