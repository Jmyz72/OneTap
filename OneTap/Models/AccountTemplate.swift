//
//  AccountTemplate.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import Foundation
import SwiftUI

struct AccountTemplate: Identifiable {
    let id = UUID()
    let name: String
    let type: AccountType
    let institution: String
    let iconName: String? // Custom icon if needed, else use type default
    
    // Helper to get the display icon
    var displayIcon: String {
        iconName ?? type.icon
    }
}

struct AccountTemplateGroup: Identifiable {
    let id = UUID()
    let group: AccountGroup
    let templates: [AccountTemplate]
}

extension AccountTemplate {
    static let allGroups: [AccountTemplateGroup] = [
        AccountTemplateGroup(group: .funding, templates: [
            AccountTemplate(name: "Cash", type: .cash, institution: "", iconName: "banknote"),
            
            // Major Banks
            AccountTemplate(name: "Maybank", type: .savings, institution: "Maybank", iconName: "MaybankLogo"),
            AccountTemplate(name: "CIMB", type: .savings, institution: "CIMB", iconName: "CimbBankLogo"),
            AccountTemplate(name: "Public Bank", type: .savings, institution: "Public Bank", iconName: "PublicBankLogo"),
            AccountTemplate(name: "RHB Bank", type: .savings, institution: "RHB", iconName: "RHBBankLogo"),
            AccountTemplate(name: "Hong Leong Bank", type: .savings, institution: "HLB", iconName: "HongLeongBankLogo"),
            AccountTemplate(name: "AmBank", type: .savings, institution: "AmBank", iconName: "AmBankLogo"),
            AccountTemplate(name: "Alliance Bank", type: .savings, institution: "Alliance", iconName: "AllianceBankLogo"),
            AccountTemplate(name: "Al-Rajhi Bank", type: .savings, institution: "Al-Rajhi", iconName: "AlrajhiBankLogo"),
            
            // Digital Banks
            AccountTemplate(name: "GX Bank", type: .savings, institution: "GX Bank", iconName: "GXBankLogo"),
            AccountTemplate(name: "Aeon Bank", type: .savings, institution: "Aeon Bank", iconName: "AeonBankLogo"),
            AccountTemplate(name: "Boost Bank", type: .savings, institution: "Boost", iconName: "BoostBank"),
            AccountTemplate(name: "Ryt Bank", type: .savings, institution: "Ryt", iconName: "rytlogo"),
            
            // E-Wallets & Others
            AccountTemplate(name: "TNG eWallet", type: .savings, institution: "Touch 'n Go", iconName: "TNGE-walletLogo"),
            AccountTemplate(name: "GrabPay", type: .savings, institution: "Grab", iconName: "GrabPayLogo"),
            AccountTemplate(name: "PayPal", type: .savings, institution: "PayPal", iconName: "PayPalLogo"),
            AccountTemplate(name: "General Bank", type: .savings, institution: "", iconName: nil)
        ]),
        
        AccountTemplateGroup(group: .financial, templates: [
            // Retirement & National Savings
            AccountTemplate(name: "KWSP (EPF)", type: .investment, institution: "EPF", iconName: "e.circle.fill"),
            AccountTemplate(name: "PTPTN (SSPN)", type: .investment, institution: "PTPTN", iconName: "graduationcap.fill"),
            AccountTemplate(name: "Tabung Haji", type: .investment, institution: "Tabung Haji", iconName: "building.2.fill"),
            AccountTemplate(name: "ASB / ASNB", type: .investment, institution: "ASNB", iconName: "chart.pie.fill"),
            
            // Modern Investment & Robo-Advisors
            AccountTemplate(name: "Versa", type: .investment, institution: "Versa", iconName: "v.circle.fill"),
            AccountTemplate(name: "KDI", type: .investment, institution: "Kenanga", iconName: "k.circle.fill"),
            AccountTemplate(name: "Wahed Invest", type: .investment, institution: "Wahed", iconName: "w.circle.fill"),
            AccountTemplate(name: "Raiz", type: .investment, institution: "Raiz", iconName: "r.square.fill"),
            AccountTemplate(name: "Akru", type: .investment, institution: "Akru", iconName: "a.square.fill"),
            AccountTemplate(name: "StashAway", type: .investment, institution: "StashAway", iconName: "chart.bar.fill"),
            
            // Crypto & Trading
            AccountTemplate(name: "Moomoo", type: .investment, institution: "Moomoo", iconName: "chart.xyaxis.line"),
            AccountTemplate(name: "Luno", type: .investment, institution: "Luno", iconName: "bitcoinsign.circle.fill"),
            AccountTemplate(name: "Rakuten Trade", type: .investment, institution: "Rakuten", iconName: "r.circle.fill")
        ]),
        
        AccountTemplateGroup(group: .credit, templates: [
            AccountTemplate(name: "Credit Card", type: .creditCard, institution: "", iconName: "creditcard.fill"),
            AccountTemplate(name: "SPayLater", type: .bnpl, institution: "Shopee", iconName: "bag.fill"),
            AccountTemplate(name: "GrabPay Later", type: .bnpl, institution: "Grab", iconName: "car.fill"),
            AccountTemplate(name: "Atome", type: .bnpl, institution: "Atome", iconName: "a.circle.fill")
        ])
    ]
}
