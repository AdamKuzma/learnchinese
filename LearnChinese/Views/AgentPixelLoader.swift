import SwiftUI

/// A 3×3 pixel grid in the style of Cursor's agent-running indicator.
struct AgentPixelLoader: View {
    enum Pattern: CaseIterable {
        case columnFall
        case snake
        case spiral
        case rain
        case orbit
        case diagonal
    }

    var pattern: Pattern
    var accessibilityLabel: String = "Creating your mission"

    private let pixelSize: CGFloat = 8
    private let spacing: CGFloat = 5
    private let frameInterval: TimeInterval = 0.12

    var body: some View {
        TimelineView(.periodic(from: .now, by: frameInterval)) { timeline in
            let frame = Int(timeline.date.timeIntervalSinceReferenceDate / frameInterval)
            let cells = pattern.cells(at: frame)

            VStack(spacing: spacing) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<3, id: \.self) { column in
                            RoundedRectangle(cornerRadius: 1, style: .continuous)
                                .fill(Color.appForeground)
                                .frame(width: pixelSize, height: pixelSize)
                                .opacity(cells[row * 3 + column])
                        }
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }
}

private extension AgentPixelLoader.Pattern {
    func cells(at frame: Int) -> [Double] {
        switch self {
        case .columnFall:
            return columnFall(frame)
        case .snake:
            return trail(path: snakePath, frame: frame, length: 3)
        case .spiral:
            return trail(path: spiralPath, frame: frame, length: 3)
        case .rain:
            return rain(frame)
        case .orbit:
            return trail(path: orbitPath, frame: frame, length: 2)
        case .diagonal:
            return diagonal(frame)
        }
    }

    /// Cursor's signature motion: a two-dot window that climbs and drops in
    /// each column, with the three columns staggered by a third of a cycle.
    func columnFall(_ frame: Int) -> [Double] {
        let cycle = 6
        var cells = Array(repeating: 0.12, count: 9)
        for column in 0..<3 {
            let step = pos(frame - column * 2, cycle: cycle)
            let rows: [Int]
            switch step {
            case 0, 5: rows = [1, 2]
            case 1: rows = [0, 1]
            default: rows = [0, 1]
            }
            for (index, row) in rows.enumerated() {
                cells[row * 3 + column] = index == 0 ? 1 : 0.7
            }
        }
        return cells
    }

    func rain(_ frame: Int) -> [Double] {
        var cells = Array(repeating: 0.12, count: 9)
        let offsets = [0, 2, 4]
        for column in 0..<3 {
            let step = pos(frame - offsets[column], cycle: 5)
            let rows: [Int]
            switch step {
            case 0: rows = [0]
            case 1: rows = [0, 1]
            case 2: rows = [1, 2]
            case 3: rows = [2]
            default: rows = []
            }
            for (index, row) in rows.enumerated() {
                cells[row * 3 + column] = index == rows.count - 1 ? 1 : 0.4
            }
        }
        return cells
    }

    func diagonal(_ frame: Int) -> [Double] {
        let bands: [[Int]] = [
            [0],
            [1, 3],
            [2, 4, 6],
            [5, 7],
            [8],
            [5, 7],
            [2, 4, 6],
            [1, 3]
        ]
        let current = pos(frame, cycle: bands.count)
        var cells = Array(repeating: 0.12, count: 9)
        for (offset, band) in [-1, 0, 1].enumerated() {
            let index = pos(current + band, cycle: bands.count)
            let brightness = [0.35, 1, 0.35][offset]
            for cell in bands[index] {
                cells[cell] = max(cells[cell], brightness)
            }
        }
        return cells
    }

    func trail(path: [Int], frame: Int, length: Int) -> [Double] {
        var cells = Array(repeating: 0.12, count: 9)
        let head = pos(frame, cycle: path.count)
        for offset in 0..<length {
            let index = pos(head - offset, cycle: path.count)
            let brightness = 1.0 - Double(offset) * 0.32
            cells[path[index]] = max(cells[path[index]], brightness)
        }
        return cells
    }

    func pos(_ value: Int, cycle: Int) -> Int {
        let remainder = value % cycle
        return remainder >= 0 ? remainder : remainder + cycle
    }

    var snakePath: [Int] { [0, 1, 2, 5, 4, 3, 6, 7, 8, 5, 4, 1] }
    var spiralPath: [Int] { [0, 1, 2, 5, 8, 7, 6, 3, 4] }
    var orbitPath: [Int] { [0, 1, 2, 5, 8, 7, 6, 3] }
}
