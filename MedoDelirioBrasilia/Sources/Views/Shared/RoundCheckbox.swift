//
//  RoundCheckbox.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 13/02/23.
//

import SwiftUI

struct RoundCheckbox: View {
    
    @Binding var selected: Bool
    var color: Color = .gray

    @Environment(\.colorScheme) var colorScheme
    
    private let circleSize: CGFloat = 28.0
    
    var body: some View {
        ZStack {
            if selected {
                Circle()
                    .fill(.blue)
                    .frame(width: circleSize, height: circleSize)
                
                Image(systemName: "checkmark")
                    .foregroundColor(.white)
                    .font(.system(size: 15).bold())
                    .frame(width: circleSize, height: circleSize)
            } else {
                Circle()
                    .stroke(colorScheme == .dark ? .white : color.darkened(by: 0.5), lineWidth: 1.7)
                    .frame(width: circleSize, height: circleSize)
                    .opacity(colorScheme == .dark ? 1.0 : 0.7)
            }
        }
        .onTapGesture {
            selected.toggle()
        }
    }

}

#Preview {
    VStack(spacing: .spacing(.xLarge)) {
        // Unchecked
        RoundCheckbox(selected: .constant(false))

        // Checked
        RoundCheckbox(selected: .constant(true))
    }
}
