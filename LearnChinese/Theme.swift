import SwiftUI
import UIKit

enum AppChrome {
    static let containerCornerRadius: CGFloat = 20

    static func configure() {
        let largeTitleFont = UIFont.systemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .title1).pointSize,
            weight: .bold
        )
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .font: largeTitleFont,
            .foregroundColor: UIColor.appForeground
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor.appForeground
        ]
        UINavigationBar.appearance().tintColor = UIColor.appAccent

        // Keep long-press context menu previews and list highlights neutral.
        UITableView.appearance().tintColor = UIColor.appForeground
        UICollectionView.appearance().tintColor = UIColor.appForeground
    }
}

enum AppHaptics {
    static func addedItem() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
}

extension UIColor {
    static let appForeground = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0xDB / 255, green: 0xDC / 255, blue: 0xDC / 255, alpha: 1)
        }
        return .label
    }

    static let appAccent = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0xDB / 255, green: 0xDC / 255, blue: 0xDC / 255, alpha: 1)
        }
        return .systemBlue
    }
}

extension Color {
    static let appForeground = Color(uiColor: .appForeground)
    static let appAccent = Color(uiColor: .appAccent)

    static let appBackground = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0x14 / 255, green: 0x14 / 255, blue: 0x14 / 255, alpha: 1)
        }
        // Neutral gray instead of systemGroupedBackground (#F2F2F7), whose blue
        // undertone gets amplified by the context-menu blur and reads as blue.
        return UIColor(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF2 / 255, alpha: 1)
    })

    static let appSecondaryBackground = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0x18 / 255, green: 0x18 / 255, blue: 0x18 / 255, alpha: 1)
        }
        return .secondarySystemGroupedBackground
    })

    static let appSecondaryBorder = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0x28 / 255, green: 0x28 / 255, blue: 0x28 / 255, alpha: 1)
        }
        return UIColor.black.withAlphaComponent(0.08)
    })

    static let activityAccent = Color(red: 1.0, green: 0.38, blue: 0.13)
    static let appMutedText = Color(red: 145.0 / 255.0, green: 145.0 / 255.0, blue: 145.0 / 255.0)
}

struct AppSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .textCase(nil)
    }
}

struct AppSecondaryContainerBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: AppChrome.containerCornerRadius, style: .continuous)
            .fill(Color.appSecondaryBackground)
            .overlay {
                RoundedRectangle(cornerRadius: AppChrome.containerCornerRadius, style: .continuous)
                    .stroke(Color.appSecondaryBorder, lineWidth: 0.5)
            }
    }
}

extension View {
    func appScreenBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
            .tint(Color.appAccent)
            .foregroundStyle(Color.appForeground)
    }

    func appListChrome() -> some View {
        self
            .appScreenBackground()
            .listStyle(.plain)
            .listSectionSpacing(16)
            .listItemTint(Color.appForeground)
            .environment(\.defaultMinListRowHeight, 0)
            .contentMargins(.horizontal, 16, for: .scrollContent)
    }

    func appListRowBackground() -> some View {
        self
            .listRowBackground(AppSecondaryContainerBackground())
            .listRowSeparator(.hidden)
    }

    func appRaisedCard() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppSecondaryContainerBackground())
    }

    func appListSectionTitle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
            .listRowBackground(Rectangle().fill(Color.clear))
            .listRowSeparator(.hidden)
            .containerShape(Rectangle())
    }

    func appPlainCardRow() -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowBackground(Rectangle().fill(Color.clear))
            .listRowSeparator(.hidden)
            .containerShape(Rectangle())
    }

    @ViewBuilder
    func appLabeledCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        AppSectionHeader(title: title)
            .appListSectionTitle()
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .appRaisedCard()
            .appPlainCardRow()
    }
}

struct AppLabeledBlock<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionHeader(title: title)
                .padding(.horizontal, 4)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .appRaisedCard()
        }
    }
}
