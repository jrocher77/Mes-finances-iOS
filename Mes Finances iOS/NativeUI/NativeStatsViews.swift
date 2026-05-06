//
//  NativeStatsViews.swift
//  Mes Finances iOS
//
//  Read-only native statistics views for the migration dashboard.
//

import SwiftUI

struct NativeCheckingStatsView: View {
    @ObservedObject var store: NativeFinanceStore
    var onBack: () -> Void
    @State private var accountId = "all"

    private var currentMonthKey: String {
        FinanceCalculations.currentMonthKey()
    }

    private var checkingAccounts: [FinanceAccount] {
        store.document.accounts.filter { $0.type == .checking }
    }

    private var selectedCheckingAccounts: [FinanceAccount] {
        guard accountId != "all" else { return checkingAccounts }
        return checkingAccounts.filter { $0.id == accountId }
    }

    private var currentStats: CheckingStatsResult {
        FinanceCalculations.aggregateCheckingStats(
            transactions: store.document.transactions,
            accountIds: selectedCheckingAccounts.map(\.id),
            monthKey: currentMonthKey
        )
    }

    private var historyRows: [CheckingHistoryRow] {
        let entries = accountId == "all"
            ? store.document.checkingHistory
            : store.document.checkingHistory.filter { $0.accountId == accountId }
        let grouped = Dictionary(grouping: entries, by: \.monthKey)
        return grouped.map { monthKey, entries in
            CheckingHistoryRow(
                monthKey: monthKey,
                income: entries.reduce(0) { $0 + $1.income },
                expense: entries.reduce(0) { $0 + $1.expense },
                balance: entries.reduce(0) { $0 + $1.balance },
                total: entries.reduce(0) { $0 + $1.total },
                pointed: entries.reduce(0) { $0 + $1.pointed },
                accountCount: Set(entries.map(\.accountId)).count
            )
        }
        .sorted { $0.monthKey > $1.monthKey }
    }

    private var chartRows: [CheckingChartRow] {
        let history = historyRows.prefix(5).reversed().map {
            CheckingChartRow(
                id: $0.monthKey,
                label: monthShort($0.monthKey),
                income: $0.income,
                expense: $0.expense,
                balance: $0.balance
            )
        }
        let current = CheckingChartRow(
            id: currentMonthKey,
            label: monthShort(currentMonthKey),
            income: currentStats.income,
            expense: currentStats.expense,
            balance: currentStats.balance
        )
        return Array(history) + [current]
    }

    private var incomeSparkline: [Double] {
        chartRows.map(\.income)
    }

    private var expenseSparkline: [Double] {
        chartRows.map(\.expense)
    }

    private var balanceSparkline: [Double] {
        chartRows.map(\.balance)
    }

    private var previousRow: CheckingHistoryRow? {
        historyRows.first
    }

    private var dayOfMonth: Int {
        max(Calendar.current.component(.day, from: Date()), 1)
    }

    private var daysInCurrentMonth: Int {
        daysInMonth(currentMonthKey)
    }

    private var daysLeft: Int {
        max(daysInCurrentMonth - dayOfMonth + 1, 1)
    }

    private var averageDailyExpense: Double {
        currentStats.expense / Double(dayOfMonth)
    }

    private var remainingPerDay: Double? {
        guard currentStats.balance > 0 else { return nil }
        return currentStats.balance / Double(daysLeft)
    }

    private var pointedRate: Int? {
        guard currentStats.total > 0 else { return nil }
        return Int((Double(currentStats.pointed) / Double(currentStats.total) * 100).rounded())
    }

    var body: some View {
        StatsScreenScaffold(title: "Statistiques comptes courants", onBack: onBack) {
            VStack(spacing: 14) {
                accountSelector
                monthTitle(currentMonthKey, suffix: "en cours")

                HStack(spacing: 8) {
                    StatCard(title: "Revenus", value: currentStats.income, color: NativeTheme.green, sparkline: incomeSparkline)
                    StatCard(title: "Dépenses", value: currentStats.expense, color: NativeTheme.red, sparkline: expenseSparkline)
                    StatCard(
                        title: "Résultat mois",
                        value: currentStats.balance,
                        color: currentStats.balance >= 0 ? NativeTheme.gold : NativeTheme.red,
                        sparkline: balanceSparkline
                    )
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    SmallMetricCard(
                        title: "Tx pointées",
                        value: pointedRate.map { "\($0)%" } ?? "-",
                        detail: pointageDetail,
                        color: pointageColor,
                        progress: pointedProgress
                    )
                    SmallMetricCard(
                        title: "Dépense / jour",
                        value: averageDailyExpense.formatted(.currency(code: "EUR")),
                        detail: "Sur \(dayOfMonth)j écoulé\(dayOfMonth > 1 ? "s" : "")",
                        color: NativeTheme.red
                    )
                    SmallMetricCard(
                        title: "Restant / jour",
                        value: remainingPerDay?.formatted(.currency(code: "EUR")) ?? "-",
                        detail: "\(daysLeft)j restants ce mois-ci",
                        color: remainingPerDay == nil ? NativeTheme.red : NativeTheme.green
                    )
                    previousMonthCard
                }

                if chartRows.count >= 2 {
                    CheckingBarChartView(rows: chartRows)
                    chartLegend
                }

                historySection
            }
        }
    }

    private var accountSelector: some View {
        Group {
            if checkingAccounts.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        AccountSelectorChip(
                            title: "Tous les comptes",
                            icon: "chart.bar",
                            isSelected: accountId == "all"
                        ) {
                            accountId = "all"
                        }

                        ForEach(checkingAccounts) { account in
                            AccountSelectorChip(
                                title: account.name,
                                icon: "creditcard",
                                isSelected: accountId == account.id
                            ) {
                                accountId = account.id
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var pointageDetail: String {
        guard currentStats.total > 0 else { return "Aucune tx" }
        if currentStats.pointed == currentStats.total {
            return "Mois soldé"
        }
        let remaining = currentStats.total - currentStats.pointed
        return "\(currentStats.pointed)/\(currentStats.total) - \(remaining) non pointée\(remaining > 1 ? "s" : "")"
    }

    private var pointageColor: Color {
        guard let pointedRate else { return NativeTheme.mutedText }
        if pointedRate == 100 { return NativeTheme.green }
        if pointedRate >= 50 { return NativeTheme.gold }
        return NativeTheme.red
    }

    private var pointedProgress: Double? {
        guard currentStats.total > 0 else { return nil }
        return Double(currentStats.pointed) / Double(currentStats.total)
    }

    private var previousMonthCard: some View {
        PreviousMonthMetricCard(
            previousMonth: previousRow.map { monthShort($0.monthKey) },
            balanceDiff: previousRow.map { currentStats.balance - $0.balance },
            incomeDiff: previousRow.map { currentStats.income - $0.income },
            expenseDiff: previousRow.map { currentStats.expense - $0.expense }
        )
    }

    private var chartLegend: some View {
        HStack(spacing: 12) {
            Label("Revenus", systemImage: "square.fill")
                .foregroundStyle(NativeTheme.green)
            Label("Dépenses", systemImage: "square.fill")
                .foregroundStyle(NativeTheme.red)
            Spacer()
        }
        .font(.caption.weight(.semibold))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(historyRows.isEmpty ? "Historique mensuel" : "Historique mensuel (\(historyRows.count) mois)")
                .font(.caption.weight(.bold))
                .foregroundStyle(NativeTheme.subtleText)
                .textCase(.uppercase)

            if historyRows.isEmpty {
                EmptyStatsState(text: "Historique vide pour l'instant")
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(historyRows.enumerated()), id: \.element.id) { index, row in
                        let previous = historyRows.indices.contains(index + 1) ? historyRows[index + 1] : nil
                        CheckingHistoryRowView(
                            row: row,
                            variation: previous.map { row.balance - $0.balance },
                            showAccountCount: accountId == "all"
                        )
                    }
                }
            }
        }
    }
}

struct NativeSavingsStatsView: View {
    @ObservedObject var store: NativeFinanceStore
    var onBack: () -> Void

    private var totals: (available: Double, blocked: Double) {
        FinanceCalculations.savingsTotals(accounts: store.document.accounts)
    }

    private var totalSavings: Double {
        totals.available + totals.blocked
    }

    private var historyRows: [SavingsHistoryRow] {
        store.document.savingsHistory
            .map {
                SavingsHistoryRow(
                    date: $0.date,
                    available: $0.available,
                    blocked: $0.blocked,
                    total: $0.available + $0.blocked,
                    note: $0.note
                )
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        StatsScreenScaffold(title: "Statistiques epargne", onBack: onBack) {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    StatCard(title: "Disponible", value: totals.available, color: NativeTheme.green)
                    StatCard(title: "Bloquee", value: totals.blocked, color: NativeTheme.red)
                    StatCard(title: "Total", value: totalSavings, color: NativeTheme.gold)
                }

                historySection
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Historique epargne")
                .font(.caption.weight(.bold))
                .foregroundStyle(NativeTheme.subtleText)
                .textCase(.uppercase)

            if historyRows.isEmpty {
                EmptyStatsState(text: "Aucun snapshot epargne")
            } else {
                VStack(spacing: 8) {
                    ForEach(historyRows.prefix(10)) { row in
                        HistoryRow(
                            title: dateLabel(row.date),
                            primary: row.total,
                            details: [
                                ("Disponible", row.available, NativeTheme.green),
                                ("Bloquee", row.blocked, NativeTheme.red)
                            ]
                        )
                    }
                }
            }
        }
    }
}

private struct StatsScreenScaffold<Content: View>: View {
    var title: String
    var onBack: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            NativeTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    content
                        .padding(16)
                        .padding(.bottom, 30)
                }
            }
        }
        .foregroundStyle(NativeTheme.text)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                    Text("Retour")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(NativeTheme.mutedText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(NativeTheme.surface2, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(NativeTheme.border))
            }

            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(NativeTheme.background.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NativeTheme.border)
                .frame(height: 1)
        }
    }
}

private struct StatCard: View {
    var title: String
    var value: Double
    var color: Color
    var sparkline: [Double] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(NativeTheme.subtleText)
                .textCase(.uppercase)
            Text(value, format: .currency(code: "EUR"))
                .font(.system(size: 14, weight: .bold, design: .serif))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            MiniSparkline(values: sparkline, color: color)
                .frame(height: 12)
        }
        .frame(maxWidth: .infinity, minHeight: 66, maxHeight: 66, alignment: .leading)
        .padding(9)
        .background(NativeTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(NativeTheme.border))
    }
}

private struct AccountSelectorChip: View {
    var title: String
    var icon: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? NativeTheme.gold : NativeTheme.mutedText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? NativeTheme.gold.opacity(0.14) : NativeTheme.surface2, in: Capsule())
            .overlay(Capsule().stroke(isSelected ? NativeTheme.gold : NativeTheme.border))
        }
        .buttonStyle(.plain)
    }
}

private struct MiniSparkline: View {
    var values: [Double]
    var color: Color

    var body: some View {
        GeometryReader { proxy in
            let points = sparklinePoints(size: proxy.size)
            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(color.opacity(0.72), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func sparklinePoints(size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        let range = max(maxValue - minValue, 1)
        let width = max(size.width, 1)
        let height = max(size.height, 1)

        return values.enumerated().map { index, value in
            let x = width * CGFloat(index) / CGFloat(values.count - 1)
            let normalized = (value - minValue) / range
            let y = height - CGFloat(normalized) * height
            return CGPoint(x: x, y: y)
        }
    }
}

private struct SmallMetricCard: View {
    var title: String
    var value: String
    var detail: String
    var color: Color = NativeTheme.gold
    var progress: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(NativeTheme.subtleText)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(NativeTheme.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if let progress {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(NativeTheme.surface2)
                        Capsule()
                            .fill(color)
                            .frame(width: proxy.size.width * min(max(progress, 0), 1))
                    }
                }
                .frame(height: 5)
                .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 78, maxHeight: 78, alignment: .leading)
        .padding(10)
        .background(NativeTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(NativeTheme.border))
    }
}

private struct PreviousMonthMetricCard: View {
    var previousMonth: String?
    var balanceDiff: Double?
    var incomeDiff: Double?
    var expenseDiff: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("vs \(previousMonth ?? "mois préc.")")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(NativeTheme.subtleText)
                .textCase(.uppercase)

            if balanceDiff == nil {
                Text("Pas encore d'historique")
                    .font(.caption)
                    .foregroundStyle(NativeTheme.mutedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 2) {
                    diffLine(label: "Résultat", value: balanceDiff, colorValue: balanceDiff)
                    diffLine(label: "Revenus", value: incomeDiff, colorValue: incomeDiff)
                    diffLine(
                        label: "Dépenses",
                        value: expenseDiff,
                        colorValue: expenseDiff.map { -$0 }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 78, maxHeight: 78, alignment: .leading)
        .padding(10)
        .background(NativeTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(NativeTheme.border))
    }

    private func diffLine(label: String, value: Double?, colorValue: Double?) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(NativeTheme.mutedText)
            Spacer()
            Text(value.map(amountWithSign) ?? "-")
                .font(.caption.weight(.bold))
                .foregroundStyle(diffColor(colorValue ?? 0))
        }
    }

    private func diffColor(_ value: Double) -> Color {
        if value > 0 { return NativeTheme.green }
        if value < 0 { return NativeTheme.red }
        return NativeTheme.subtleText
    }
}

private struct CheckingBarChartView: View {
    var rows: [CheckingChartRow]
    @State private var selectedID: String?

    private var maxValue: Double {
        max(rows.flatMap { [$0.income, $0.expense] }.max() ?? 0, 1)
    }

    private var selectedRow: CheckingChartRow? {
        guard let selectedID else { return nil }
        return rows.first { $0.id == selectedID }
    }

    private var scaleTicks: [Double] {
        (0...3).map { maxValue * Double($0) / 3 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Revenus / Dépenses par mois")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(NativeTheme.subtleText)
                .textCase(.uppercase)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

            GeometryReader { proxy in
                let leftAxisWidth: CGFloat = 42
                let rightPadding: CGFloat = 8
                let bottomLabelHeight: CGFloat = 22
                let plotHeight = max(proxy.size.height - bottomLabelHeight, 1)
                let plotWidth = max(proxy.size.width - leftAxisWidth - rightPadding, 1)
                let groupWidth = plotWidth / CGFloat(max(rows.count, 1))
                let barWidth = min(groupWidth * 0.26, 20)
                let gap = barWidth * 0.45

                ZStack(alignment: .topLeading) {
                    ForEach(Array(scaleTicks.enumerated()), id: \.offset) { _, tick in
                        let y = yPosition(tick, height: plotHeight)
                        Text(formatAxis(tick))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(NativeTheme.subtleText.opacity(0.65))
                            .frame(width: leftAxisWidth - 6, alignment: .trailing)
                            .position(x: (leftAxisWidth - 6) / 2, y: y)

                        Rectangle()
                            .fill(NativeTheme.border.opacity(0.55))
                            .frame(width: plotWidth, height: 1)
                            .position(x: leftAxisWidth + plotWidth / 2, y: y)
                    }

                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        let centerX = leftAxisWidth + groupWidth * CGFloat(index) + groupWidth / 2
                        let incomeHeight = barHeight(row.income, availableHeight: plotHeight)
                        let expenseHeight = barHeight(row.expense, availableHeight: plotHeight)
                        let isSelected = selectedID == row.id

                        if isSelected {
                            Rectangle()
                                .fill(NativeTheme.text.opacity(0.12))
                                .frame(width: 1, height: plotHeight)
                                .position(x: centerX, y: plotHeight / 2)
                        }

                        RoundedRectangle(cornerRadius: 3)
                            .fill(NativeTheme.green.opacity(isSelected ? 1 : 0.75))
                            .frame(width: barWidth, height: incomeHeight)
                            .position(
                                x: centerX - gap / 2 - barWidth / 2,
                                y: plotHeight - incomeHeight / 2
                            )

                        RoundedRectangle(cornerRadius: 3)
                            .fill(NativeTheme.red.opacity(isSelected ? 1 : 0.75))
                            .frame(width: barWidth, height: expenseHeight)
                            .position(
                                x: centerX + gap / 2 + barWidth / 2,
                                y: plotHeight - expenseHeight / 2
                            )

                        Text(row.label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(NativeTheme.subtleText)
                            .lineLimit(1)
                            .position(x: centerX, y: plotHeight + 12)
                    }
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            selectRow(at: value.location.x, leftAxisWidth: leftAxisWidth, groupWidth: groupWidth)
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 16, coordinateSpace: .local)
                        .onChanged { value in
                            let horizontal = abs(value.translation.width)
                            let vertical = abs(value.translation.height)
                            guard horizontal > vertical * 1.25 else { return }
                            selectRow(at: value.location.x, leftAxisWidth: leftAxisWidth, groupWidth: groupWidth)
                        }
                )
            }
            .frame(height: 160)

            chartDetail
        }
        .background(NativeTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(NativeTheme.border))
    }

    private func barHeight(_ value: Double, availableHeight: CGFloat) -> CGFloat {
        max(CGFloat(value / maxValue) * availableHeight, value > 0 ? 2 : 0)
    }

    private func yPosition(_ value: Double, height: CGFloat) -> CGFloat {
        height - CGFloat(value / maxValue) * height
    }

    private func selectRow(at x: CGFloat, leftAxisWidth: CGFloat, groupWidth: CGFloat) {
        guard x >= leftAxisWidth, groupWidth > 0 else { return }
        let index = Int((x - leftAxisWidth) / groupWidth)
        guard rows.indices.contains(index) else { return }
        selectedID = rows[index].id
    }

    private func formatAxis(_ value: Double) -> String {
        if value >= 1000 {
            let rounded = value / 1000
            let hasDecimal = abs(rounded.rounded() - rounded) > 0.05
            return "\(rounded.formatted(.number.precision(.fractionLength(hasDecimal ? 1 : 0))))k"
        }
        return value.formatted(.number.precision(.fractionLength(0)))
    }

    private var chartDetail: some View {
        Group {
            if let selectedRow {
                HStack(spacing: 8) {
                    ChartDetailValue(title: "Revenus", value: selectedRow.income, color: NativeTheme.green, signed: false)
                    ChartDetailValue(title: "Dépenses", value: selectedRow.expense, color: NativeTheme.red, signed: false)
                    ChartDetailValue(
                        title: "Résultat",
                        value: selectedRow.balance,
                        color: selectedRow.balance >= 0 ? NativeTheme.gold : NativeTheme.red,
                        signed: true
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            } else {
                Text("Touchez le graphique pour voir les détails")
                    .font(.caption2)
                    .foregroundStyle(NativeTheme.subtleText)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(NativeTheme.border)
                .frame(height: 1)
        }
    }
}

private struct ChartDetailValue: View {
    var title: String
    var value: Double
    var color: Color
    var signed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(NativeTheme.subtleText)
                .textCase(.uppercase)
            Text(signed ? amountWithSign(value) : value.formatted(.currency(code: "EUR")))
                .font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CheckingHistoryRowView: View {
    var row: CheckingHistoryRow
    var variation: Double?
    var showAccountCount: Bool

    private var averageDailyExpense: Double {
        row.expense / Double(max(daysInMonth(row.monthKey), 1))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(monthLong(row.monthKey))
                        .font(.subheadline.weight(.semibold))
                    if showAccountCount && row.accountCount > 1 {
                        Text("\(row.accountCount) comptes")
                            .font(.caption2)
                            .foregroundStyle(NativeTheme.subtleText)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(amountWithSign(row.balance))
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundStyle(row.balance >= 0 ? NativeTheme.green : NativeTheme.red)
                    if let variation {
                        Text(amountWithSign(variation))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(variation >= 0 ? NativeTheme.green : NativeTheme.red)
                    }
                }
            }
            .padding(12)
            .background(NativeTheme.surface2)

            HStack(spacing: 0) {
                historyColumn("Revenus", value: row.income, color: NativeTheme.green)
                Divider().background(NativeTheme.border)
                historyColumn("Dépenses", value: row.expense, color: NativeTheme.red)
                Divider().background(NativeTheme.border)
                historyColumn("Moy./jour", value: averageDailyExpense, color: NativeTheme.text)
            }
            .padding(.vertical, 10)
        }
        .background(NativeTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(NativeTheme.border))
    }

    private func historyColumn(_ title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(NativeTheme.subtleText)
                .textCase(.uppercase)
            Text(value, format: .currency(code: "EUR"))
                .font(.system(size: 14, weight: .bold, design: .serif))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

private struct HistoryRow: View {
    var title: String
    var primary: Double
    var details: [(String, Double, Color)]

    var body: some View {
        VStack(spacing: 9) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(primary, format: .currency(code: "EUR"))
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundStyle(primary >= 0 ? NativeTheme.green : NativeTheme.red)
            }

            HStack(spacing: 12) {
                ForEach(details, id: \.0) { label, value, color in
                    HStack(spacing: 4) {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(NativeTheme.subtleText)
                        Text(value, format: .currency(code: "EUR"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(color)
                    }
                }
                Spacer()
            }
        }
        .padding(12)
        .background(NativeTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(NativeTheme.border))
    }
}

private struct EmptyStatsState: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(NativeTheme.mutedText)
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(NativeTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(NativeTheme.border))
    }
}

private struct CheckingHistoryRow: Identifiable {
    var id: String { monthKey }
    var monthKey: String
    var income: Double
    var expense: Double
    var balance: Double
    var total: Int
    var pointed: Int
    var accountCount: Int
}

private struct CheckingChartRow: Identifiable {
    var id: String
    var label: String
    var income: Double
    var expense: Double
    var balance: Double
}

private struct SavingsHistoryRow: Identifiable {
    var id: String { date }
    var date: String
    var available: Double
    var blocked: Double
    var total: Double
    var note: String?
}

private func monthTitle(_ monthKey: String, suffix: String) -> some View {
    Text("\(monthLong(monthKey)) - \(suffix)")
        .font(.caption.weight(.bold))
        .foregroundStyle(NativeTheme.subtleText)
        .textCase(.uppercase)
}

private func monthLong(_ monthKey: String) -> String {
    let parts = monthKey.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 2 else { return monthKey }

    var components = DateComponents()
    components.year = parts[0]
    components.month = parts[1]
    components.day = 2

    guard let date = Calendar(identifier: .gregorian).date(from: components) else {
        return monthKey
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "fr_FR")
    formatter.dateFormat = "LLLL yyyy"
    return formatter.string(from: date)
}

private func monthShort(_ monthKey: String) -> String {
    let parts = monthKey.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 2 else { return monthKey }

    var components = DateComponents()
    components.year = parts[0]
    components.month = parts[1]
    components.day = 2

    guard let date = Calendar(identifier: .gregorian).date(from: components) else {
        return monthKey
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "fr_FR")
    formatter.dateFormat = "LLL"
    return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
}

private func daysInMonth(_ monthKey: String) -> Int {
    let parts = monthKey.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 2 else { return 30 }

    var components = DateComponents()
    components.year = parts[0]
    components.month = parts[1]
    components.day = 1

    guard let date = Calendar(identifier: .gregorian).date(from: components),
          let range = Calendar(identifier: .gregorian).range(of: .day, in: .month, for: date) else {
        return 30
    }

    return range.count
}

private func amountWithSign(_ value: Double) -> String {
    let amount = value.formatted(.currency(code: "EUR"))
    return value > 0 ? "+\(amount)" : amount
}

private func dateLabel(_ dateString: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "fr_FR")
    formatter.dateFormat = "yyyy-MM-dd"

    guard let date = formatter.date(from: dateString) else {
        return dateString
    }

    formatter.dateFormat = "d MMM yyyy"
    return formatter.string(from: date)
}
