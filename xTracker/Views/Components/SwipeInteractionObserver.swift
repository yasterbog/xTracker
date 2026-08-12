//
//  SwipeInteractionObserver.swift
//  xTracker
//

import SwiftUI
import UIKit

enum SwipeRevealMetrics {
    static let trashVisibleOffset: CGFloat = 28
}

struct SwipeInteractionObserver: UIViewRepresentable {
    @Binding var isSwiping: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isSwiping: $isSwiping)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        context.coordinator.hostView = view
        context.coordinator.startObservingIfNeeded()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.isSwiping = $isSwiping
        context.coordinator.hostView = uiView
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    final class Coordinator {
        var isSwiping: Binding<Bool>
        weak var hostView: UIView?
        private var displayLink: CADisplayLink?

        init(isSwiping: Binding<Bool>) {
            self.isSwiping = isSwiping
        }

        func startObservingIfNeeded() {
            guard displayLink == nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func stopObserving() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func tick() {
            guard let hostView else { return }

            let trashVisible = Self.isTrashVisible(hostView: hostView)
            guard trashVisible != isSwiping.wrappedValue else { return }
            isSwiping.wrappedValue = trashVisible
        }

        private static func isTrashVisible(hostView: UIView) -> Bool {
            swipeOffset(from: hostView) < -SwipeRevealMetrics.trashVisibleOffset
        }

        private static func swipeOffset(from view: UIView) -> CGFloat {
            var minOffset: CGFloat = 0
            var current: UIView? = view

            while let currentView = current {
                minOffset = min(minOffset, horizontalOffset(of: currentView))
                if currentView is UITableViewCell || currentView is UICollectionViewCell {
                    break
                }
                current = currentView.superview
            }

            return minOffset
        }

        private static func horizontalOffset(of view: UIView) -> CGFloat {
            if view.transform.tx != 0 {
                return view.transform.tx
            }
            return view.frame.minX
        }
    }
}
