//
//  ElectionLiveBannerView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 24/09/26.
//

import SwiftUI

/// Entry point for the election Live Activity. Only shown when `ElectionLiveActivityManager`
/// says the feature is available, so it can't be dismissed: the server takes it down after
/// the count.
struct ElectionLiveBannerView: View {

    @Binding var toast: Toast?

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var isRunning = ElectionLiveActivityManager.shared.isRunning
    @State private var isWorking = false
    @State private var showActivitiesDisabledAlert = false

    private var textColor: Color {
        colorScheme == .dark ? .primary : .darkestGreen
    }

    private var message: String {
        isRunning
            ? "Você está acompanhando a apuração na Tela Bloqueada e na Dynamic Island."
            : "Acompanhe a apuração para Presidente em tempo real na Tela Bloqueada e na Dynamic Island, com dados oficiais do TSE."
    }

    private var buttonTitle: String {
        isRunning ? "Parar de Acompanhar" : "Acompanhar ao Vivo"
    }

    // MARK: - View Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing(.medium)) {
            Label("Apuração ao Vivo", systemImage: "checkmark.seal")
                .foregroundStyle(textColor)
                .bold()

            Text(message)
                .foregroundStyle(textColor)
                .opacity(0.8)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            if #available(iOS 26, *) {
                Button {
                    Task { await onButtonSelected() }
                } label: {
                    buttonLabel
                        .foregroundStyle(textColor)
                        .padding(.vertical, .spacing(.small))
                        .frame(maxWidth: .infinity)
                        .glassEffect(.regular.interactive())
                }
                .disabled(isWorking)
            } else {
                Button {
                    Task { await onButtonSelected() }
                } label: {
                    buttonLabel
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, .spacing(.xxSmall))
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking)
            }
        }
        .padding(.all, 20)
        .background {
            RoundedRectangle(cornerRadius: 15)
                .foregroundColor(.green)
                .opacity(colorScheme == .dark ? 0.3 : 0.15)
        }
        // The user can end the activity from the Lock Screen while the app is in the background.
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                isRunning = ElectionLiveActivityManager.shared.isRunning
            }
        }
        .alert("Atividades ao Vivo Desativadas", isPresented: $showActivitiesDisabledAlert) {
            Button("Abrir Ajustes") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Ative as Atividades ao Vivo nos Ajustes do sistema para acompanhar a apuração na Tela Bloqueada.")
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var buttonLabel: some View {
        if isWorking {
            ProgressView()
        } else {
            Text(buttonTitle)
                .font(.callout)
                .bold()
        }
    }

    // MARK: - Functions

    private func onButtonSelected() async {
        isWorking = true
        defer { isWorking = false }

        let manager = ElectionLiveActivityManager.shared
        if isRunning {
            await manager.endAll()
            await AnalyticsService().send(originatingScreen: "ElectionLiveBanner", action: "election_live_activity_stopped")
        } else {
            do {
                try await manager.start()
                await AnalyticsService().send(originatingScreen: "ElectionLiveBanner", action: "election_live_activity_started")
            } catch ElectionLiveActivityManager.StartError.activitiesDisabled {
                showActivitiesDisabledAlert = true
            } catch let error as ElectionLiveActivityManager.StartError {
                toast = Toast(message: error.localizedDescription, type: .warning)
            } catch {
                toast = Toast(message: "Não foi possível iniciar o acompanhamento da apuração. Tente novamente.", type: .warning)
            }
        }
        isRunning = manager.isRunning
    }
}

// MARK: - Preview

#Preview {
    ElectionLiveBannerView(toast: .constant(nil))
        .padding()
}
