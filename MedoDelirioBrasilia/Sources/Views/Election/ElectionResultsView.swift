//
//  ElectionResultsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 29/09/26.
//

import SwiftUI

/// Every candidate in the President count, opened from the Live Activity and the election
/// banner (`medodelirio://apuracao`). The Live Activity is the glance; this is where people
/// come for the rest: every candidate, votes, a card to share and the TSE's own app.
struct ElectionResultsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var info: ElectionLiveInfo?
    @State private var loadFailed = false
    @State private var isRunning = ElectionLiveActivityManager.shared.isRunning
    @State private var isWorking = false
    @State private var startErrorMessage: String?
    @State private var showActivitiesDisabledAlert = false
    /// The count at the moment "Compartilhar Imagem" was tapped.
    @State private var shareSnapshot: ElectionShareSnapshot?
    @State private var toast: Toast?

    /// The server takes a new TSE file every 10 s; 20 s keeps the screen current without
    /// hammering it while someone leaves it open all night.
    private static let refreshInterval: Duration = .seconds(20)

    // MARK: - View Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .spacing(.large)) {
                    if let info, let state = info.state {
                        ElectionResultsHeader(round: info.round, state: state, details: info.details)

                        actions(info: info, state: state)

                        if let details = info.details {
                            candidateList(details)
                        }

                        Text("Os números são os divulgados pelo Tribunal Superior Eleitoral, sem nenhuma alteração.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else if info != nil {
                        placeholder(
                            symbol: "clock",
                            title: "A apuração ainda não começou",
                            message: "Os resultados aparecem aqui quando o TSE publicar os primeiros números, a partir das 17h de Brasília."
                        )
                    } else if loadFailed {
                        placeholder(
                            symbol: "wifi.exclamationmark",
                            title: "Não foi possível carregar a apuração",
                            message: "Confira sua conexão. Enquanto isso, os resultados oficiais estão no app Resultados, do TSE."
                        )
                        Button("Tentar de Novo") {
                            Task { await load() }
                        }
                        .electionButtonStyle(prominent: false)
                        Link("Abrir o App do TSE", destination: ElectionLiveInfo.defaultOfficialResultsURL)
                            .electionButtonStyle(prominent: false)
                    } else {
                        ProgressView()
                            .padding(.top, 80)
                    }
                }
                .frame(maxWidth: 600)
                .padding(.horizontal, .spacing(.medium))
                .padding(.bottom, .spacing(.large))
                .frame(maxWidth: .infinity)
            }
            .refreshable {
                await load()
            }
            .toast($toast)
            .navigationTitle("Apuração ao Vivo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
            .task {
                while !Task.isCancelled {
                    await load()
                    try? await Task.sleep(for: Self.refreshInterval)
                }
            }
            .sheet(item: $shareSnapshot) { snapshot in
                ElectionShareView(snapshot: snapshot) { activityType in
                    let message = activityType == .saveToCameraRoll
                        ? "Imagem salva nas Fotos."
                        : "Imagem compartilhada com sucesso."
                    toast = Toast(message: message, type: .success)
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
            .alert(
                "Não Foi Possível Acompanhar",
                isPresented: Binding(get: { startErrorMessage != nil }, set: { if !$0 { startErrorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(startErrorMessage ?? "")
            }
        }
    }

    // MARK: - Subviews

    private func actions(info: ElectionLiveInfo, state: ElectionActivityAttributes.ContentState) -> some View {
        VStack(spacing: .spacing(.small)) {
            Button {
                Task { await toggleLiveActivity() }
            } label: {
                // The label stays in the layout while the spinner shows, so the button
                // keeps its height.
                Label(
                    isRunning ? "Parar de Acompanhar" : "Acompanhar na Tela Bloqueada",
                    systemImage: isRunning ? "stop.circle" : "lock.iphone"
                )
                .opacity(isWorking ? 0 : 1)
                .overlay {
                    if isWorking {
                        ProgressView()
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, .spacing(.xxSmall))
            }
            .electionButtonStyle(prominent: true)
            .disabled(isWorking)

            // Stacked at full width: side by side, the labels had to go icon-over-text.
            Group {
                Button {
                    shareSnapshot = ElectionShareSnapshot(round: info.round, state: state)
                } label: {
                    secondaryLabel("Compartilhar Imagem", systemImage: "square.and.arrow.up")
                }

                Link(destination: info.officialResults) {
                    secondaryLabel("App do TSE", systemImage: "arrow.up.forward.app")
                }
            }
            .electionButtonStyle(prominent: false)
        }
    }

    private func secondaryLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, .spacing(.xxSmall))
    }

    private func candidateList(_ details: ElectionLiveDetails) -> some View {
        VStack(alignment: .leading, spacing: .spacing(.small)) {
            Text("TODOS OS CANDIDATOS")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(details.candidates.enumerated()), id: \.element.id) { index, candidate in
                    ElectionCandidateResultRow(position: index + 1, candidate: candidate)
                    if index < details.candidates.count - 1 {
                        Divider()
                            .padding(.leading, 90)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        }
    }

    private func placeholder(symbol: String, title: String, message: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        }
        .padding(.top, 40)
    }

    // MARK: - Functions

    private func load() async {
        do {
            info = try await APIClient.shared.electionLiveInfo()
            loadFailed = false
        } catch {
            // Keep showing the last numbers; the next refresh may work.
            if info == nil {
                loadFailed = true
            }
        }
        isRunning = ElectionLiveActivityManager.shared.isRunning
    }

    private func toggleLiveActivity() async {
        isWorking = true
        defer { isWorking = false }

        let manager = ElectionLiveActivityManager.shared
        if isRunning {
            await manager.endAll()
        } else {
            do {
                try await manager.start()
            } catch ElectionLiveActivityManager.StartError.activitiesDisabled {
                showActivitiesDisabledAlert = true
            } catch {
                startErrorMessage = error.localizedDescription
            }
        }
        isRunning = manager.isRunning
    }
}

// MARK: - Header

/// The Live Activity's green band, bigger: round, counted share, bar, sections, time and
/// source, and the final message when there is one.
struct ElectionResultsHeader: View {

    let round: Int
    let state: ElectionActivityAttributes.ContentState
    let details: ElectionLiveDetails?

    var body: some View {
        VStack(spacing: .spacing(.small)) {
            HStack(spacing: 6) {
                if !state.isFinal {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                }
                Text(state.isFinal ? "PRESIDENTE · \(round)º TURNO · RESULTADO" : "PRESIDENTE · \(round)º TURNO · AO VIVO")
                    .font(.caption)
                    .fontWeight(.heavy)
            }
            .foregroundStyle(.white.opacity(0.9))

            Text(ElectionResultsFormat.percent(state.sectionsCountedPercent))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("TOTALIZADO")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white.opacity(0.85))

            ElectionResultsBar(fraction: state.sectionsCountedPercent / 100, color: ElectionResultsPalette.bar)
                .frame(height: 10)
                .padding(.top, 4)

            if let details {
                Text("\(ElectionResultsFormat.count(details.sectionsCounted)) de \(ElectionResultsFormat.count(details.sectionsTotal)) seções")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }

            if state.isFinal, let finalMessage = state.finalMessage {
                Text(finalMessage)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            Text("Atualizado às \(state.updatedAtDate.formatted(date: .omitted, time: .shortened)) · Fonte: TSE")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.spacing(.large))
        .background(
            LinearGradient(
                colors: [ElectionResultsPalette.header, ElectionResultsPalette.body],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: .rect(cornerRadius: 24)
        )
        .padding(.top, .spacing(.small))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Candidate Row

struct ElectionCandidateResultRow: View {

    let position: Int
    let candidate: ElectionLiveDetails.Candidate

    var body: some View {
        HStack(spacing: .spacing(.small)) {
            Text("\(position)º")
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)

            ElectionCandidatePhoto(number: candidate.number, colorHex: candidate.colorHex, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                // Two lines rather than cutting a long ballot name. The badge sits on the
                // party line: next to the name it squeezed both into broken lines.
                Text(candidate.name)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(candidate.hasValidVotes ? candidate.party : "\(candidate.party) · anulado")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let badge {
                        Text(badge)
                            .font(.caption2)
                            .fontWeight(.heavy)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ElectionResultsPalette.accent.opacity(0.2), in: .capsule)
                            .fixedSize()
                    }
                }
                ElectionResultsBar(
                    fraction: candidate.percent / 100,
                    color: candidate.colorHex.map(Color.init(hex:)) ?? ElectionResultsPalette.accent
                )
                .frame(height: 6)
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(ElectionResultsFormat.percent(candidate.percent))
                    .font(.headline)
                    .monospacedDigit()
                Text("\(ElectionResultsFormat.count(candidate.votes)) votos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            // Same width on every row, so the bars end at the same place. Fits
            // "99.999.999 votos".
            .frame(width: 106, alignment: .trailing)
        }
        .padding(.vertical, .spacing(.small))
        .padding(.horizontal, .spacing(.small))
        .opacity(candidate.hasValidVotes ? 1 : 0.6)
        .accessibilityElement(children: .combine)
    }

    private var badge: String? {
        switch candidate.status {
        case .elected: "ELEITO"
        case .runoff: "2º TURNO"
        case .counting, .notElected: nil
        }
    }
}

// MARK: - Pieces

/// The official TSE photo when the app has one (`ElectionCandidate<number>`), otherwise the
/// candidate's color with the ballot number, like the Live Activity.
struct ElectionCandidatePhoto: View {

    let number: Int
    let colorHex: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let photo = UIImage(named: "ElectionCandidate\(number)") {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size, alignment: .top)
            } else {
                Circle()
                    .fill(colorHex.map(Color.init(hex:)) ?? Color.gray)
                    .overlay {
                        Text(String(number))
                            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay {
            Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5)
        }
        .accessibilityHidden(true)
    }
}

struct ElectionResultsBar: View {

    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(color)
                    .frame(width: max(proxy.size.height, proxy.size.width * min(max(fraction, 0), 1)))
            }
        }
        .accessibilityHidden(true)
    }
}

extension View {

    /// Liquid Glass on iOS 26, bordered before it: prominent for the screen's main action,
    /// plain glass for the rest. Tinted with the election green either way.
    @ViewBuilder
    func electionButtonStyle(prominent: Bool) -> some View {
        if #available(iOS 26, *) {
            if prominent {
                buttonStyle(.glassProminent)
                    .tint(ElectionResultsPalette.accent)
            } else {
                buttonStyle(.glass)
                    .tint(ElectionResultsPalette.accent)
            }
        } else {
            if prominent {
                buttonStyle(.borderedProminent)
                    .tint(ElectionResultsPalette.accent)
            } else {
                buttonStyle(.bordered)
                    .tint(ElectionResultsPalette.accent)
            }
        }
    }
}

enum ElectionResultsPalette {

    /// Same greens and yellow as the Live Activity.
    static let header = Color(red: 0.03, green: 0.20, blue: 0.11)
    static let body = Color(red: 0.06, green: 0.29, blue: 0.16)
    static let bar = Color(red: 1, green: 0.84, blue: 0)
    static let accent = Color(red: 0.13, green: 0.55, blue: 0.29)
}

enum ElectionResultsFormat {

    private static let locale = Locale(identifier: "pt_BR")

    static func percent(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)).locale(locale)) + "%"
    }

    static func count(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }
}

// MARK: - Preview

#Preview("Results") {
    ElectionResultsView()
}
