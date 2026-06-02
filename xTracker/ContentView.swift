//
//  ContentView.swift
//  xTracker
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedTab = 0

    init() {
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarView()
                .tag(0)

            StatisticsView()
                .tag(1)

            SettingsView()
                .tag(2)
        }
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .bottom) {
            FloatingTabBar(selectedTab: $selectedTab)
                .offset(y: 12)
                .allowsHitTesting(true)
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selectedTab: Int

    @State private var touchStartIndex: Int = 0
    @State private var isTouching = false
    @State private var pillStretch: PillStretchState = .neutral
    @State private var pillStretchResetTask: Task<Void, Never>?

    private static let itemWidth: CGFloat = 72
    private static let itemSpacing: CGFloat = 4
    private static let tabCount = 3
    private static let containerPadding: CGFloat = 4
    private static let rowWidth =
        CGFloat(tabCount) * itemWidth + CGFloat(tabCount - 1) * itemSpacing
    private static let rowHeight: CGFloat = 48
    private static let barSize = CGSize(
        width: rowWidth + containerPadding * 2,
        height: rowHeight + containerPadding * 2
    )

    private let pressedScale: CGFloat = 1.08
    private let pressSpring = Animation.spring(response: 0.32, dampingFraction: 0.82)
    /// Ignore finger movement beyond this (pt²) so a small wobble still counts as a tap.
    private let tapCancelThresholdSquared: CGFloat = 36

    private var segmentWidth: CGFloat { Self.itemWidth + Self.itemSpacing }

    private var pillOffsetX: CGFloat {
        CGFloat(selectedTab) * segmentWidth
    }

    private var highlightedIndex: Int {
        isTouching ? touchStartIndex : selectedTab
    }

    var body: some View {
        ZStack {
            TabBarBlurCapsule(size: Self.barSize)
                .equatable()

            TabBarTrackView(
                pillOffsetX: pillOffsetX,
                highlightedIndex: highlightedIndex,
                pillStretch: pillStretch
            )
            .padding(Self.containerPadding)
        }
        .frame(width: Self.barSize.width, height: Self.barSize.height)
        .scaleEffect(isTouching ? pressedScale : 1)
        .animation(pressSpring, value: isTouching)
        .contentShape(Capsule())
        .gesture(tabBarTapGesture)
    }

    private func tabIndex(at locationX: CGFloat) -> Int {
        let adjustedX = locationX - Self.containerPadding
        guard adjustedX >= 0 else { return 0 }
        let index = Int(adjustedX / segmentWidth)
        return min(max(index, 0), Self.tabCount - 1)
    }

    private func exceedsTapCancelThreshold(_ translation: CGSize) -> Bool {
        let dx = translation.width
        let dy = translation.height
        return dx * dx + dy * dy > tapCancelThresholdSquared
    }

    private func beginPillStretch(from fromIndex: Int, to toIndex: Int) {
        guard fromIndex != toIndex else { return }

        let distance = abs(toIndex - fromIndex)
        let anchor: UnitPoint = toIndex > fromIndex ? .leading : .trailing
        pillStretch = PillStretchState(
            x: 1.02 + 0.04 * CGFloat(max(0, distance - 1)),
            y: 0.95,
            anchor: anchor
        )
    }

    private func resetPillStretch() {
        pillStretch = .neutral
    }

    private func schedulePillStretchReset() {
        pillStretchResetTask?.cancel()
        pillStretchResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(TabBarPillAnimation.stretchRelax) {
                resetPillStretch()
            }
        }
    }

    private func selectTab(at index: Int) {
        let fromIndex = selectedTab
        guard index != fromIndex else { return }

        var stretch = Transaction(animation: TabBarPillAnimation.stretchSnap)
        withTransaction(stretch) {
            beginPillStretch(from: fromIndex, to: index)
        }

        var move = Transaction(animation: TabBarPillAnimation.move)
        withTransaction(move) {
            selectedTab = index
        }

        schedulePillStretchReset()
    }

    private var tabBarTapGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard !isTouching else { return }

                withAnimation(TabBarPillAnimation.icon) {
                    isTouching = true
                    touchStartIndex = tabIndex(at: value.startLocation.x)
                }
            }
            .onEnded { value in
                withAnimation(TabBarPillAnimation.icon) {
                    isTouching = false
                }

                guard !exceedsTapCancelThreshold(value.translation) else { return }

                selectTab(at: tabIndex(at: value.startLocation.x))
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(EventStore())
        .environmentObject(AuthService())
        .environmentObject(UserService())
}
