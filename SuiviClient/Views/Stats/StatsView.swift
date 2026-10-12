import SwiftUI
import Charts

private enum StatsPeriod: String, CaseIterable { case ceMois = "Ce mois", troisMois = "3 derniers mois", cetteAnnee = "Cette année", depuisToujours = "Depuis toujours", periode = "Période…" }

private enum RankSet: String, CaseIterable { case modeles = "Modèles vendus", reparations = "Réparations", couleurs = "Couleurs", produits = "Produits", clientes = "Meilleures clientes" }

private struct RankItem: Identifiable {
    let id = UUID()
    let label: String
    let valueLabel: String
    let subLabel: String
    let color: Color
    let ratio: CGFloat
}

private struct Slice: Identifiable {
    let id = UUID()
    let category: Category
    let amount: Decimal
    let pct: Double
}

struct StatsView: View {
    @Environment(DataStore.self) private var store

    @State private var period: StatsPeriod = .ceMois
    @State private var pFrom = Calendar.current.date(byAdding: .month, value: -2, to: .now) ?? .now
    @State private var pTo = Date.now
    @State private var rankSet: RankSet = .modeles

    private var scope: [TransactionEntry] {
        store.allEntries.filter { t in
            switch period {
            case .ceMois: return Calendar.current.isDate(t.dropDate, equalTo: .now, toGranularity: .month)
            case .troisMois: return Formatters.days(from: t.dropDate) <= 92
            case .cetteAnnee: return Calendar.current.isDate(t.dropDate, equalTo: .now, toGranularity: .year)
            case .depuisToujours: return true
            case .periode:
                let start = Calendar.current.startOfDay(for: pFrom)
                let end = Calendar.current.startOfDay(for: pTo)
                return t.dropDate >= start && t.dropDate <= end
            }
        }
    }

    private func sum(_ items: [TransactionEntry]) -> Decimal { items.reduce(0) { $0 + $1.price } }

    private var scopeTotal: Decimal { sum(scope) }
    private var scopePaid: Decimal { sum(scope.filter(\.isPaid)) }
    private var scopePlanPaid: Decimal { scope.filter { $0.plan != nil && !$0.isPaid }.reduce(0) { $0 + ($1.planReceived ?? 0) } }
    private var encaisse: Decimal { scopePaid + scopePlanPaid }
    private var enAttente: Decimal { scopeTotal - encaisse }
    private var moyen: Decimal { scope.isEmpty ? 0 : scopeTotal / Decimal(scope.count) }

    private var periodLabel: String {
        period == .periode ? "\(Formatters.shortDate(pFrom)) → \(Formatters.shortDate(pTo))" : period.rawValue
    }

    private var slices: [Slice] {
        Category.selectable.map { cat in
            let amt = sum(scope.filter { $0.category == cat })
            let pct = scopeTotal > 0 ? (Double(truncating: amt as NSNumber) / Double(truncating: scopeTotal as NSNumber)) * 100 : 0
            return Slice(category: cat, amount: amt, pct: pct)
        }
    }

    private var ranking: [RankItem] {
        switch rankSet {
        case .modeles:
            return grouped(scope.filter { $0.category == .vente }) { $0.item.components(separatedBy: " · ").first ?? $0.item }
        case .reparations:
            return grouped(scope.filter { $0.category == .reparation }) { $0.item.components(separatedBy: " + ").first ?? $0.item }
        case .couleurs:
            return grouped(scope.filter { $0.category == .couleur }) { e in
                let p = e.item.components(separatedBy: " · ")
                return p.count > 1 ? p[1] : e.item
            }
        case .produits:
            return grouped(scope.filter { $0.category == .produit }) { $0.item }
        case .clientes:
            var map: [String: [TransactionEntry]] = [:]
            for t in scope { map[t.clientName, default: []].append(t) }
            let items = map.map { (name, txs) in (name, txs) }.sorted { sum($0.1) > sum($1.1) }.prefix(5)
            let maxValue = items.first.map { sum($0.1) } ?? 1
            return items.map { name, txs in
                let total = sum(txs)
                let ratio = maxValue > 0 ? max(0.06, min(0.82, Double(truncating: (total / maxValue) as NSNumber))) : 0.06
                return RankItem(label: name, valueLabel: Formatters.money(total), subLabel: "\(txs.count) fiche\(txs.count > 1 ? "s" : "")", color: Theme.Colors.couleurLine, ratio: ratio)
            }
        }
    }

    private var rankHint: String {
        switch rankSet {
        case .modeles: return "Perruques les plus vendues (texture + longueur)."
        case .reparations: return "Réparations les plus fréquentes sur la période."
        case .couleurs: return "Couleurs les plus demandées sur la période."
        case .produits: return "Produits les plus vendus sur la période."
        case .clientes: return "Clientes qui ont le plus dépensé sur la période."
        }
    }

    private var rankColor: Color {
        switch rankSet {
        case .modeles: return Theme.Colors.venteLine
        case .reparations: return Theme.Colors.reparationLine
        case .couleurs: return Theme.Colors.couleurLine
        case .produits: return Theme.Colors.produitLine
        case .clientes: return Theme.Colors.couleurLine
        }
    }

    private func grouped(_ items: [TransactionEntry], key: (TransactionEntry) -> String) -> [RankItem] {
        var map: [String: [TransactionEntry]] = [:]
        for t in items {
            let k = key(t)
            guard !k.isEmpty else { continue }
            map[k, default: []].append(t)
        }
        let sorted = map.map { ($0.key, $0.value) }.sorted { $0.1.count > $1.1.count }.prefix(5)
        let maxCount = sorted.first?.1.count ?? 1
        return sorted.map { name, txs in
            let ratio = maxCount > 0 ? max(0.06, min(0.82, Double(txs.count) / Double(maxCount))) : 0.06
            return RankItem(label: name, valueLabel: "\(txs.count)×", subLabel: Formatters.money(sum(txs)), color: rankColor, ratio: ratio)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Statistiques").font(AppFont.display(22, weight: .semibold)).tracking(AppTracking.screenTitle).textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.contentMargin)
            .padding(.top, 6)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 12) {
                    FlowLayout(spacing: 7) {
                        ForEach(StatsPeriod.allCases, id: \.self) { p in
                            ChipButton(label: p.rawValue, isActive: period == p) { period = p }
                        }
                    }

                    if period == .periode {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Du").font(AppFont.montserrat(11, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                                DatePicker("", selection: $pFrom, displayedComponents: .date).labelsHidden()
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Au").font(AppFont.montserrat(11, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                                DatePicker("", selection: $pTo, displayedComponents: .date).labelsHidden()
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.Colors.card))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button).strokeBorder(Theme.Colors.border, lineWidth: 1))
                    }

                    summaryCard
                    donutCard
                    rankingCard
                }
                .padding(.horizontal, Theme.Spacing.contentMargin)
                .screenBottomPadding()
            }
        }
        .background(PaperBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("\(periodLabel) · encaissé").font(AppFont.montserrat(13, weight: .medium)).foregroundStyle(.white)
                Text(Formatters.money(encaisse))
                    .font(AppFont.display(44, weight: .bold))
                    .tracking(AppTracking.bigNumber)
                    .foregroundStyle(.white)
            }
            HStack(spacing: 8) {
                statTile("En attente", Formatters.money(enAttente))
                statTile("Travaux", "\(scope.count)")
                statTile("Moyen", Formatters.money(moyen))
            }
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.statCard).fill(Theme.Colors.primaryButton))
        .statCardShadow()
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(AppFont.montserrat(11, weight: .medium)).foregroundStyle(.white)
            Text(value).font(AppFont.display(18, weight: .bold)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Color.white.opacity(0.12)))
    }

    private var donutCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 18) {
                ZStack {
                    Chart(slices) { s in
                        SectorMark(angle: .value("Montant", max(Double(truncating: s.amount as NSNumber), 0.0001)),
                                   innerRadius: .ratio(0.66), angularInset: 1.5)
                            .foregroundStyle(s.category.lineColor)
                    }
                    .chartLegend(.hidden)
                    .frame(width: 132, height: 132)

                    VStack(spacing: 1) {
                        Text(Formatters.money(scopeTotal))
                            .font(AppFont.display(18, weight: .bold))
                            .tracking(-0.3)
                        Text("facturé").font(AppFont.montserrat(10)).foregroundStyle(Theme.Colors.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(slices) { s in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3).fill(s.category.lineColor).frame(width: 10, height: 10)
                            Text(s.category.rawValue).font(AppFont.montserrat(12, weight: .medium)).lineLimit(1)
                            Spacer()
                            Text("\(Int(s.pct.rounded())) %").font(AppFont.montserrat(12, weight: .semibold))
                        }
                    }
                }
            }

            VStack(spacing: 0) {
                ForEach(slices) { s in
                    HStack {
                        Text(s.category.rawValue).font(AppFont.montserrat(13)).foregroundStyle(Theme.Colors.textSecondary)
                        Spacer()
                        Text(Formatters.money(s.amount)).font(AppFont.montserrat(13, weight: .semibold))
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.Colors.separator).frame(height: 1) }
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Colors.card))
        .cardShadow()
    }

    private var rankingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Classement").font(AppFont.display(16, weight: .semibold))
            FlowLayout(spacing: 7) {
                ForEach(RankSet.allCases, id: \.self) { r in
                    ChipButton(label: r.rawValue, isActive: rankSet == r) { rankSet = r }
                }
            }
            Text(rankHint).font(AppFont.montserrat(12)).foregroundStyle(Theme.Colors.textSecondary)

            if ranking.isEmpty {
                Text("Rien sur cette période.").font(AppFont.montserrat(13)).foregroundStyle(Theme.Colors.textSecondary)
            } else {
                VStack(spacing: 9) {
                    HStack(alignment: .bottom, spacing: 9) {
                        ForEach(ranking) { r in
                            VStack(spacing: 6) {
                                Text(r.valueLabel).font(AppFont.montserrat(12, weight: .semibold))
                                UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 10, style: .continuous)
                                    .fill(r.color)
                                    .frame(height: max(8, 156 * r.ratio))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.border).frame(height: 1) }

                    HStack(spacing: 9) {
                        ForEach(ranking) { r in
                            VStack(spacing: 2) {
                                Text(shortLabel(r.label)).font(AppFont.montserrat(10, weight: .medium)).lineLimit(1)
                                Text(r.subLabel).font(AppFont.montserrat(9)).foregroundStyle(Theme.Colors.textSecondary).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Colors.card))
        .cardShadow()
    }

    private func shortLabel(_ s: String) -> String {
        s.count > 15 ? String(s.prefix(14)).trimmingCharacters(in: .whitespaces) + "…" : s
    }
}
