//
//  EventFormComponents.swift
//  xTracker
//

import SwiftUI

enum EventFormStyle {
    static let unselectedLabel = Color(hex: "#C0C0C0")
    static let selectedLabel = AppTheme.primaryText
    static let selectedTintBackground = AppTheme.accent.opacity(0.12)
    static let selectedBorderColor = AppTheme.accent.opacity(0.55)
    static let selectedChipFill = AppTheme.accent
    static let selectedCheckboxFill = AppTheme.accent
    static let selectedCheckboxCheckmark = AppTheme.primaryText
    static let uncheckedCheckboxBorder = Color.white.opacity(0.06)
    static let surfaceBackground = Color.white.opacity(0.08)

    static var unselectedSurface: some View {
        RoundedRectangle(cornerRadius: AppTheme.compactCardCornerRadius, style: .continuous)
            .fill(surfaceBackground)
    }
}

struct EventFormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppTheme.sectionHeader(title)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EventFormCheckbox: View {
    let isOn: Bool

    @State private var trimProgress: CGFloat = 0
    @State private var checkmarkOpacity: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(EventFormStyle.uncheckedCheckboxBorder, lineWidth: 1.5)
                .opacity(isOn ? 0 : 1)
                .animation(.spring(response: 0.38, dampingFraction: 0.62), value: isOn)

            Circle()
                .fill(EventFormStyle.selectedCheckboxFill)
                .scaleEffect(isOn ? 1 : 0.6)
                .opacity(isOn ? 1 : 0)
                .animation(.spring(response: 0.38, dampingFraction: 0.62), value: isOn)

            CheckmarkDrawShape()
                .trim(from: 0, to: trimProgress)
                .stroke(
                    EventFormStyle.selectedCheckboxCheckmark,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 11, height: 11)
                .opacity(checkmarkOpacity)
        }
        .frame(width: 22, height: 22)
        .onAppear {
            syncCheckmarkState()
        }
        .onChange(of: isOn) { newValue in
            if newValue {
                animateCheckmarkIn()
            } else {
                animateCheckmarkOut()
            }
        }
    }

    private func syncCheckmarkState() {
        if isOn {
            checkmarkOpacity = 1
            trimProgress = 1
        } else {
            checkmarkOpacity = 0
            trimProgress = 0
        }
    }

    private func animateCheckmarkIn() {
        checkmarkOpacity = 1
        trimProgress = 0
        withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) {
            trimProgress = 1
        }
    }

    private func animateCheckmarkOut() {
        withAnimation(.easeOut(duration: 0.12)) {
            checkmarkOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            trimProgress = 0
        }
    }
}

struct CheckmarkDrawShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.midY + rect.height * 0.02))
        path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.02, y: rect.maxY - rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.minY + rect.height * 0.22))
        return path
    }
}
