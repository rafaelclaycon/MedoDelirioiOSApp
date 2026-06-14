//
//  LargeCreatorView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 13/04/23.
//

import SwiftUI

struct LargeCreatorView: View {
    
    @Binding var showLargeCreatorImage: Bool
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(0.6)
                .onTapGesture {
                    withAnimation {
                        showLargeCreatorImage = false
                    }
                }
            
            VStack {
                Image("creator_large")
                    .resizable()
                    .scaledToFit()
                    .clipShape(Circle())
                    .frame(maxWidth: UIDevice.deviceType == .iPhone ? .infinity : 500)
                    .onTapGesture {
                        withAnimation {
                            showLargeCreatorImage = false
                        }
                    }
            }
        }
        .transition(.opacity)
        .ignoresSafeArea()
    }
}

struct LargeCreatorView_Previews: PreviewProvider {
    
    static var previews: some View {
        LargeCreatorView(showLargeCreatorImage: .constant(true))
    }
}
