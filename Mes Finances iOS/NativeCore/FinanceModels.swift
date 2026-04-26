//
//  FinanceModels.swift
//  Mes Finances iOS
//
//  Native data models mirroring the current Firestore/WebApp shape.
//

import Foundation

nonisolated enum AccountType: Codable, Equatable, Identifiable {
    case checking
    case savings
    case benefit
    case other(String)

    var id: String { rawValue }

    var rawValue: String {
        switch self {
        case .checking:
            "checking"
        case .savings:
            "savings"
        case .benefit:
            "benefit"
        case .other(let value):
            value
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "checking":
            self = .checking
        case "savings":
            self = .savings
        case "benefit":
            self = .benefit
        default:
            self = .other(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated enum SavingsSubtype: String, Codable, CaseIterable, Identifiable {
    case available
    case blocked

    var id: String { rawValue }
}

nonisolated enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case income
    case expense

    var id: String { rawValue }
}

nonisolated struct FinanceAccount: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var type: AccountType
    var balance: Double
    var cardName: String?
    var savingsSubtype: SavingsSubtype?
    var dailyCap: Double?
    var overflowAccountId: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        type: AccountType = .checking,
        balance: Double = 0,
        cardName: String? = nil,
        savingsSubtype: SavingsSubtype? = nil,
        dailyCap: Double? = nil,
        overflowAccountId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.balance = balance
        self.cardName = cardName
        self.savingsSubtype = savingsSubtype
        self.dailyCap = dailyCap
        self.overflowAccountId = overflowAccountId
    }
}

nonisolated struct FinanceTransaction: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var amount: Double
    var type: TransactionType
    var date: String
    var accountId: String
    var pointed: Bool
    var isCard: Bool?
    var note: String?
    var templateMonthKey: String?
    var transferFromMonthKey: String?
    var transferPairId: String?
    var clicked: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case amount
        case type
        case date
        case accountId
        case pointed
        case isCard
        case note
        case templateMonthKey = "_tpl"
        case transferFromMonthKey = "_transferFrom"
        case transferPairId = "_virementId"
        case clicked
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        amount: Double,
        type: TransactionType,
        date: String,
        accountId: String,
        pointed: Bool = false,
        isCard: Bool? = nil,
        note: String? = nil,
        templateMonthKey: String? = nil,
        transferFromMonthKey: String? = nil,
        transferPairId: String? = nil,
        clicked: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.type = type
        self.date = date
        self.accountId = accountId
        self.pointed = pointed
        self.isCard = isCard
        self.note = note
        self.templateMonthKey = templateMonthKey
        self.transferFromMonthKey = transferFromMonthKey
        self.transferPairId = transferPairId
        self.clicked = clicked
    }
}

enum UserPreferenceValue: Codable, Equatable {
    case bool(Bool)
    case string(String)
    case number(Double)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

nonisolated struct TemplateItem: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var amount: Double
    var type: TransactionType
    var day: Int?
    var note: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        amount: Double,
        type: TransactionType,
        day: Int? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.type = type
        self.day = day
        self.note = note
    }
}

nonisolated struct AccountTemplate: Codable, Equatable {
    var even: TemplateBucket
    var odd: TemplateBucket

    init(even: TemplateBucket = TemplateBucket(), odd: TemplateBucket = TemplateBucket()) {
        self.even = even
        self.odd = odd
    }
}

nonisolated struct TemplateBucket: Codable, Equatable {
    var items: [TemplateItem]

    init(items: [TemplateItem] = []) {
        self.items = items
    }
}

nonisolated struct BenefitAllotment: Codable, Equatable {
    enum Mode: String, Codable {
        case amount
        case units
    }

    var mode: Mode
    var amount: Double?
    var count: Double?
    var unitValue: Double?
    var isCarryOver: Bool?

    enum CodingKeys: String, CodingKey {
        case mode
        case amount
        case count
        case unitValue
        case isCarryOver = "_isCarryOver"
    }
}

nonisolated struct BenefitExpense: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var amount: Double
    var date: String
    var isChecked: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case amount
        case date
        case isChecked = "_checked"
    }
}

nonisolated struct BenefitAccountData: Codable, Equatable {
    var allotments: [String: BenefitAllotment]
    var expenses: [BenefitExpense]

    init(allotments: [String: BenefitAllotment] = [:], expenses: [BenefitExpense] = []) {
        self.allotments = allotments
        self.expenses = expenses
    }
}

nonisolated struct SavingsSnapshot: Identifiable, Codable, Equatable {
    var id: String
    var date: String
    var available: Double
    var blocked: Double
    var auto: Bool?
    var note: String?
}

nonisolated struct CheckingSnapshot: Identifiable, Codable, Equatable {
    var id: String
    var date: String
    var monthKey: String
    var accountId: String
    var accountName: String
    var income: Double
    var expense: Double
    var balance: Double
    var total: Int
    var pointed: Int
    var auto: Bool?
}

nonisolated struct UserBudgetDocument: Codable, Equatable {
    var transactions: [FinanceTransaction]
    var templates: [String: AccountTemplate]
    var accounts: [FinanceAccount]
    var portfolio: [PortfolioPosition]
    var cleanupDay: Int
    var autoCleanup: Bool
    var savingsHistory: [SavingsSnapshot]
    var checkingHistory: [CheckingSnapshot]
    var savingsSnapDays: [Int]
    var savingsSnapActive: Bool
    var cardDebitDates: [String: [String: String]]
    var showFutureTx: Bool
    var benefitData: [String: BenefitAccountData]
    var uiPrefs: [String: UserPreferenceValue]

    init(
        transactions: [FinanceTransaction] = [],
        templates: [String: AccountTemplate] = [:],
        accounts: [FinanceAccount] = [FinanceAccount(name: "Compte courant")],
        portfolio: [PortfolioPosition] = [],
        cleanupDay: Int = 10,
        autoCleanup: Bool = true,
        savingsHistory: [SavingsSnapshot] = [],
        checkingHistory: [CheckingSnapshot] = [],
        savingsSnapDays: [Int] = [1, 15],
        savingsSnapActive: Bool = true,
        cardDebitDates: [String: [String: String]] = [:],
        showFutureTx: Bool = true,
        benefitData: [String: BenefitAccountData] = [:],
        uiPrefs: [String: UserPreferenceValue] = [:]
    ) {
        self.transactions = transactions
        self.templates = templates
        self.accounts = accounts
        self.portfolio = portfolio
        self.cleanupDay = cleanupDay
        self.autoCleanup = autoCleanup
        self.savingsHistory = savingsHistory
        self.checkingHistory = checkingHistory
        self.savingsSnapDays = savingsSnapDays
        self.savingsSnapActive = savingsSnapActive
        self.cardDebitDates = cardDebitDates
        self.showFutureTx = showFutureTx
        self.benefitData = benefitData
        self.uiPrefs = uiPrefs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        transactions = (try? container.decodeIfPresent([FinanceTransaction].self, forKey: .transactions)) ?? []
        templates = (try? container.decodeIfPresent([String: AccountTemplate].self, forKey: .templates)) ?? [:]
        accounts = (try? container.decodeIfPresent([FinanceAccount].self, forKey: .accounts)) ?? [FinanceAccount(name: "Compte courant")]
        portfolio = (try? container.decodeIfPresent([PortfolioPosition].self, forKey: .portfolio)) ?? []
        cleanupDay = (try? container.decodeIfPresent(Int.self, forKey: .cleanupDay)) ?? 10
        autoCleanup = (try? container.decodeIfPresent(Bool.self, forKey: .autoCleanup)) ?? true
        savingsHistory = (try? container.decodeIfPresent([SavingsSnapshot].self, forKey: .savingsHistory)) ?? []
        checkingHistory = (try? container.decodeIfPresent([CheckingSnapshot].self, forKey: .checkingHistory)) ?? []
        savingsSnapDays = (try? container.decodeIfPresent([Int].self, forKey: .savingsSnapDays)) ?? [1, 15]
        savingsSnapActive = (try? container.decodeIfPresent(Bool.self, forKey: .savingsSnapActive)) ?? true
        cardDebitDates = (try? container.decodeIfPresent([String: [String: String]].self, forKey: .cardDebitDates)) ?? [:]
        showFutureTx = (try? container.decodeIfPresent(Bool.self, forKey: .showFutureTx)) ?? true
        benefitData = (try? container.decodeIfPresent([String: BenefitAccountData].self, forKey: .benefitData)) ?? [:]
        uiPrefs = (try? container.decodeIfPresent([String: UserPreferenceValue].self, forKey: .uiPrefs)) ?? [:]
    }

    enum CodingKeys: String, CodingKey {
        case transactions
        case templates
        case accounts
        case portfolio = "portefeuille"
        case cleanupDay
        case autoCleanup
        case savingsHistory
        case checkingHistory
        case savingsSnapDays
        case savingsSnapActive
        case cardDebitDates
        case showFutureTx
        case benefitData
        case uiPrefs
    }
}

nonisolated struct PortfolioPosition: Identifiable, Codable, Equatable {
    var id: String
    var symbol: String
    var name: String?
    var quantity: Double
    var averagePrice: Double?
    var currency: String?
}
