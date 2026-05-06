//
//  NativeDashboardView.swift
//  Mes Finances iOS
//
//  Read-only SwiftUI dashboard used as the first native parity target.
//

import SwiftUI

struct NativeDashboardView: View {
    @ObservedObject var store: NativeFinanceStore
    @State private var selectedMonth = FinanceCalculations.currentMonthKey()
    @State private var route: NativeDashboardRoute?

    private var months: [String] {
        FinanceCalculations.visibleDashboardMonths(
            transactions: store.document.transactions,
            cardDebitDates: store.document.cardDebitDates
        )
    }

    private var checkingRows: [(account: FinanceAccount, balance: Double)] {
        store.document.accounts
            .filter { $0.type == .checking }
            .map {
                (
                    account: $0,
                    balance: FinanceCalculations.displayBalance(
                        account: $0,
                        monthKey: selectedMonth,
                        transactions: store.document.transactions,
                        cardDebitDates: store.document.cardDebitDates
                    )
                )
            }
    }

    private var savingsRows: [(account: FinanceAccount, balance: Double)] {
        store.document.accounts
            .filter { $0.type == .savings }
            .map { (account: $0, balance: $0.balance) }
    }

    private var benefitRows: [(account: FinanceAccount, balance: Double)] {
        store.document.accounts
            .filter { $0.type == .benefit }
            .map {
                (
                    account: $0,
                    balance: FinanceCalculations.benefitAvailableBalance(
                        accountId: $0.id,
                        monthKey: selectedMonth,
                        benefitData: store.document.benefitData
                    )
                )
            }
    }

    private var totalChecking: Double {
        checkingRows.reduce(0) { $0 + $1.balance }
    }

    private var totalSavings: Double {
        savingsRows.reduce(0) { $0 + $1.balance }
    }

    var body: some View {
        if route == .checkingStats {
            NativeCheckingStatsView(store: store) {
                route = nil
            }
        } else if route == .savingsStats {
            NativeSavingsStatsView(store: store) {
                route = nil
            }
        } else {
            dashboardBody
        }
    }

    private var dashboardBody: some View {
        ZStack {
            NativeTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    header
                    monthTabs
                    dashboardCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 34)
            }
        }
        .foregroundStyle(NativeTheme.text)
        .onAppear {
            if !months.contains(selectedMonth) {
                selectedMonth = FinanceCalculations.currentMonthKey()
            }
        }
        .onChange(of: months) { _, newMonths in
            if !newMonths.contains(selectedMonth), let fallback = newMonths.first {
                selectedMonth = fallback
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mes Finances")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                Text("\(store.document.transactions.count) transactions synchronisees")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(NativeTheme.mutedText)
            }

            Spacer()

            Image(systemName: store.isReady ? "checkmark.icloud.fill" : "icloud.slash")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(store.isReady ? NativeTheme.green : NativeTheme.subtleText)
                .frame(width: 36, height: 36)
                .background(NativeTheme.surface2, in: RoundedRectangle(cornerRadius: 9))
        }
    }

    private var monthTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(months, id: \.self) { month in
                    Button {
                        selectedMonth = month
                    } label: {
                        Text(monthLabel(month))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedMonth == month ? NativeTheme.gold : NativeTheme.mutedText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selectedMonth == month ? NativeTheme.gold.opacity(0.14) : NativeTheme.surface2, in: Capsule())
                            .overlay(Capsule().stroke(selectedMonth == month ? NativeTheme.gold : NativeTheme.border))
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var dashboardCard: some View {
        VStack(spacing: 0) {
            if !checkingRows.isEmpty {
                sectionHeader(symbol: "creditcard", title: "Comptes courants", total: totalChecking)
                    .padding(.bottom, 12)

                VStack(spacing: 8) {
                    ForEach(checkingRows, id: \.account.id) { row in
                        DashboardAccountRow(
                            account: row.account,
                            balance: row.balance,
                            kind: .checking
                        )
                    }
                }

                StatsButton(title: "Statistiques comptes courants", icon: "chart.bar", color: NativeTheme.green) {
                    route = .checkingStats
                }
                    .padding(.top, 8)
            }

            if !savingsRows.isEmpty {
                if !checkingRows.isEmpty {
                    DividerLine()
                        .padding(.vertical, 16)
                }

                sectionHeader(symbol: "banknote", title: "Comptes epargne", total: totalSavings)
                    .padding(.bottom, 12)

                VStack(spacing: 8) {
                    ForEach(savingsRows, id: \.account.id) { row in
                        DashboardAccountRow(
                            account: row.account,
                            balance: row.balance,
                            kind: .savings
                        )
                    }
                }

                StatsButton(title: "Statistiques epargne", icon: "chart.line.uptrend.xyaxis", color: NativeTheme.gold) {
                    route = .savingsStats
                }
                    .padding(.top, 8)
            }

            if !benefitRows.isEmpty {
                if !checkingRows.isEmpty || !savingsRows.isEmpty {
                    DividerLine()
                        .padding(.vertical, 16)
                }

                HStack(spacing: 10) {
                    Image(systemName: "ticket")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(NativeTheme.gold)
                    Text("Avantages")
                        .font(.subheadline.weight(.bold))
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.bottom, 12)

                VStack(spacing: 8) {
                    ForEach(benefitRows, id: \.account.id) { row in
                        DashboardAccountRow(
                            account: row.account,
                            balance: row.balance,
                            kind: .benefit
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(NativeTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(NativeTheme.border))
    }

    private func sectionHeader(symbol: String, title: String, total: Double) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(NativeTheme.gold)

            Text(title)
                .font(.subheadline.weight(.bold))
                .textCase(.uppercase)

            Spacer()

            Text(total, format: .currency(code: "EUR"))
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(total >= 0 ? NativeTheme.green : NativeTheme.red)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private func monthLabel(_ monthKey: String) -> String {
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
        formatter.dateFormat = "MMM yy"
        return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }
}

private enum NativeDashboardRoute {
    case checkingStats
    case savingsStats
}

private enum DashboardAccountKind {
    case checking
    case savings
    case benefit
}

private struct DashboardAccountRow: View {
    var account: FinanceAccount
    var balance: Double
    var kind: DashboardAccountKind

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(account.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    if let badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(badgeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(badgeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(badgeColor.opacity(0.28)))
                    }
                }
            }

            Spacer()

            Text(balance, format: .currency(code: "EUR"))
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundStyle(balance >= 0 ? NativeTheme.green : NativeTheme.red)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(NativeTheme.subtleText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(NativeTheme.surface2, in: RoundedRectangle(cornerRadius: 10))
    }

    private var badge: String? {
        switch kind {
        case .checking:
            return account.cardName
        case .savings:
            return account.savingsSubtype == .blocked ? "Bloquee" : "Disponible"
        case .benefit:
            return nil
        }
    }

    private var badgeColor: Color {
        switch kind {
        case .checking:
            return NativeTheme.gold
        case .savings:
            return account.savingsSubtype == .blocked ? NativeTheme.red : NativeTheme.green
        case .benefit:
            return NativeTheme.gold
        }
    }
}

private struct StatsButton: View {
    var title: String
    var icon: String
    var color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.footnote.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(color)
            .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4])).foregroundStyle(color.opacity(0.42)))
        }
    }
}

private struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(NativeTheme.border)
            .frame(height: 1)
    }
}

struct NativeDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NativeDashboardView(store: NativeFinanceStore(
            document: UserBudgetDocument(
                transactions: [
                    FinanceTransaction(title: "Salaire", amount: 3200, type: .income, date: "2026-05-01", accountId: "a1"),
                    FinanceTransaction(title: "Loyer", amount: 950, type: .expense, date: "2026-05-02", accountId: "a1"),
                    FinanceTransaction(title: "Courses", amount: 140, type: .expense, date: "2026-05-03", accountId: "a2")
                ],
                accounts: [
                    FinanceAccount(id: "a1", name: "Compte courant", type: .checking, cardName: "Visa Premier"),
                    FinanceAccount(id: "a2", name: "Compte joint", type: .checking),
                    FinanceAccount(id: "a3", name: "Livret A", type: .savings, balance: 8500, savingsSubtype: .available),
                    FinanceAccount(id: "a4", name: "PEL", type: .savings, balance: 24000, savingsSubtype: .blocked),
                    FinanceAccount(id: "a5", name: "Ticket Restaurant", type: .benefit, dailyCap: 25)
                ],
                benefitData: [
                    "a5": BenefitAccountData(
                        allotments: ["2026-05": BenefitAllotment(mode: .amount, amount: 180)],
                        expenses: [BenefitExpense(id: "e1", title: "Boulangerie", amount: 8.50, date: "2026-05-04")]
                    )
                ]
            ),
            isReady: true
        ))
    }
}
