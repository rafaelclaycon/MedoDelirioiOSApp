//
//  SettingsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 21/05/22.
//

import SwiftUI
import TipKit

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
    /// Written from the chapter list's "Ocultar capítulos" action; this is the
    /// only way back once a user hides them.

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
                    Text("Algumas vírgulas e músicas contam com muitos palavrões. Ao marcar essa opção, você concorda que tem mais de 18 anos e que deseja ver esses conteúdos.")
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

                    NavigationLink(value: SettingsDestination.episodesSettings) {
                        Label {
                            Text("Episódios")
                        } icon: {
                            Image(systemName: "headphones")
                                .foregroundColor(.green)
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

                case .episodesSettings:
                    EpisodesSettingsView()

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
    case episodesSettings
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
    @State private var showTipsResetConfirmation: Bool = false
    @State private var isGeneratingReactionsExport: Bool = false
    @State private var reactionsExportURL: URL?
    @State private var reactionsExportError: String?
    @State private var reactionsExportResultMessage: String?

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

                Button("Resetar Todos os Tips (TipKit)") {
                    // Must run before the next `Tips.configure()`, which already
                    // happened at this launch — the datastore clears immediately,
                    // but tips only re-evaluate their eligibility on the next
                    // configure(), hence the relaunch ask below.
                    try? Tips.resetDatastore()
                    showTipsResetConfirmation = true
                }
            }

            Section("Reactions") {
                Button {
                    Task {
                        isGeneratingReactionsExport = true
                        do {
                            reactionsExportURL = try await ReactionsExportGenerator.generate()
                        } catch {
                            reactionsExportError = error.localizedDescription
                        }
                        isGeneratingReactionsExport = false
                    }
                } label: {
                    HStack {
                        Text("Exportar Dados para Sugestão de Reactions")
                        if isGeneratingReactionsExport {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isGeneratingReactionsExport)
            }
        }
        .navigationTitle("Dev Options")
        .sheet(item: $supportSheetPreviewContext) { context in
            StandaloneSupportView(context: context)
        }
        .alert("Tips resetados", isPresented: $showTipsResetConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Feche o app completamente e abra de novo para ver os tips outra vez.")
        }
        .alert("Erro ao Exportar", isPresented: .constant(reactionsExportError != nil)) {
            Button("OK", role: .cancel) { reactionsExportError = nil }
        } message: {
            Text(reactionsExportError ?? "")
        }
        .sheet(isPresented: Binding(
            get: { reactionsExportURL != nil },
            set: { isPresented in
                if !isPresented { reactionsExportURL = nil }
            }
        )) {
            if let reactionsExportURL {
                ActivityViewController(activityItems: [reactionsExportURL]) { _, completed, _, _ in
                    reactionsExportResultMessage = completed
                        ? "Reactions exportadas com sucesso."
                        : "Exportação cancelada."
                }
            }
        }
        .alert("Exportação", isPresented: .constant(reactionsExportResultMessage != nil)) {
            Button("OK", role: .cancel) { reactionsExportResultMessage = nil }
        } message: {
            Text(reactionsExportResultMessage ?? "")
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(apiClient: APIClient.shared)
}
