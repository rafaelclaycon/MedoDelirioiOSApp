//
//  ShareAsVideoView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 22/02/23.
//

import SwiftUI

struct ShareAsVideoView: View {

    @State var viewModel: ShareAsVideoViewModel
    let useLongerGeneratingVideoMessage: Bool

    @State private var didCloseTip: Bool = false
    @State private var showTextSocialNetworkTip: Bool = true
    @State private var showInstagramTip: Bool = true
    @State private var tipText: String = ""
    @State private var verticalOffset: CGFloat = 0.0
    @State private var isExpanded = false
    @State private var titleSize = 24.0
    @State private var subtitleSize = 18.0

    @ScaledMetric private var vstackSpacing: CGFloat = 22
    @ScaledMetric private var bottomPadding: CGFloat = 26

    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed & Stored Properties

    private let textSocialNetworkTip = "Para responder a uma publicação na sua rede social favorita, escolha Salvar Vídeo e depois adicione o vídeo à resposta a partir do app da rede."
    private let instagramTip = "Para fazer um Story, escolha Salvar Vídeo e depois adicione o vídeo ao seu Story a partir do Instagram."

    // MARK: - Computed Properties

    private var isSquare: Bool {
        viewModel.selectedSocialNetwork == IntendedVideoDestination.twitter.rawValue
    }

    private var is9By16: Bool {
        !isSquare
    }

    // MARK: - View Body

    var body: some View {
        let squareImage = squareImageView(contentName: viewModel.content.title, contentAuthor: viewModel.subtitle)
        let nineBySixteenImage = nineBySixteenImageView(contentName: viewModel.content.title, contentAuthor: viewModel.subtitle)
        
        ZStack {
            NavigationView {
                ScrollView {
                    VStack(spacing: vstackSpacing) {
                        // The 9:16 option is hidden for now, so only the square format is offered.
                        // Picker(selection: $viewModel.selectedSocialNetwork, label: Text("Rede social")) {
                        //     Text("Quadrado").tag(0)
                        //     Text("9 : 16").tag(1)
                        // }
                        // .pickerStyle(SegmentedPickerStyle())
                        // .disabled(viewModel.isShowingProcessingView)
                        // .onChange(of: viewModel.selectedSocialNetwork) {
                        //     tipText = viewModel.selectedSocialNetwork == IntendedVideoDestination.twitter.rawValue ? textSocialNetworkTip : instagramTip
                        // }

                        if viewModel.selectedSocialNetwork == 0 {
                            squareImage
                        } else {
                            nineBySixteenImage
                        }

                        if isSquare {
                            Stepper("Tamanho do texto: \(Int(titleSize))", value: $titleSize, in: 18...38, step: 1)
                                .onChange(of: titleSize) { _, newValue in
                                    subtitleSize = newValue - 6
                                }
                        }
                        
                        if is9By16 {
                            Toggle("Incluir aviso Ligue o Som", isOn: $viewModel.includeSoundWarning)
                                .disabled(viewModel.isShowingProcessingView)
                        }
                        
                        DisclosureGroup {
                            Slider(value: $verticalOffset, in: -30...30, step: 1)
                            .padding(.top, 5)
                            
                            HStack {
                                Spacer()
                                
                                Button("REDEFINIR") {
                                    verticalOffset = 0
                                }
                                .miniButton(colored: .gray)
                            }
                        } label: {
                            Label("Ajustar posição vertical do texto", systemImage: "arrow.up.and.down")
                                .foregroundColor(.primary)
                        }
                        .disabled(viewModel.isShowingProcessingView)
                        
                        if viewModel.selectedSocialNetwork == IntendedVideoDestination.twitter.rawValue && showTextSocialNetworkTip {
                            TipView(text: $tipText, didTapClose: $didCloseTip)
                                .disabled(viewModel.isShowingProcessingView)
                        } else if viewModel.selectedSocialNetwork == IntendedVideoDestination.instagramTikTok.rawValue && showInstagramTip {
                            TipView(text: $tipText, didTapClose: $didCloseTip)
                                .disabled(viewModel.isShowingProcessingView)
                        }
                        
                        if UIDevice.isiPhone {
                            VStack(spacing: vstackSpacing) {
                                if viewModel.selectedSocialNetwork == 0 {
                                    shareButton(view: squareImage)
                                    saveVideoButton(view: squareImage)
                                } else {
                                    shareButton(view: nineBySixteenImage)
                                    saveVideoButton(view: nineBySixteenImage)
                                }
                            }
                        } else {
                            HStack(spacing: 20) {
                                if viewModel.selectedSocialNetwork == 0 {
                                    shareButton(view: squareImage)

                                    saveVideoButton(view: squareImage)
                                } else {
                                    shareButton(view: nineBySixteenImage)

                                    saveVideoButton(view: nineBySixteenImage)
                                }
                            }
                        }
                    }
                    .navigationTitle("Gerar Vídeo")
                    .navigationBarTitleDisplayMode(.inline)
                    .padding(.horizontal, 25)
                    .padding(.bottom, bottomPadding)
                    .navigationBarItems(leading:
                        CloseButton {
                            dismiss()
                        }
                    )
                    .alert(isPresented: $viewModel.showAlert) {
                        Alert(title: Text(viewModel.alertTitle), message: Text(viewModel.alertMessage), dismissButton: .default(Text("OK")))
                    }
                    .onChange(of: viewModel.shouldCloseView) {
                        if viewModel.shouldCloseView {
                            dismiss()
                        }
                    }
                    .onChange(of: didCloseTip) {
                        if didCloseTip {
                            if viewModel.selectedSocialNetwork == IntendedVideoDestination.twitter.rawValue {
                                showTextSocialNetworkTip = false
                                AppPersistentMemory.shared.setHasHiddenShareAsVideoTextSocialNetworkTip(to: true)
                                self.didCloseTip = false
                            } else if viewModel.selectedSocialNetwork == IntendedVideoDestination.instagramTikTok.rawValue {
                                showInstagramTip = false
                                AppPersistentMemory.shared.setHasHiddenShareAsVideoInstagramTip(to: true)
                                self.didCloseTip = false
                            }
                        }
                    }
                }
            }
            
            if viewModel.isShowingProcessingView {
                if useLongerGeneratingVideoMessage {
                    ProcessingView(message: Shared.ShareAsVideo.generatingVideoLongMessage, progressViewYOffset: -27, progressViewWidth: 270, messageYOffset: 30)
                        .padding(.bottom)
                } else {
                    ProcessingView(message: Shared.ShareAsVideo.generatingVideoShortMessage)
                        .padding(.bottom)
                }
            }
        }
        .onAppear {
            tipText = textSocialNetworkTip
            showTextSocialNetworkTip = AppPersistentMemory.shared.getHasHiddenShareAsVideoTextSocialNetworkTip() == false
            showInstagramTip = AppPersistentMemory.shared.getHasHiddenShareAsVideoInstagramTip() == false
            viewModel.onViewAppeared()
        }
    }

    // MARK: - Subviews

    private func squareImageView(contentName: String, contentAuthor: String) -> some View {
        ZStack {
            Image("square_video_background")
                .resizable()
                .frame(width: 350, height: 350)
            
            HStack {
                VStack(alignment: .leading, spacing: .spacing(.medium)) {
                    Text(contentName)
                        .fontDesign(.rounded)
                        .fontWeight(.black)
                        .font(.system(size: titleSize))
                        .foregroundColor(.black)

                    if !contentAuthor.isEmpty {
                        Text(contentAuthor)
                            .fontDesign(.rounded)
                            .font(.system(size: subtitleSize))
                            .foregroundColor(.black)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, .spacing(.xLarge))
            .padding(.bottom)
            .offset(y: verticalOffset)
        }
        .frame(width: 350, height: 350)
    }
    
    private func nineBySixteenImageView(contentName: String, contentAuthor: String) -> some View {
        ZStack {
            Image(viewModel.includeSoundWarning ? "9_16_video_background_with_warning" : "9_16_video_background_no_warning")
                .resizable()
                .scaledToFit()
                .frame(height: 350)
            
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    Text(contentName)
                        .font(Font.system(size: 14))
                        .bold()
                        .foregroundColor(.black)

                    if !contentAuthor.isEmpty {
                        Text(contentAuthor)
                            .font(Font.system(size: 12))
                            .foregroundColor(.black)
                    }
                }
                Spacer()
            }
            .padding(.leading, 12)
            .padding(.trailing)
            .padding(.bottom)
            .offset(y: verticalOffset)
        }
        .frame(width: 196, height: 350)
    }
    
    @ViewBuilder
    func shareButton(view: some View) -> some View {
        let button = Button {
            Task {
                let renderer = ImageRenderer(content: view)
                renderer.scale = viewModel.selectedSocialNetwork == 0 ? 3.0 : 4.0
                guard let image = renderer.uiImage else { return } // TODO: Show an error?
                await viewModel.onShareVideoSelected(image)
            }
        } label: {
            HStack(spacing: 15) {
                Spacer()
                
                Image(systemName: "square.and.arrow.up")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 25)
                
                Text("Compartilhar")
                    .font(.headline)
                
                Spacer()
            }
        }

        if #available(iOS 26, *) {
            button
                .controlSize(.large)
                .buttonStyle(.glass)
                .disabled(viewModel.isShowingProcessingView)
        } else {
            button
                .borderedButton(colored: .accentColor)
                .disabled(viewModel.isShowingProcessingView)
        }
    }
    
    @ViewBuilder
    func saveVideoButton(view: some View) -> some View {
        let button = Button {
            Task {
                let renderer = ImageRenderer(content: view)
                renderer.scale = viewModel.selectedSocialNetwork == 0 ? 3.0 : 4.0
                guard let image = renderer.uiImage else { return } // TODO: Show an error?
                await viewModel.onSaveVideoSelected(image)
            }
        } label: {
            HStack(spacing: 15) {
                Spacer()
                
                Image(systemName: "square.and.arrow.down")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 25)
                
                Text("Salvar Vídeo")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
        }

        if #available(iOS 26, *) {
            button
                .controlSize(.large)
                .buttonStyle(.glassProminent)
                .disabled(viewModel.isShowingProcessingView)
        } else {
            button
                .borderedProminentButton(colored: .accentColor)
                .disabled(viewModel.isShowingProcessingView)
        }
    }
}

// MARK: - Preview

#Preview {
    ShareAsVideoView(
        viewModel: ShareAsVideoViewModel(
            content: AnyEquatableMedoContent(Sound(title: "Você é maluco ou você é idiota, companheiro?")),
            subtitle: "Lula (Cristiano Botafogo)",
            contentType: .videoFromSound,
            result: .constant(ShareAsVideoResult(videoFilepath: "", contentId: "", exportMethod: .saveAsVideo))
        ),
        useLongerGeneratingVideoMessage: false
    )
}
