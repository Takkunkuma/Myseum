import SwiftUI
import PhotosUI

/// Profile detail screen: change the avatar and username individually.
/// The picked photo shows immediately (optimistic) while it uploads, and any
/// upload error is surfaced rather than swallowed.
struct EditProfileView: View {
    @State private var auth = AuthService.shared
    @State private var photoItem: PhotosPickerItem?
    @State private var localAvatar: UIImage?
    @State private var isUploading = false
    @State private var showUsernameEditor = false
    @State private var usernameDraft = ""
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Group {
                        if let localAvatar {
                            Image(uiImage: localAvatar).resizable().scaledToFill()
                        } else {
                            AvatarView(urlString: auth.profile?.avatarURL, size: 100)
                        }
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        if isUploading {
                            ProgressView()
                        } else {
                            Text("Change photo")
                        }
                    }
                    .disabled(isUploading)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section {
                Button {
                    usernameDraft = auth.profile?.username ?? ""
                    showUsernameEditor = true
                } label: {
                    HStack {
                        Text("Username").foregroundStyle(.primary)
                        Spacer()
                        Text(auth.profile?.username ?? "—").foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                HStack {
                    Text("Email")
                    Spacer()
                    Text(auth.profile?.email ?? auth.session?.user.email ?? "—").foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Section { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Edit username", isPresented: $showUsernameEditor) {
            TextField("Username", text: $usernameDraft).textInputAutocapitalization(.never)
            Button("Save") { saveUsername() }
            Button("Cancel", role: .cancel) { }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            uploadAvatar(item)
        }
    }

    private func uploadAvatar(_ item: PhotosPickerItem) {
        errorMessage = nil
        isUploading = true
        Task {
            defer { isUploading = false; photoItem = nil }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Couldn't read that photo."
                return
            }
            localAvatar = image   // show it right away
            guard let jpeg = image.jpegData(compressionQuality: 0.8) else { return }
            do {
                try await auth.updateAvatar(jpeg: jpeg)
            } catch {
                errorMessage = "Photo upload failed: \(error.localizedDescription)"
            }
        }
    }

    private func saveUsername() {
        let name = usernameDraft
        Task { try? await auth.updateUsername(name) }
    }
}
