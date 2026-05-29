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
            VStack(alignment: .leading, spacing: 24) {
                Text("Введите код партнёра, чтобы подключить общий календарь.")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.secondaryText)

                TextField("Код партнёра", text: $partnerCodeInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.primaryText)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.subtleSurfaceBackground)
                    )

                if let errorMessage = authService.connectionError {
                    Text(errorMessage)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await connect() }
                } label: {
                    Group {
                        if authService.isConnecting {
                            ProgressView()
                                .tint(AppTheme.primaryText)
                        } else {
                            Text("Подключить")
                                .font(.system(size: 16, weight: .semibold, design: .default))
                        }
                    }
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.accent)
                    )
                }
                .buttonStyle(.plain)
                .disabled(authService.isConnecting || partnerCodeInput.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.background)
            .navigationTitle("Подключить партнёра")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.secondaryText)
                    .disabled(authService.isConnecting)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
