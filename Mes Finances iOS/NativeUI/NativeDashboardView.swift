//
//  NativeDashboardView.swift
//  Mes Finances iOS
//
//  Read-only SwiftUI dashboard used as the first native parity target.
//

import SwiftUI

struct NativeDashboardView: View {
    @ObservedObject var store: NativeFinanceStore

    private var checkingAccounts: [FinanceAccount] {
        store.document.accounts.filter { $0.type == .checking }
    }

    private var savingsAccounts: [FinanceAccount] {
        store.document.accounts.filter { $0.type == .savings }
    }

    private var benefitAccounts: [FinanceAccount] {
        store.document.accounts.filter { $0.type == .benefit }
    }

    private var savingsTotals: (available: Double, blocked: Double) {
        store.savingsTotals()
    }

    var body: some View {
        ZStack {
            NativeTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    summaryStrip
                    accountSection(title: "Comptes courants", icon: "creditcard", accounts: checkingAccounts)
                    accountSection(title: "Epargne", icon: "banknote", accounts: savingsAccounts)
                    accountSection(title: "Avantages", icon: "ticket", accounts: benefitAccounts)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
        }
        .foregroundStyle(NativeTheme.text)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mes Finances")
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                    Text("\(store.document.transactions.count) transactions synchronisees")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(NativeTheme.mutedText)
                }

                Spacer()

                Image(systemName: store.isReady ? "checkmark.icloud.fill" : "icloud.slash")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(store.isReady ? NativeTheme.green : NativeTheme.subtleText)
                    .frame(width: 38, height: 38)
                    .background(NativeTheme.surface2, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryStrip: some View {
        HStack(spacing: 10) {
            SummaryTile(
                title: "Disponible",
                value: savingsTotals.available,
                color: NativeTheme.green,
                icon: "arrow.down.left"
            )
            SummaryTile(
                title: "Bloquee",
                value: savingsTotals.blocked,
                color: NativeTheme.red,
                icon: "lock"
            )
        }
    }

    private func accountSection(title: String, icon: String, accounts: [FinanceAccount]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(NativeTheme.gold)
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(accounts.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NativeTheme.subtleText)
            }

            if accounts.isEmpty {
                Text("Aucun compte")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(NativeTheme.subtleText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(NativeTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(NativeTheme.border))
            } else {
                VStack(spacing: 8) {
                    ForEach(accounts) { account in
                        AccountRowView(account: account)
                    }
                }
            }
        }
    }
}

private struct SummaryTile: View {
    var title: String
    var value: Double
    var color: Color
    var icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                Text(title)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                Spacer()
            }
            .foregroundStyle(color)

            Text(value, format: .currency(code: "EUR"))
                .font(.system(size: 22, weight: .bold, design: .serif))
                .minimumScaleFactor(0.78)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NativeTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NativeTheme.border))
    }
}

private struct AccountRowView: View {
    var account: FinanceAccount

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(NativeTheme.mutedText)
                    .lineLimit(1)
            }

            Spacer()

            if account.type == .savings {
                Text(account.balance, format: .currency(code: "EUR"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(14)
        .background(NativeTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NativeTheme.border))
    }

    private var icon: String {
        switch account.type {
        case .checking:
            "creditcard"
        case .savings:
            account.savingsSubtype == .blocked ? "lock" : "banknote"
        case .benefit:
            "ticket"
        case .other:
            "square.grid.2x2"
        }
    }

    private var color: Color {
        switch account.type {
        case .checking:
            NativeTheme.gold
        case .savings:
            account.savingsSubtype == .blocked ? NativeTheme.red : NativeTheme.green
        case .benefit:
            NativeTheme.gold
        case .other:
            NativeTheme.mutedText
        }
    }

    private var subtitle: String {
        switch account.type {
        case .checking:
            return account.cardName.map { "Carte \($0)" } ?? "Compte courant"
        case .savings:
            return account.savingsSubtype == .blocked ? "Bloquee" : "Disponible"
        case .benefit:
            if let dailyCap = account.dailyCap, dailyCap > 0 {
                return "Plafond \(dailyCap.formatted(.currency(code: "EUR"))) / jour"
            }
            return "Compte avantage"
        case .other(let value):
            return value
        }
    }
}

struct NativeDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NativeDashboardView(store: NativeFinanceStore(
            document: UserBudgetDocument(
                transactions: [
                    FinanceTransaction(title: "Salaire", amount: 3200, type: .income, date: "2026-04-01", accountId: "a1"),
                    FinanceTransaction(title: "Loyer", amount: 950, type: .expense, date: "2026-04-02", accountId: "a1")
                ],
                accounts: [
                    FinanceAccount(id: "a1", name: "Compte courant", type: .checking, cardName: "Visa Premier"),
                    FinanceAccount(id: "a2", name: "Livret A", type: .savings, balance: 8500, savingsSubtype: .available),
                    FinanceAccount(id: "a3", name: "PEL", type: .savings, balance: 24000, savingsSubtype: .blocked),
                    FinanceAccount(id: "a4", name: "Ticket Restaurant", type: .benefit, dailyCap: 25)
                ]
            ),
            isReady: true
        ))
    }
}
