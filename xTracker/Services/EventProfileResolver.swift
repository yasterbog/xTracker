//
//  EventProfileResolver.swift
//  xTracker
//

import Foundation

enum EventProfileResolver {
    static func creatorProfile(
        for event: Event,
        currentUserID: String,
        currentPartnerID: String,
        ownName: String,
        ownAvatarBase64: String?,
        ownAvatarURL: String?,
        partnerName: String,
        partnerAvatarBase64: String?,
        partnerAvatarURL: String?
    ) -> UserAvatarProfile {
        if event.createdBy == currentUserID || (event.createdBy.isEmpty && currentUserID.isEmpty) {
            return UserAvatarProfile(
                userID: currentUserID,
                name: ownName.isEmpty ? SettingsStore.defaultUserName : ownName,
                avatarBase64: ownAvatarBase64,
                avatarURL: ownAvatarURL
            )
        }

        if event.createdBy == currentPartnerID, !currentPartnerID.isEmpty {
            return UserAvatarProfile(
                userID: currentPartnerID,
                name: partnerName.isEmpty ? "Партнёр" : partnerName,
                avatarBase64: partnerAvatarBase64,
                avatarURL: partnerAvatarURL
            )
        }

        return UserAvatarProfile(userID: event.createdBy, name: "Участник", avatarBase64: nil, avatarURL: nil)
    }
}
