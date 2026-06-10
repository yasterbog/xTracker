//
//  ChipComponents.swift
//  xTracker
//

import SwiftUI
import UIKit

enum ChipMetrics {
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 8
    static let fontSize: CGFloat = 14

    static var chipTitle: Font {
        AppFont.font(size: fontSize, weight: .semibold)
    }

    static var chipButtonTitle: Font {
        AppFont.font(size: fontSize, weight: .semibold)
    }

    static var chipHeight: CGFloat {
        AppFont.uiFont(size: fontSize, weight: .semibold).lineHeight + verticalPadding * 2
    }
}

// MARK: - Filter Chip

enum FilterChipVariant {
    case primary
    case secondary
}

struct FilterChip<Label: View>: View {
    let variant: FilterChipVariant
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    init(
        variant: FilterChipVariant = .primary,
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.variant = variant
        self.isSelected = isSelected
        self.action = action
        self.label = label
    }

    private var fillColor: Color {
        switch variant {
        case .primary:
            return isSelected ? EventFormStyle.selectedChipFill : EventFormStyle.surfaceBackground
        case .secondary:
            return isSelected ? AppTheme.accent : EventFormStyle.surfaceBackground
        }
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            label()
                .padding(.horizontal, ChipMetrics.horizontalPadding)
                .padding(.vertical, ChipMetrics.verticalPadding)
        }
        .background(
            Capsule()
                .fill(fillColor)
        )
        .contentShape(Capsule())
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isSelected)
    }
}

extension FilterChip where Label == Text {
    init(
        chipTitle: String,
        variant: FilterChipVariant = .primary,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.variant = variant
        self.isSelected = isSelected
        self.action = action
        self.label = {
            Text(chipTitle)
                .font(ChipMetrics.chipTitle)
                .foregroundColor(
                    isSelected
                        ? (variant == .primary ? AppTheme.background : AppTheme.primaryText)
                        : EventFormStyle.unselectedLabel
                )
        }
    }
}

// MARK: - Picker Chip

struct PickerChip: View {
    @Binding var date: Date
    let mode: UIDatePicker.Mode
    let chipTitle: String
    @Binding var isExpanded: Bool
    var minimumDate: Date?
    var maximumDate: Date?

    private var valueColor: Color {
        isExpanded ? AppTheme.accent : AppTheme.primaryText
    }

    var body: some View {
        ZStack {
            Text(chipTitle)
                .font(ChipMetrics.chipTitle)
                .foregroundColor(valueColor)
                .padding(.horizontal, ChipMetrics.horizontalPadding)
                .padding(.vertical, ChipMetrics.verticalPadding)
                .background(
                    Capsule()
                        .fill(EventFormStyle.surfaceBackground)
                )
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.15), value: isExpanded)

            CompactDatePickerBridge(
                date: $date,
                isExpanded: $isExpanded,
                mode: mode,
                minimumDate: minimumDate,
                maximumDate: maximumDate
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .fixedSize()
        .contentShape(Capsule())
    }
}

struct CompactDatePickerBridge: UIViewRepresentable {
    @Binding var date: Date
    @Binding var isExpanded: Bool
    let mode: UIDatePicker.Mode
    var minimumDate: Date?
    var maximumDate: Date?

    func makeCoordinator() -> Coordinator {
        Coordinator(date: $date, isExpanded: $isExpanded)
    }

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.preferredDatePickerStyle = .compact
        picker.datePickerMode = mode
        picker.locale = Locale(identifier: "ru_RU")
        picker.minimumDate = minimumDate
        picker.maximumDate = maximumDate
        picker.tintColor = UIColor(AppTheme.accent)
        picker.date = date
        picker.alpha = 0.011
        picker.addTarget(context.coordinator, action: #selector(Coordinator.dateChanged(_:)), for: .valueChanged)
        picker.addTarget(context.coordinator, action: #selector(Coordinator.editingBegan), for: .editingDidBegin)
        picker.addTarget(context.coordinator, action: #selector(Coordinator.editingEnded), for: .editingDidEnd)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        if !context.coordinator.isExpanded {
            picker.date = date
        }
        picker.minimumDate = minimumDate
        picker.maximumDate = maximumDate
    }

    final class Coordinator: NSObject {
        @Binding var date: Date
        @Binding var isExpanded: Bool

        init(date: Binding<Date>, isExpanded: Binding<Bool>) {
            _date = date
            _isExpanded = isExpanded
        }

        @objc func dateChanged(_ sender: UIDatePicker) {
            date = sender.date
        }

        @objc func editingBegan() {
            isExpanded = true
        }

        @objc func editingEnded() {
            isExpanded = false
        }
    }
}

// MARK: - Chip Button

struct ChipButton: View {
    var icon: String?
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: icon == nil ? 0 : 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(AppFont.font(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(ChipMetrics.chipButtonTitle)
            }
            .foregroundColor(.white)
            .padding(.horizontal, ChipMetrics.horizontalPadding)
            .padding(.vertical, ChipMetrics.verticalPadding)
            .background(AppTheme.subtleSurfaceBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ChipCircleButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(AppFont.font(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.primaryText)
                .frame(width: ChipMetrics.chipHeight, height: ChipMetrics.chipHeight)
                .background(EventFormStyle.surfaceBackground)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
