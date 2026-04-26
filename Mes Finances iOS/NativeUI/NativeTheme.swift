//
//  NativeTheme.swift
//  Mes Finances iOS
//
//  Visual constants matching the current WebApp direction.
//

import SwiftUI

enum NativeTheme {
    static let background = Color(red: 0.055, green: 0.059, blue: 0.075)
    static let surface = Color(red: 0.086, green: 0.094, blue: 0.122)
    static let surface2 = Color(red: 0.118, green: 0.125, blue: 0.161)
    static let border = Color.white.opacity(0.08)
    static let gold = Color(red: 0.788, green: 0.659, blue: 0.298)
    static let green = Color(red: 0.298, green: 0.686, blue: 0.510)
    static let red = Color(red: 0.878, green: 0.361, blue: 0.361)
    static let text = Color(red: 0.941, green: 0.925, blue: 0.894)
    static let mutedText = text.opacity(0.52)
    static let subtleText = text.opacity(0.32)
}
