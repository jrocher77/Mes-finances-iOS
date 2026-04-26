//
//  NativeFinanceStore.swift
//  Mes Finances iOS
//
//  Observable native state container for the progressive SwiftUI migration.
//

import Foundation
import Combine

@MainActor
final class NativeFinanceStore: ObservableObject {
    @Published private(set) var document: UserBudgetDocument
    @Published private(set) var isReady: Bool
    @Published var lastErrorMessage: String?

    init(document: UserBudgetDocument? = nil, isReady: Bool = false) {
        self.document = document ?? UserBudgetDocument()
        self.isReady = isReady
    }

    func replaceDocument(_ document: UserBudgetDocument) {
        self.document = document.normalized()
        isReady = true
    }

    func markReady() {
        isReady = true
    }

    func addTransaction(_ transaction: FinanceTransaction) {
        document.transactions.insert(transaction, at: 0)
    }

    func updateTransaction(id: String, updates: (inout FinanceTransaction) -> Void) {
        guard let index = document.transactions.firstIndex(where: { $0.id == id }) else { return }
        updates(&document.transactions[index])
        document.transactions[index].templateMonthKey = nil
    }

    func removeTransaction(id: String) {
        document.transactions.removeAll { $0.id == id }
    }

    func togglePointed(transactionId: String) {
        updateTransaction(id: transactionId) { transaction in
            transaction.pointed.toggle()
        }
    }

    func addAccount(_ account: FinanceAccount) {
        guard document.accounts.count < 15 else { return }
        document.accounts.append(account.normalized())
    }

    func updateAccount(id: String, updates: (inout FinanceAccount) -> Void) {
        guard let index = document.accounts.firstIndex(where: { $0.id == id }) else { return }
        updates(&document.accounts[index])
        document.accounts[index] = document.accounts[index].normalized()
    }

    func removeAccount(id: String) {
        guard document.accounts.count > 1 else { return }
        document.accounts.removeAll { $0.id == id }
        document.transactions.removeAll { $0.accountId == id }
        document.templates[id] = nil
        document.benefitData[id] = nil
        document.cardDebitDates[id] = nil
    }

    func moveAccount(id: String, direction: Int) {
        guard
            let account = document.accounts.first(where: { $0.id == id }),
            let currentIndexInGroup = document.accounts.filter({ $0.type == account.type }).firstIndex(where: { $0.id == id })
        else { return }

        var group = document.accounts.filter { $0.type == account.type }
        let nextIndex = currentIndexInGroup + direction
        guard group.indices.contains(nextIndex) else { return }

        group.swapAt(currentIndexInGroup, nextIndex)
        document.accounts = document.accounts.map { existing in
            existing.type == account.type ? group.removeFirst() : existing
        }
    }

    func applyTemplate(monthKey: String, accountId: String) {
        let template = document.templates[accountId] ?? AccountTemplate()
        let bucket = FinanceCalculations.isEvenMonth(monthKey) ? template.even : template.odd
        let items = bucket.items
        guard !items.isEmpty else { return }

        let alreadyApplied = document.transactions.contains {
            $0.templateMonthKey == monthKey && $0.accountId == accountId
        }
        guard !alreadyApplied else { return }

        let generated = items.map { item in
            let day = String(format: "%02d", item.day ?? 1)
            return FinanceTransaction(
                title: FinanceCalculations.resolveTemplateVariables(item.title, monthKey: monthKey),
                amount: item.amount,
                type: item.type,
                date: "\(monthKey)-\(day)",
                accountId: accountId,
                note: item.note.map { FinanceCalculations.resolveTemplateVariables($0, monthKey: monthKey) },
                templateMonthKey: monthKey
            )
        }

        document.transactions.insert(contentsOf: generated, at: 0)
    }

    func setCardDebitDate(accountId: String, monthKey: String, date: String) {
        var accountDates = document.cardDebitDates[accountId] ?? [:]
        accountDates[monthKey] = date
        document.cardDebitDates[accountId] = accountDates
    }

    func clearCardDebitDate(accountId: String, monthKey: String) {
        document.cardDebitDates[accountId]?[monthKey] = nil
    }

    func cleanupBlockers(currentMonthKey: String? = nil) -> [String] {
        FinanceCalculations.cleanupBlockers(
            transactions: document.transactions,
            accounts: document.accounts,
            cardDebitDates: document.cardDebitDates,
            currentMonthKey: currentMonthKey ?? FinanceCalculations.currentMonthKey()
        )
    }

    func savingsTotals() -> (available: Double, blocked: Double) {
        FinanceCalculations.savingsTotals(accounts: document.accounts)
    }
}

private extension UserBudgetDocument {
    func normalized() -> UserBudgetDocument {
        var copy = self
        copy.accounts = accounts.map { $0.normalized() }
        copy.transactions = transactions.map { transaction in
            var copy = transaction
            copy.pointed = transaction.pointed
            return copy
        }
        return copy
    }
}

private extension FinanceAccount {
    func normalized() -> FinanceAccount {
        var copy = self
        if copy.type == .savings && copy.savingsSubtype == nil {
            copy.savingsSubtype = .available
        }
        return copy
    }
}
