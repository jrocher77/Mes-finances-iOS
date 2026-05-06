//
//  FinanceCalculations.swift
//  Mes Finances iOS
//
//  Native financial helpers ported from the current WebApp reference.
//

import Foundation

enum FinanceCalculations {
    nonisolated static let monthKeyLength = 7

    nonisolated static func monthKey(for dateString: String) -> String {
        String(dateString.prefix(monthKeyLength))
    }

    nonisolated static func currentMonthKey(date: Date = Date(), calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        return "\(year)-\(String(format: "%02d", month))"
    }

    nonisolated static func previousMonthKey(_ monthKey: String) -> String {
        let parts = monthKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return monthKey }

        let year = parts[0]
        let month = parts[1]
        if month == 1 {
            return "\(year - 1)-12"
        }
        return "\(year)-\(String(format: "%02d", month - 1))"
    }

    nonisolated static func nextMonthKey(_ monthKey: String) -> String {
        let parts = monthKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return monthKey }

        let year = parts[0]
        let month = parts[1]
        if month == 12 {
            return "\(year + 1)-01"
        }
        return "\(year)-\(String(format: "%02d", month + 1))"
    }

    nonisolated static func isEvenMonth(_ monthKey: String) -> Bool {
        let parts = monthKey.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]) else { return false }
        return month.isMultiple(of: 2)
    }

    nonisolated static func allotmentAmount(_ allotment: BenefitAllotment?) -> Double {
        guard let allotment else { return 0 }

        switch allotment.mode {
        case .units:
            return (allotment.count ?? 0) * (allotment.unitValue ?? 0)
        case .amount:
            return allotment.amount ?? 0
        }
    }

    nonisolated static func resolveTemplateVariables(_ value: String, monthKey: String, locale: Locale = Locale(identifier: "fr_FR")) -> String {
        let parts = monthKey.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else {
            return value
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let date = Calendar(identifier: .gregorian).date(from: components) else {
            return value
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "LLLL"

        let lowerMonth = formatter.string(from: date)
        let upperMonth = lowerMonth.prefix(1).uppercased(with: locale) + lowerMonth.dropFirst()
        let paddedMonth = String(format: "%02d", month)
        let yearString = String(year)

        return value
            .replacingOccurrences(of: "$Month", with: upperMonth)
            .replacingOccurrences(of: "$month", with: lowerMonth)
            .replacingOccurrences(of: "$mm", with: paddedMonth)
            .replacingOccurrences(of: "$yyyy", with: yearString)
            .replacingOccurrences(of: "$Year", with: yearString)
            .replacingOccurrences(of: "$year", with: yearString)
    }

    nonisolated static func transactions(
        forMonth monthKey: String,
        accountId: String,
        in transactions: [FinanceTransaction],
        includeCard: Bool = true
    ) -> [FinanceTransaction] {
        transactions.filter { transaction in
            transaction.accountId == accountId &&
            Self.monthKey(for: transaction.date) == monthKey &&
            (includeCard || transaction.isCard != true)
        }
    }

    nonisolated static func signedAmount(_ transaction: FinanceTransaction) -> Double {
        switch transaction.type {
        case .income:
            return transaction.amount
        case .expense:
            return -transaction.amount
        }
    }

    nonisolated static func balance(for transactions: [FinanceTransaction]) -> Double {
        transactions.reduce(0) { total, transaction in
            total + signedAmount(transaction)
        }
    }

    nonisolated static func checkingSnapshot(
        account: FinanceAccount,
        monthKey: String,
        transactions: [FinanceTransaction],
        takenAt dateString: String
    ) -> CheckingSnapshot? {
        let regular = transactions.filter {
            Self.monthKey(for: $0.date) == monthKey &&
            $0.accountId == account.id &&
            $0.isCard != true
        }
        let card = transactions.filter {
            Self.monthKey(for: $0.date) == monthKey &&
            $0.accountId == account.id &&
            $0.isCard == true
        }

        guard !regular.isEmpty || !card.isEmpty else { return nil }

        let income = regular
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
        let regularExpense = regular
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
        let cardExpense = card.reduce(0) { total, transaction in
            total + (transaction.type == .expense ? transaction.amount : -transaction.amount)
        }
        let all = regular + card

        return CheckingSnapshot(
            id: UUID().uuidString,
            date: dateString,
            monthKey: monthKey,
            accountId: account.id,
            accountName: account.name,
            income: income,
            expense: regularExpense + cardExpense,
            balance: income - regularExpense - cardExpense,
            total: all.count,
            pointed: all.filter(\.pointed).count,
            auto: true
        )
    }

    nonisolated static func savingsTotals(accounts: [FinanceAccount]) -> (available: Double, blocked: Double) {
        let savingsAccounts = accounts.filter { $0.type == .savings }
        let available = savingsAccounts
            .filter { $0.savingsSubtype != .blocked }
            .reduce(0) { $0 + $1.balance }
        let blocked = savingsAccounts
            .filter { $0.savingsSubtype == .blocked }
            .reduce(0) { $0 + $1.balance }

        return (available, blocked)
    }

    nonisolated static func visibleDashboardMonths(
        transactions: [FinanceTransaction],
        cardDebitDates: [String: [String: String]],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [String] {
        let currentKey = currentMonthKey(date: today, calendar: calendar)
        let previousKey = previousMonthKey(currentKey)
        var months: [String] = []

        let hasNonDeferredPreviousTransactions = transactions.contains { transaction in
            guard monthKey(for: transaction.date) == previousKey else { return false }
            if transaction.isCard == true,
               let debitDate = cardDebitDates[transaction.accountId]?[previousKey],
               monthKey(for: debitDate) >= currentKey {
                return false
            }
            return true
        }

        if hasNonDeferredPreviousTransactions {
            months.append(previousKey)
        }

        let nextKey = nextMonthKey(currentKey)
        months.append(currentKey)
        months.append(nextKey)
        months.append(nextMonthKey(nextKey))
        return months
    }

    nonisolated static func displayBalance(
        account: FinanceAccount,
        monthKey: String,
        transactions: [FinanceTransaction],
        cardDebitDates: [String: [String: String]]
    ) -> Double {
        switch account.type {
        case .checking:
            let regular = transactions.filter {
                Self.monthKey(for: $0.date) == monthKey &&
                $0.accountId == account.id &&
                $0.isCard != true
            }
            let regularBalance = balance(for: regular)
            let cardTotal = transactions
                .filter {
                    $0.isCard == true &&
                    $0.accountId == account.id &&
                    Self.monthKey(for: $0.date) == monthKey
                }
                .reduce(0) { total, transaction in
                    total + (transaction.type == .expense ? transaction.amount : -transaction.amount)
                }
            let syntheticDebitTotal = (cardDebitDates[account.id] ?? [:]).reduce(0) { total, entry in
                let sourceMonth = entry.key
                let debitDate = entry.value
                guard !debitDate.isEmpty, Self.monthKey(for: debitDate) == monthKey, sourceMonth != monthKey else {
                    return total
                }

                let sourceTotal = transactions
                    .filter {
                        $0.isCard == true &&
                        $0.accountId == account.id &&
                        Self.monthKey(for: $0.date) == sourceMonth
                    }
                    .reduce(0) { sum, transaction in
                        sum + (transaction.type == .expense ? transaction.amount : -transaction.amount)
                    }
                return total + sourceTotal
            }
            return regularBalance - cardTotal - syntheticDebitTotal
        case .savings:
            return account.balance
        case .benefit:
            return 0
        case .other:
            return 0
        }
    }

    nonisolated static func benefitAvailableBalance(
        accountId: String,
        monthKey: String,
        benefitData: [String: BenefitAccountData]
    ) -> Double {
        let data = benefitData[accountId] ?? BenefitAccountData()
        let carry = carryOver(for: data, upToMonthKey: monthKey)
        let allotted = allotmentAmount(data.allotments[monthKey])
        let spent = data.expenses
            .filter { Self.monthKey(for: $0.date) == monthKey }
            .reduce(0) { $0 + $1.amount }
        return carry + allotted - spent
    }

    nonisolated static func carryOver(for accountData: BenefitAccountData, upToMonthKey monthKey: String) -> Double {
        var months = Set(accountData.allotments.keys)
        accountData.expenses.forEach { months.insert(Self.monthKey(for: $0.date)) }

        let pastMonths = months.filter { $0 < monthKey }.sorted()
        return pastMonths.reduce(0) { carry, currentMonth in
            let allotted = allotmentAmount(accountData.allotments[currentMonth])
            let spent = accountData.expenses
                .filter { Self.monthKey(for: $0.date) == currentMonth }
                .reduce(0) { $0 + $1.amount }
            return max(0, carry + allotted - spent)
        }
    }

    nonisolated static func cleanupBlockers(
        transactions: [FinanceTransaction],
        accounts: [FinanceAccount],
        cardDebitDates: [String: [String: String]],
        currentMonthKey: String
    ) -> [String] {
        let previousKey = previousMonthKey(currentMonthKey)
        var reasons: [String] = []

        let unpointedToDelete = transactions.filter { transaction in
            let transactionMonth = Self.monthKey(for: transaction.date)
            if transactionMonth >= currentMonthKey { return false }
            if transaction.isCard == true,
               let debitDate = cardDebitDates[transaction.accountId]?[transactionMonth],
               Self.monthKey(for: debitDate) >= currentMonthKey {
                return false
            }
            return !transaction.pointed && transaction.transferFromMonthKey == nil
        }

        if !unpointedToDelete.isEmpty {
            reasons.append("\(unpointedToDelete.count) transaction(s) non pointee(s) seraient supprimees.")
        }

        let missingCarry = accounts.filter { account in
            guard account.type == .checking else { return false }

            let hasPastTransaction = transactions.contains { transaction in
                guard transaction.accountId == account.id else { return false }
                let transactionMonth = Self.monthKey(for: transaction.date)
                if transactionMonth >= currentMonthKey { return false }
                if transaction.isCard == true,
                   let debitDate = cardDebitDates[account.id]?[transactionMonth],
                   Self.monthKey(for: debitDate) >= currentMonthKey {
                    return false
                }
                return true
            }

            guard hasPastTransaction else { return false }

            let hasCarry = transactions.contains { transaction in
                transaction.accountId == account.id && transaction.transferFromMonthKey == previousKey
            }
            return !hasCarry
        }

        if !missingCarry.isEmpty {
            let names = missingCarry.map(\.name).joined(separator: ", ")
            reasons.append("Le solde du mois precedent n'a pas ete reporte pour : \(names).")
        }

        return reasons
    }
}
