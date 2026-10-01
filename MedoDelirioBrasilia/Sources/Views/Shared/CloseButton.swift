//
//  CloseButton.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 07/09/25.
//

import SwiftUI

struct CloseButton: View {

    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "xmark")
        }
    }
}

#Preview {
    CloseButton(action: {})
}
