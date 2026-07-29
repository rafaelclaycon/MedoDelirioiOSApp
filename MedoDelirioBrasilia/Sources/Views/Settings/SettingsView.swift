//
//  SettingsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 21/05/22.
//

import SwiftUI

struct SettingsView: View {

    @State private var path = NavigationPath()

    @State private var showExplicitSounds: Bool = UserSettings().getShowExplicitContent()

    @State private var showChangeAppIcon: Bool = UIDevice.deviceType != .mac

    @State private var showAskForMoneyView: Bool = false
    @State private var showOnboardingPreview: Bool = false
    @State private var showTranscriptsWhatsNewPreview: Bool = false
    @State private var showShareClipWhatsNewPreview: Bool = false
    @State private var toast: Toast?
    @State private var donors: [Donor]? = nil

    private let apiClient: APIClientProtocol

    // MARK: - Environment

    @Environment(SettingsHelper.self) private var helper
    @Environment(TranscriptDownloadService.self) private var transcriptDownloadService
    @Environment(\.dismiss) var dismiss

    // MARK: - Initializer

    init(
        apiClient: APIClientProtocol
    ) {
        self.apiClient = apiClient
    }

    // MARK: - View Body

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    Toggle("Exibir conteúdo sensível", isOn: $showExplicitSounds)
                        .onChange(of: showExplicitSounds) {
                            UserSettings().setShowExplicitContent(to: showExplicitSounds)
                            helper.updateSoundsList = true
                        }
                } footer: {
                    Text("Alguns conteúdos contam com muitos palavrões. Ao marcar essa opção, você concorda que tem mais de 18 anos e que deseja ver esses conteúdos.")
                }

                if CommandLine.arguments.contains("-SHOW_MORE_DEV_OPTIONS") {
                    Section {
                        NavigationLink(value: SettingsDestination.devOptions) {
                            Label {
                                Text("Dev Options")
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "hammer")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                Section {
                    NavigationLink(value: SettingsDestination.notificationSettings) {
                        Label {
                            Text("Notificações")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "bell.badge")
                                .foregroundColor(.red)
                        }
                    }

                    NavigationLink(value: SettingsDestination.storageSettings) {
                        Label {
                            Text("Armazenamento")
                        } icon: {
                            Image(systemName: "internaldrive")
                                .foregroundColor(.gray)
                        }
                    }

                    NavigationLink(value: SettingsDestination.privacySettings) {
                        Label {
                            Text("Privacidade")
                        } icon: {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.blue)
                        }
                    }

                    if showChangeAppIcon {
                        NavigationLink(value: SettingsDestination.changeAppIcon) {
                            Label {
                                Text("Ícone do app")
                            } icon: {
                                Image(systemName: "app")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }

                Section("Problemas, sugestões e pedidos") {
                    Button {
                        Task {
                            await Mailman.openDefaultEmailApp(
                                subject: Shared.issueSuggestionEmailSubject,
                                body: Shared.issueSuggestionEmailBody
                            )
                        }
                    } label: {
                        Label("Entrar em contato por e-mail", systemImage: "envelope")
                    }
                    .foregroundStyle(Color.blue)
                }

                if showAskForMoneyView || CommandLine.arguments.contains("-FORCE_SHOW_HELP_THE_APP") {
                    HelpTheAppView(donors: donors, toast: $toast, apiClient: APIClient.shared)
                }

//                Section("Outros apps do mesmo desenvolvedor") {
//                    Button {
//                        OpenUtility.open(link: "https://apps.apple.com/br/app/d%C3%B9n-private-link-storage/id6627333601")
//                    } label: {
//                        HStack(spacing: .spacing(.small)) {
//                            Image("DunAppIcon")
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 40, height: 40)
//                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
//
//                            VStack(alignment: .leading, spacing: 2) {
//                                Text("Dùn — Guarde Seus Links")
//                                    .font(.subheadline.weight(.semibold))
//                                    .foregroundStyle(.primary)
//
//                                Text("Seus links, só seus.")
//                                    .font(.caption)
//                                    .foregroundStyle(.secondary)
//                            }
//
//                            Spacer()
//
//                            Text("Grátis")
//                                .font(.caption.weight(.medium))
//                                .foregroundStyle(.blue)
//                                .padding(.horizontal, .spacing(.xSmall))
//                                .padding(.vertical, .spacing(.xxxSmall))
//                                .background {
//                                    Capsule()
//                                        .fill(Color.blue.opacity(0.12))
//                                }
//                        }
//                    }
//                }

                Section("Sobre") {
                    Text("Versão \(Versioneer.appVersion) Build \(Versioneer.buildVersionNumber)")

                    Button {
                        Task {
                            OpenUtility.open(link: "https://github.com/rafaelclaycon/MedoDelirioBrasilia")
                            await SettingsView.sendAnalytics(for: "didTapGitHubButton")
                        }
                    } label: {
                        HStack {
                            Label("Ver código fonte", systemImage: "chevron.left.forwardslash.chevron.right")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    AuthorCreditsView()

//                    Button {
//                        OpenUtility.open(link: "https://apps.apple.com/br/app/d%C3%B9n-private-link-storage/id6627333601")
//                    } label: {
//                        HStack {
//                            Label("Experimente Dùn, meu outro app", systemImage: "app")
//                            Spacer()
//                            Image(systemName: "arrow.up.right")
//                                .font(.footnote.weight(.semibold))
//                                .foregroundStyle(.tertiary)
//                        }
//                    }
//                    .foregroundStyle(.purple)
                }

                Section {
                    Button {
                        path.append(SettingsDestination.diagnostics)
                    } label: {
                        HStack {
                            Label("Diagnóstico", systemImage: "stethoscope")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Configurações")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await onViewAppeared()
                }
            }
            .toast($toast)
            .sheet(isPresented: $showOnboardingPreview) {
                OnboardingView()
            }
            .sheet(isPresented: $showTranscriptsWhatsNewPreview) {
                IntroducingTranscriptsView(appMemory: AppPersistentMemory.shared)
                    .environment(transcriptDownloadService)
            }
            .sheet(isPresented: $showShareClipWhatsNewPreview) {
                IntroducingShareClipView(appMemory: AppPersistentMemory.shared)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        path.append(SettingsDestination.help)
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .changeAppIcon:
                    ChangeAppIconView()

                case .devOptions:
                    DevOptionsView(
                        showOnboardingPreview: $showOnboardingPreview,
                        showTranscriptsWhatsNewPreview: $showTranscriptsWhatsNewPreview,
                        showShareClipWhatsNewPreview: $showShareClipWhatsNewPreview
                    )

                case .diagnostics:
                    DiagnosticsView(
                        database: LocalDatabase.shared,
                        analyticsService: AnalyticsService()
                    )

                case .help:
                    HelpView()

                case .notificationSettings:
                    NotificationsSettingsView()
                    
                case .privacySettings:
                    PrivacySettingsView()

                case .storageSettings:
                    StorageSettingsView()
                }
            }
        }
    }

    // MARK: - Functions

    private func onViewAppeared() async {
        showAskForMoneyView = await apiClient.displayAskForMoneyView(appVersion: Versioneer.appVersion)
        let copy = await apiClient.getDonorNames()?.shuffled()
        self.donors = copy
    }

    private static func sendAnalytics(for action: String) async {
        await AnalyticsService().send(
            originatingScreen: "SettingsView",
            action: action
        )
    }
}

enum SettingsDestination: Hashable {

    case changeAppIcon
    case devOptions
    case diagnostics
    case help
    case notificationSettings
    case privacySettings
    case storageSettings
}

// MARK: - Dev Options

struct DevOptionsView: View {

    @Binding var showOnboardingPreview: Bool
    @Binding var showTranscriptsWhatsNewPreview: Bool
    @Binding var showShareClipWhatsNewPreview: Bool

    @State private var supportSheetPreviewContext: StandaloneSupportView.Context?

    var body: some View {
        Form {
            FeatureFlagsSettingsView()

            Section("Tools") {
                Button("Reexibir Onboarding") {
                    showOnboardingPreview = true
                }

                Button("Reexibir Transcripts What's New") {
                    showTranscriptsWhatsNewPreview = true
                }

                Button("Reexibir ShareClip What's New") {
                    showShareClipWhatsNewPreview = true
                }

                Menu("Exibir Tela de Apoio") {
                    Button("Genérico") { supportSheetPreviewContext = .generic }
                    Button("Fim de Episódio") { supportSheetPreviewContext = .episodeCompleted }
                    Button("Exportar Clipe") { supportSheetPreviewContext = .shareClip }
                }

                Button("Resetar Prompt de Apoio") {
                    AppPersistentMemory.shared.resetSupportPromptMemory()
                }
            }
        }
        .navigationTitle("Dev Options")
        .sheet(item: $supportSheetPreviewContext) { context in
            StandaloneSupportView(context: context)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(apiClient: APIClient.shared)
}
