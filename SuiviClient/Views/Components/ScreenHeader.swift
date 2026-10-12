import SwiftUI

/// Bouton retour 36×36, rayon 12, utilisé en tête des écrans poussés.
struct BackButton: View {
    @Environment(\.dismiss) private var dismiss
    var action: (() -> Void)?

    var body: some View {
        Button {
            if let action { action() } else { dismiss() }
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.backButton).fill(Theme.Colors.card))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.backButton).strokeBorder(Theme.Colors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// En-tête standard : retour + titre serif en capitales espacées + accessoire à droite.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    var showBack: Bool = true
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            if showBack { BackButton() }
            Text(title)
                .font(AppFont.display(18, weight: .semibold))
                .tracking(AppTracking.screenTitle * 0.8)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            trailing()
        }
        .padding(.horizontal, Theme.Spacing.contentMargin)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, showBack: Bool = true) {
        self.title = title
        self.showBack = showBack
        self.trailing = { EmptyView() }
    }
}
