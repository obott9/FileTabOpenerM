// FlowLayout.swift
// FileTabOpenerM
//
// タブボタンの折り返しレイアウト
// ContentView.swift から分離

import SwiftUI

// MARK: - FlowLayout (タブボタンの折り返しレイアウト)

struct FlowLayout: Layout {
    var spacing: CGFloat = 2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            height += row.height
            if i > 0 { height += spacing }
        }
        return CGSize(width: proposal.width ?? 0, height: max(height, 28))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for (i, row) in rows.enumerated() {
            if i > 0 { y += spacing }
            var x = bounds.minX
            for subview in row.subviews {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height
        }
    }

    private struct Row {
        var subviews: [LayoutSubviews.Element]
        var height: CGFloat
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow: [LayoutSubviews.Element] = []
        var usedWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needed = currentRow.isEmpty ? size.width : size.width + spacing
            if !currentRow.isEmpty && usedWidth + needed > maxWidth {
                rows.append(Row(subviews: currentRow, height: rowHeight))
                currentRow = []
                usedWidth = 0
                rowHeight = 0
            }
            currentRow.append(subview)
            usedWidth += needed
            rowHeight = max(rowHeight, size.height)
        }
        if !currentRow.isEmpty {
            rows.append(Row(subviews: currentRow, height: rowHeight))
        }
        return rows
    }
}
