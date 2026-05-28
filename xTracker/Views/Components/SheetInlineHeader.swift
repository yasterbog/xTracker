//
//  SheetInlineHeader.swift
//  xTracker
//

import SwiftUI

private struct SheetInlineHeaderModifier: ViewModifier {
    let title: String
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundColor(.gray)
                }
            }
    }
}

extension View {
    func sheetInlineHeader(_ title: String) -> some View {
        modifier(SheetInlineHeaderModifier(title: title))
    }
}
