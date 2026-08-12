//
//  PartnerConnectSheet.swift
//  xTracker
//

import SwiftUI

struct PartnerConnectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    @Binding var partnerCodeInput: String
    let onConnect: () async -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Введите код партнёра, чтобы подключить общий календарь.")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.secondaryText)

                FloatingLabelTextField(
                    label: "Код партнёра",
                    text: $partnerCodeInput,
                    textInputAutocapitalization: .characters
                )
                .onChange(of: partnerCodeInput) { newValue in
                    let uppercased = newValue.uppercased()
                    if uppercased != newValue {
                        partnerCodeInput = uppercased
                    }
                }

                if let errorMessage = authService.connectionError {
                    Text(errorMessage)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(.red)
                }

                PrimaryActionButton(
                    title: "Подключить",
                    isEnabled: !partnerCodeInput.trimmingCharacters(in: .whitespaces).isEmpty,
                    isLoading: authService.isConnecting
                ) {
                    Task { await connect() }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.background)
            .sheetInlineHeader("Подключить партнёра")
        }
        .preferredColorScheme(.dark)
    }

    private func connect() async {
        await onConnect()
        if authService.connectionError == nil {
            dismiss()
        }
    }
}

#Preview {
    PartnerConnectSheet(partnerCodeInput: .constant(""), onConnect: {})
        .environmentObject(AuthService())
}
