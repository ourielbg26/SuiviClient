import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home = "Accueil"
    case stats = "Stats"
    case calendar = "Calendrier"
    case settings = "Paramètres"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house"
        case .stats: return "chart.bar"
        case .calendar: return "calendar"
        case .settings: return "slider.horizontal.3"
        }
    }
}

/// Barre d'onglets capsule flottante en verre translucide (§5 du README) —
/// pas une TabView standard : posée au-dessus du contenu, flou + matériau.
struct FloatingTabBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                let active = tab == selected
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Capsule()
                                .fill(active ? Theme.Colors.accentTint : Color.clear)
                                .frame(width: 34, height: 26)
                            Image(systemName: tab.icon)
                                .font(.system(size: 17, weight: active ? .regular : .light))
                        }
                        Text(tab.rawValue)
                            .font(AppFont.montserrat(10, weight: .semibold))
                    }
                    .foregroundStyle(active ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(.regularMaterial)
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.8), lineWidth: 1)
                )
        )
        .tabBarShadow()
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }
}
