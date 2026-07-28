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
    @State private var verticalOffset: CGFloat = 0.0
    @State private var isExpanded = false
    @State private var titleSize = 24.0
    @State private var subtitleSize = 18.0

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - View Body

    var body: some View {
        let squareImage = squareImageView(contentName: viewModel.content.title, contentAuthor: viewModel.subtitle)

        NavigationStack {
            ScrollView {
                VStack(spacing: .spacing(.xLarge)) {
                    // Rounded corners + glow are preview-only. The instance passed to the
                    // share/save buttons (and thus ImageRenderer) stays a plain square.
                    squareImage
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(
                            color: colorScheme == .dark ? .green.opacity(0.4) : .black.opacity(0.25),
                            radius: colorScheme == .dark ? 8 : 8,
                            y: colorScheme == .dark ? 0 : 4
                        )
                        .padding(.top, .spacing(.small))

                    HStack {
                        Text("Cor de fundo:")

                        Spacer()

                        backgroundPicker
                    }

                    Stepper("Tamanho do texto: \(Int(titleSize))", value: $titleSize, in: 18...38, step: 1)
                        .onChange(of: titleSize) { _, newValue in
                            subtitleSize = newValue - 6
                        }

                    DisclosureGroup {
                        Slider(value: $verticalOffset, in: -30...30, step: 1)
                        .padding(.top, 5)

                        HStack {
                            Spacer()

                            GlassButton(title: "REDEFINIR", color: .gray, compact: true) {
                                verticalOffset = 0
                            }
                        }
                    } label: {
                        Label("Ajustar posição vertical do texto", systemImage: "arrow.up.and.down")
                            .foregroundColor(.primary)
                    }
                    .disabled(viewModel.isShowingProcessingView)

                    if showTextSocialNetworkTip && !didCloseTip {
                        TipView(
                            text: "Para responder a uma publicação na sua rede social favorita, escolha Salvar Vídeo e depois adicione o vídeo à resposta a partir do app da rede.",
                            didTapClose: $didCloseTip
                        )
                        .disabled(viewModel.isShowingProcessingView)
                    }

                    ViewThatFits {
                        VStack(spacing: .spacing(.xLarge)) {
                            shareButton(view: squareImage)
                            saveVideoButton(view: squareImage)
                        }

                        HStack(spacing: .spacing(.large)) {
                            shareButton(view: squareImage)
                            saveVideoButton(view: squareImage)
                        }
                    }
                }
                .navigationTitle("Gerar Vídeo")
                .navigationBarTitleDisplayMode(.inline)
                .padding([.horizontal,.bottom], .spacing(.xLarge))
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
                        AppPersistentMemory.shared.setHasHiddenShareAsVideoTextSocialNetworkTip(to: true)
                    }
                }
            }
        }
        .overlay {
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
            showTextSocialNetworkTip = AppPersistentMemory.shared.getHasHiddenShareAsVideoTextSocialNetworkTip() == false
            viewModel.onViewAppeared()
        }
    }

    // MARK: - Subviews

    private var backgroundPicker: some View {
        HStack(spacing: .spacing(.small)) {
            ForEach(ShareAsVideoBackground.allCases) { background in
                Button {
                    viewModel.selectedBackground = background
                } label: {
                    LinearGradient(
                        colors: background.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                viewModel.selectedBackground == background ? Color.accentColor : Color.secondary.opacity(0.4),
                                lineWidth: viewModel.selectedBackground == background ? 3 : 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isShowingProcessingView)
            }
        }
    }

    private func squareImageView(contentName: String, contentAuthor: String) -> some View {
        ZStack {
            Image(viewModel.selectedBackground.imageName)
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
    VStack {
        Text("I'm no one")
    }
    .sheet(isPresented: .constant(true)) {
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
}
