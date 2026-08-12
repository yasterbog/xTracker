//
//  SettingsComponents.swift
//  xTracker
//

import PhotosUI
import SwiftUI
import UIKit

enum SettingsDestination: Hashable {
    case pair
    case activities
}

struct SettingsMenuGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(AppTheme.subtleSurfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

struct SettingsMenuRow: View {
    let iconAsset: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(iconAsset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(AppTheme.appWhite)

            Text(title)
                .font(AppFont.font(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
    }
}

struct SettingsMenuDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.appWhite.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 56)
    }
}

struct SettingsStatsCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                AppTheme.sectionTitle(title)
            }
            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.subtleSurfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

struct PairConnectionDiagram: View {
    let isPartnerConnected: Bool
    let ownAvatarImage: UIImage?
    let ownAvatarBase64: String?
    let ownAvatarURL: String?
    let ownName: String
    let partnerAvatarBase64: String?
    let partnerAvatarURL: String?
    let partnerName: String
    let onAddPartnerTap: () -> Void

    private static let avatarSize: CGFloat = 52

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if let ownAvatarImage {
                    SettingsAvatarView(
                        image: ownAvatarImage,
                        initials: SettingsStore.initials(from: ownName),
                        size: Self.avatarSize
                    )
                } else {
                    UserAvatarView(
                        avatarBase64: ownAvatarBase64,
                        avatarURL: ownAvatarURL,
                        name: ownName,
                        size: Self.avatarSize
                    )
                }
            }

            PairConnectorLine(color: AppTheme.accent)

            if isPartnerConnected {
                PairEmblemCircle {
                    Image("heart_fill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(AppTheme.accent)
                }

                PairConnectorLine(color: AppTheme.accent)

                UserAvatarView(
                    avatarBase64: partnerAvatarBase64,
                    avatarURL: partnerAvatarURL,
                    name: partnerName,
                    size: Self.avatarSize
                )
            } else {
                PairEmblemCircle {
                    Text("🔗")
                        .font(.system(size: 12))
                }

                PairConnectorLine(color: AppTheme.secondaryText.opacity(0.5))

                Button(action: onAddPartnerTap) {
                    ZStack {
                        Circle()
                            .stroke(
                                AppTheme.secondaryText.opacity(0.5),
                                style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                            )
                            .frame(width: Self.avatarSize, height: Self.avatarSize)

                        Image(systemName: "plus")
                            .font(AppFont.font(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct PairConnectorLine: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 24, height: 2)
    }
}

private let pairEmblemCircleSize: CGFloat = 28

struct PairEmblemCircle<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.accent.opacity(0.12))
            Circle()
                .stroke(AppTheme.accent, lineWidth: 1.5)
            content()
        }
        .frame(width: pairEmblemCircleSize, height: pairEmblemCircleSize)
    }
}

struct EditableAvatarView: View {
    let image: UIImage?
    let avatarBase64: String?
    let avatarURL: String?
    let name: String
    let size: CGFloat
    let isLoading: Bool
    var showsCameraOverlay = true

    private var cameraBadgeSize: CGFloat { size * 28 / 88 }
    private var cameraIconSize: CGFloat { size * 13 / 88 }
    private var cameraOffset: CGFloat { size * 2 / 88 }
    private var outerPadding: CGFloat { size * 8 / 88 }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                if let image {
                    SettingsAvatarView(image: image, initials: SettingsStore.initials(from: name), size: size)
                } else {
                    UserAvatarView(
                        avatarBase64: avatarBase64,
                        avatarURL: avatarURL,
                        name: name,
                        size: size
                    )
                }

                if isLoading {
                    Circle()
                        .fill(Color.black.opacity(0.45))
                        .frame(width: size, height: size)
                    ProgressView()
                        .tint(AppTheme.primaryText)
                }
            }

            if showsCameraOverlay {
                ZStack {
                    Circle()
                        .fill(AppTheme.appWhite)
                        .frame(width: cameraBadgeSize, height: cameraBadgeSize)
                        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)

                    Image(systemName: "camera.fill")
                        .font(AppFont.font(size: cameraIconSize, weight: .semibold))
                        .foregroundStyle(Color.black)
                }
                .offset(x: cameraOffset, y: cameraOffset)
            }
        }
        .frame(
            width: showsCameraOverlay ? size + outerPadding : size,
            height: showsCameraOverlay ? size + outerPadding : size
        )
    }
}

struct SettingsAvatarView: View {
    let image: UIImage?
    let initials: String
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            if image == nil {
                AppTheme.accent
            }

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(initials)
                    .font(AppFont.font(size: size * 0.32, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(AppTheme.appWhite.opacity(0.15), lineWidth: 1)
        )
    }
}
