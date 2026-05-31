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

    static var filterFont: Font {
        .system(size: fontSize, weight: .regular, design: .default)
    }

    static var pickerFont: Font {
        .system(size: fontSize, weight: .medium, design: .default)
    }

    static var chipHeight: CGFloat {
        UIFont.systemFont(ofSize: fontSize, weight: .regular).lineHeight + verticalPadding * 2
    }
}

// MARK: - Filter Chip

struct FilterChip<Label: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                action()
            }
        } label: {
            label()
                .padding(.horizontal, ChipMetrics.horizontalPadding)
                .padding(.vertical, ChipMetrics.verticalPadding)
                .background(
                    Capsule()
                        .fill(isSelected ? EventFormStyle.selectedChipFill : EventFormStyle.surfaceBackground)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isSelected)
    }
}

extension FilterChip where Label == Text {
    init(title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.isSelected = isSelected
        self.action = action
        self.label = {
            Text(title)
                .font(ChipMetrics.filterFont)
                .foregroundColor(isSelected ? EventFormStyle.selectedLabel : EventFormStyle.unselectedLabel)
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
                .font(ChipMetrics.pickerFont)
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
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
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
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.primaryText)
                .frame(width: ChipMetrics.chipHeight, height: ChipMetrics.chipHeight)
                .background(EventFormStyle.surfaceBackground)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
