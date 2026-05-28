//
//  SheetInlineHeader.swift
//  xTracker
//

import SwiftUI

private struct SheetInlineHeaderModifier<Trailing: View>: ViewModifier {
    let title: String
    @ViewBuilder let trailing: () -> Trailing
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
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
    func sheetInlineHeader(_ title: String) -> some View {
        modifier(SheetInlineHeaderModifier(title: title) {
            EmptyView()
        })
    }

    func sheetInlineHeader<Trailing: View>(
        _ title: String,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) -> some View {
        modifier(SheetInlineHeaderModifier(title: title, trailing: trailing))
    }
}
