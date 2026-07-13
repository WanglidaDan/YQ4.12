import PhotosUI
import SwiftUI
import UIKit

struct StandardProfileView: View {
    @Environment(StudioStore.self) private var store
    @AppStorage("hasEnteredGuestMode") private var hasEnteredGuestMode = false
    @AppStorage("profileAvatarData") private var avatarData = Data()

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var confirmingSignOut = false

    private var profile: StudioProfile {
        store.resolvedStudioProfile
    }

    private var displayName: String {
        let name = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "影期" : name
    }

    private var accountLabel: String {
        store.isAuthenticated ? "已登录" : "本机模式"
    }

    var body: some View {
        NavigationStack {
            List {
                profileSection

                Section {
                    NavigationLink {
                        SettingsView(store: store, showsCloseButton: false)
                            .environment(store)
                    } label: {
                        Label("设置", systemImage: "gearshape")
                    }
                }

                Section {
                    Button("退出登录", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        confirmingSignOut = true
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog("确认退出登录？", isPresented: $confirmingSignOut) {
                Button("退出登录", role: .destructive, action: signOut)
                Button("取消", role: .cancel) {}
            }
            .onChange(of: selectedPhoto) {
                loadSelectedAvatar()
            }
        }
    }

    private var profileSection: some View {
        Section {
            HStack(spacing: 16) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    avatar
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(AppTheme.accent, in: Circle())
                                .overlay { Circle().stroke(AppTheme.background, lineWidth: 2) }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("更换头像")

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.ink)
                    Text(accountLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let image = UIImage(data: avatarData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(AppTheme.accent, AppTheme.panelStrong)
        }
    }

    private func loadSelectedAvatar() {
        guard let selectedPhoto else { return }
        Task {
            guard let data = try? await selectedPhoto.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let compressedData = resizedAvatarData(from: image) else {
                return
            }
            await MainActor.run {
                avatarData = compressedData
                AppHaptics.success()
            }
        }
    }

    private func resizedAvatarData(from image: UIImage) -> Data? {
        let side = min(image.size.width, image.size.height)
        guard side > 0 else { return nil }

        let cropOrigin = CGPoint(
            x: (image.size.width - side) / 2,
            y: (image.size.height - side) / 2
        )
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512), format: format)
        let resizedImage = renderer.image { _ in
            image.draw(
                in: CGRect(
                    x: -cropOrigin.x * 512 / side,
                    y: -cropOrigin.y * 512 / side,
                    width: image.size.width * 512 / side,
                    height: image.size.height * 512 / side
                )
            )
        }
        return resizedImage.jpegData(compressionQuality: 0.82)
    }

    private func signOut() {
        store.clearAuthProfile()
        hasEnteredGuestMode = false
        AppHaptics.success()
    }
}
