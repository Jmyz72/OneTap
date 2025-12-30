//
//  AccountIconView.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI

struct AccountIconView: View {
    let iconName: String
    let color: Color
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size * 2.2, height: size * 2.2)
            
            if UIImage(named: iconName) != nil {
                // It's a custom asset
                Image(iconName)
                    .resizable()
                    .scaledToFill() // Fill the frame
                    .frame(width: size * 2.2, height: size * 2.2) // Match background size
                    .clipShape(Circle()) // Clip to circle
            } else {
                // Fallback to SF Symbol (keep original sizing for symbols)
                Image(systemName: iconName)
                    .font(.system(size: size))
                    .foregroundColor(color)
            }
        }
    }
}