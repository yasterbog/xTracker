//
//  SheetInlineHeader.swift
//  xTracker
//

import SwiftUI

private struct SheetInlineHeaderModifier<Trailing: View>: ViewModifier {
    let title: String
    let onClose: (() -> Void)?
    @ViewBuilder let trailing: () -> Trailing
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if let onClose {
                            onClose()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundColor(.gray)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    trailing()
                }
            }
    }
}

extension View {
    func sheetInlineHeader(_ title: String, onClose: (() -> Void)? = nil) -> some View {
        modifier(SheetInlineHeaderModifier(title: title, onClose: onClose) {
            EmptyView()
        })
    }

    func sheetInlineHeader<Trailing: View>(
        _ title: String,
        onClose: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) -> some View {
        modifier(SheetInlineHeaderModifier(title: title, onClose: onClose, trailing: trailing))
    }
}
