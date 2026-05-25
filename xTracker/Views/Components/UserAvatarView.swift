//
//  UserAvatarView.swift
//  xTracker
//

import Foundation
import SwiftUI
import UIKit

struct UserAvatarView: View {
    let avatarBase64: String?
    let avatarURL: String?
    let name: String
    var size: CGFloat = 28

    init(
        avatarBase64: String? = nil,
        avatarURL: String? = nil,
        name: String,
        size: CGFloat = 28
    ) {
        self.avatarBase64 = avatarBase64
        self.avatarURL = avatarURL
        self.name = name
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.accent)

            avatarContent
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let image = decodedBase64Image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let avatarURL, let url = URL(string: avatarURL) {
            ReloadingAsyncAvatar(url: url, fallback: initialsText)
        } else {
            initialsText
        }
    }

    private var initialsText: some View {
        Text(firstLetter)
            .font(.system(size: size * 0.34, weight: .bold, design: .default))
            .foregroundStyle(AppTheme.primaryText)
    }

    private var firstLetter: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmedName.first else { return "?" }
        return String(first).uppercased()
    }

    private var decodedBase64Image: UIImage? {
        guard let avatarBase64,
              let data = Data(base64Encoded: avatarBase64)
        else {
            return nil
        }
        return UIImage(data: data)
    }
}

private struct ReloadingAsyncAvatar<Fallback: View>: View {
    let url: URL
    let fallback: Fallback

    @State private var image: Image?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppTheme.primaryText)
            } else {
                fallback
            }
        }
        .task(id: url.absoluteString) {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let uiImage = UIImage(data: data) {
                image = Image(uiImage: uiImage)
            } else {
                image = nil
            }
        } catch {
            image = nil
        }

        isLoading = false
    }
}
