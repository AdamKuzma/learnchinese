//
//  ProfileView.swift
//  LearnChinese
//

import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var profileImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showPhotoPicker = false

    init(profileImage: UIImage? = nil) {
        _profileImage = State(initialValue: profileImage)
    }

    private var dayCounts: [DayCount] {
        ActivityHistory.countsFromFirstActivity()
    }

    private var totalActivities: Int {
        SharedStore.activityEvents.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 56) {
                    identitySection
                    activitiesSection
                    VStack(alignment: .leading, spacing: 28) {
                        streakSection
                        monthGridSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .appScreenBackground()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $pickerItem, matching: .images)
            .onAppear {
                if profileImage == nil, let data = SharedStore.profilePhotoData {
                    profileImage = UIImage(data: data)
                }
            }
            .onChange(of: pickerItem) { _, item in
                Task { await loadPhoto(item) }
            }
        }
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                showPhotoPicker = true
            } label: {
                ProfileAvatarImage(image: profileImage, size: 96)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(profileImage == nil ? "Add profile photo" : "Change profile photo")

            VStack(alignment: .leading, spacing: 4) {
                Text("Adam Kuzma")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Color.appForeground)
                Text(verbatim: "adam@esecure.cc")
                    .font(.subheadline)
                    .foregroundStyle(Color.appMutedText)
                    .tint(Color.appMutedText)
                    .allowsHitTesting(false)
                    .environment(\.openURL, OpenURLAction { _ in .discarded })
            }

            Rectangle()
                .fill(Color.appSecondaryBorder)
                .frame(height: 0.5)
        }
    }

    @MainActor
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }

        let prepared = resizedPhoto(image)
        profileImage = prepared
        SharedStore.profilePhotoData = prepared.jpegData(compressionQuality: 0.85)
    }

    private func resizedPhoto(_ image: UIImage, maxDimension: CGFloat = 800) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }

        let scale = maxDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Activities")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(totalActivities)")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Color.appForeground)
            }

            ActivityBarChart(days: dayCounts)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
        }
    }

    private var streakSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Streak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(ActivityHistory.currentStreak())d")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.appForeground)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("Longest")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(ActivityHistory.longestStreak())d")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.appForeground)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var monthGridSection: some View {
        YearContributionGrid(
            completedDays: ActivityHistory.completedDays(),
            firstActivity: ActivityHistory.firstActivityDate()
        )
    }
}

private struct ActivityBarChart: View {
    let days: [DayCount]

    private let visibleDayCount = 30
    private let barSpacing: CGFloat = 2
    private let yAxisWidth: CGFloat = 22
    private let plotAxisSpacing: CGFloat = 8
    private let labelHeight: CGFloat = 14

    private var maxCount: Int {
        let highest = days.map(\.count).max() ?? 0
        if highest <= 4 { return 4 }
        return Int((Double(highest) / 4.0).rounded(.up) * 4)
    }

    private var yTicks: [Int] {
        let step = max(1, maxCount / 4)
        return Array(stride(from: 0, through: maxCount, by: step))
    }

    var body: some View {
        GeometryReader { geo in
            let plotWidth = max(0, geo.size.width - yAxisWidth - plotAxisSpacing)
            let barWidth = barWidth(for: plotWidth)
            let contentWidth = contentWidth(barWidth: barWidth)
            let plotHeight = max(0, geo.size.height - labelHeight - 10)

            HStack(alignment: .top, spacing: plotAxisSpacing) {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 10) {
                        Canvas { context, size in
                            draw(context: context, size: size, barWidth: barWidth)
                        }
                        .frame(width: contentWidth, height: plotHeight)

                        xLabels(barWidth: barWidth)
                            .frame(width: contentWidth, height: labelHeight, alignment: .topLeading)
                    }
                    .frame(minWidth: plotWidth, alignment: .trailing)
                }
                .defaultScrollAnchor(.trailing)
                .scrollBounceBehavior(.basedOnSize)

                yAxis
                    .frame(width: yAxisWidth, height: plotHeight)
            }
        }
    }

    private var yAxis: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(yTicks.reversed()), id: \.self) { tick in
                Text("\(tick)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if tick != yTicks.first {
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func xLabels(barWidth: CGFloat) -> some View {
        let calendar = Calendar.current
        return ZStack(alignment: .topLeading) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                if shouldLabel(index, calendar: calendar) {
                    Text(day.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .offset(x: labelOffset(index: index, barWidth: barWidth))
                }
            }
        }
    }

    private func barWidth(for plotWidth: CGFloat) -> CGFloat {
        let visible = min(max(days.count, 1), visibleDayCount)
        return max(2, (plotWidth - barSpacing * CGFloat(visible - 1)) / CGFloat(visible))
    }

    private func contentWidth(barWidth: CGFloat) -> CGFloat {
        let count = max(days.count, 1)
        return CGFloat(count) * barWidth + barSpacing * CGFloat(count - 1)
    }

    private func labelOffset(index: Int, barWidth: CGFloat) -> CGFloat {
        CGFloat(index) * (barWidth + barSpacing)
    }

    private func draw(context: GraphicsContext, size: CGSize, barWidth: CGFloat) {
        let calendar = Calendar.current

        for tick in yTicks {
            let y = size.height - (CGFloat(tick) / CGFloat(maxCount)) * size.height
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(
                line,
                with: .color(Color.appForeground.opacity(0.16)),
                style: StrokeStyle(lineWidth: 0.5, dash: [3, 4])
            )
        }

        for (index, day) in days.enumerated() where calendar.component(.weekday, from: day.date) == calendar.firstWeekday {
            let x = CGFloat(index) * (barWidth + barSpacing) + barWidth / 2
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(
                line,
                with: .color(Color.appForeground.opacity(0.1)),
                style: StrokeStyle(lineWidth: 0.5, dash: [3, 4])
            )
        }

        for (index, day) in days.enumerated() where day.count > 0 {
            let height = max(3, size.height * CGFloat(day.count) / CGFloat(maxCount))
            let x = CGFloat(index) * (barWidth + barSpacing)
            let rect = CGRect(x: x, y: size.height - height, width: barWidth, height: height)
            context.fill(
                Path(roundedRect: rect, cornerRadius: barWidth / 2, style: .continuous),
                with: .color(.activityAccent)
            )
        }
    }

    private func shouldLabel(_ index: Int, calendar: Calendar) -> Bool {
        guard days.indices.contains(index) else { return false }
        if days.count <= 1 { return true }
        if days.count <= visibleDayCount {
            return [0, days.count / 3, (days.count * 2) / 3, days.count - 1].contains(index)
        }
        if index == 0 || index == days.count - 1 { return true }
        return calendar.component(.day, from: days[index].date) == 1
    }
}

private struct YearContributionGrid: View {
    let completedDays: Set<Date>
    var firstActivity: Date?

    private let calendar = Calendar.current
    private let dotSize: CGFloat = 11
    private let spacing: CGFloat = 12
    private let weekdayGutter: CGFloat = 16

    var body: some View {
        let now = Date()
        let layout = ContributionGridLayout(firstActivity: firstActivity, now: now, calendar: calendar)

        HStack(alignment: .top, spacing: 6) {
            VStack(spacing: spacing) {
                ForEach(Array(rotatedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: weekdayGutter, height: dotSize, alignment: .leading)
                }
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(0..<layout.columns, id: \.self) { column in
                            VStack(spacing: spacing) {
                                ForEach(0..<7, id: \.self) { row in
                                    let date = layout.date(column: column, row: row)
                                    Circle()
                                        .fill(fill(for: date))
                                        .frame(width: dotSize, height: dotSize)
                                        .accessibilityLabel(date.map(accessibilityLabel(for:)) ?? "Empty")
                                        .accessibilityHidden(date == nil)
                                }

                                Color.clear
                                    .frame(width: dotSize, height: 14)
                                    .overlay(alignment: .leading) {
                                        if let label = layout.monthLabel(for: column) {
                                            Text(label)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .fixedSize()
                                        }
                                    }
                            }
                            .id(column)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .onAppear {
                    let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
                    if let monthStart, let column = layout.column(containing: monthStart) {
                        proxy.scrollTo(column, anchor: .leading)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var rotatedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    private func fill(for date: Date?) -> Color {
        guard let date else { return .clear }
        return completedDays.contains(calendar.startOfDay(for: date))
            ? Color.activityAccent
            : Color.appForeground.opacity(0.14)
    }

    private func accessibilityLabel(for date: Date) -> String {
        let day = date.formatted(.dateTime.month(.abbreviated).day())
        return completedDays.contains(calendar.startOfDay(for: date))
            ? "\(day), activity completed"
            : "\(day), no activity"
    }
}

struct ContributionGridLayout {
    let start: Date
    let dayCount: Int
    let leadingEmpty: Int
    let columns: Int
    let calendar: Calendar
    let nowYear: Int

    init(firstActivity: Date?, now: Date, calendar: Calendar) {
        self.calendar = calendar
        nowYear = calendar.component(.year, from: now)
        var endComponents = calendar.dateComponents([.year], from: now)
        endComponents.month = 12
        endComponents.day = 31
        let end = calendar.startOfDay(for: calendar.date(from: endComponents) ?? now)

        let origin = firstActivity.map { min($0, now) }
        var startComponents: DateComponents
        if let origin {
            startComponents = DateComponents(year: calendar.component(.year, from: origin), month: 1, day: 1)
        } else {
            startComponents = calendar.dateComponents([.year, .month], from: now)
        }
        var monthStart = calendar.date(from: startComponents) ?? calendar.startOfDay(for: origin ?? now)
        if monthStart > end {
            startComponents = calendar.dateComponents([.year, .month], from: now)
            monthStart = calendar.date(from: startComponents) ?? calendar.startOfDay(for: now)
        }

        start = monthStart
        dayCount = max(1, (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
        let weekday = calendar.component(.weekday, from: start)
        leadingEmpty = (weekday - calendar.firstWeekday + 7) % 7
        columns = Int(ceil(Double(leadingEmpty + dayCount) / 7.0))
    }

    func date(column: Int, row: Int) -> Date? {
        let offset = column * 7 + row - leadingEmpty
        guard offset >= 0, offset < dayCount else { return nil }
        return calendar.date(byAdding: .day, value: offset, to: start)
    }

    func column(containing date: Date) -> Int? {
        let day = calendar.startOfDay(for: date)
        let offset = calendar.dateComponents([.day], from: start, to: day).day ?? 0
        guard offset >= 0, offset < dayCount else { return nil }
        return (offset + leadingEmpty) / 7
    }

    func monthLabel(for column: Int) -> String? {
        for row in 0..<7 {
            guard let date = date(column: column, row: row), calendar.component(.day, from: date) == 1 else {
                continue
            }
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let startYear = calendar.component(.year, from: start)
            if year != nowYear || (month == 1 && startYear != nowYear) {
                return date.formatted(.dateTime.month(.abbreviated).year())
            }
            return date.formatted(.dateTime.month(.abbreviated))
        }
        return nil
    }
}

struct ProfileAvatarImage: View {
    var image: UIImage?
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.appSecondaryBackground)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.38, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.appSecondaryBorder, lineWidth: 0.5)
        }
    }
}
