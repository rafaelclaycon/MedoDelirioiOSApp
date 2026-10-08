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

                        if let turnout = info.details?.turnout, turnout.totalVotes > 0 {
                            ElectionTurnoutSection(turnout: turnout, isFinal: state.isFinal)
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

        // Same events as the election banner, from this screen, so the server's analytics
        // count people who start and stop here too.
        let manager = ElectionLiveActivityManager.shared
        if isRunning {
            await manager.endAll()
            await AnalyticsService().send(originatingScreen: "ElectionResults", action: "election_live_activity_stopped")
        } else {
            do {
                try await manager.start()
                await AnalyticsService().send(originatingScreen: "ElectionResults", action: "election_live_activity_started")
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

/// The two candidates face to face, the leader on the left like the Live Activity, and one
/// line saying by how much. How much is counted sits underneath, smaller: it matters less
/// than who's ahead.
struct ElectionResultsHeader: View {

    let round: Int
    let state: ElectionActivityAttributes.ContentState
    let details: ElectionLiveDetails?

    /// One side of the duel, from `details` when the server sent it (it has the votes),
    /// otherwise from the Live Activity state.
    struct Side: Identifiable {
        let number: Int
        let name: String
        let party: String
        let percent: Double
        let votes: Int?
        let status: ElectionActivityAttributes.Status
        let colorHex: String?

        var id: Int { number }
    }

    private var sides: [Side] {
        if let details, details.candidates.count >= 2 {
            return details.candidates.prefix(2).map {
                Side(number: $0.number, name: $0.name, party: $0.party, percent: $0.percent, votes: $0.votes, status: $0.status, colorHex: $0.colorHex)
            }
        }
        return state.candidates.prefix(2).map {
            Side(number: $0.number, name: $0.name, party: $0.party, percent: $0.percent, votes: nil, status: $0.status, colorHex: $0.colorHex)
        }
    }

    var body: some View {
        VStack(spacing: .spacing(.medium)) {
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

            HStack(alignment: .top, spacing: .spacing(.small)) {
                ForEach(sides) { side in
                    sideView(side)
                        .frame(maxWidth: .infinity)
                }
            }

            if sides.count == 2 {
                lead(sides[0], over: sides[1])
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))
            }

            if state.isFinal, let finalMessage = state.finalMessage {
                Text(finalMessage)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }

            counted
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

    private func sideView(_ side: Side) -> some View {
        VStack(spacing: 6) {
            ElectionCandidatePhoto(number: side.number, colorHex: side.colorHex, size: 76)
            Text(ElectionResultsFormat.percent(side.percent))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(side.name)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(side.party)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            if let votes = side.votes {
                Text("\(ElectionResultsFormat.count(votes)) votos")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.75))
            }
            if side.status == .elected {
                Text("ELEITO")
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundStyle(ElectionResultsPalette.header)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ElectionResultsPalette.bar, in: .capsule)
            } else if side.status == .runoff {
                Text("2º TURNO")
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.2), in: .capsule)
            }
        }
    }

    /// "Lula à frente por 285.671 votos (1,68 ponto)". Votes only when the server sent them.
    private func lead(_ leader: Side, over runnerUp: Side) -> Text {
        let points = leader.percent - runnerUp.percent
        let voteGap = leader.votes.flatMap { leaderVotes in runnerUp.votes.map { leaderVotes - $0 } }
        guard points > 0 || (voteGap ?? 0) > 0 else {
            return Text("Empate")
        }
        let name = Text(Self.displayName(leader.name)).bold()
        let pointsText = "\(ElectionResultsFormat.decimal(points)) \(points < 2 ? "ponto" : "pontos")"
        let gap = voteGap.map { "\(ElectionResultsFormat.count($0)) votos (\(pointsText))" } ?? pointsText
        return state.isFinal
            ? Text("\(name) terminou à frente por \(gap)")
            : Text("\(name) à frente por \(gap)")
    }

    /// "FLAVIO BOLSONARO" reads as shouting mid-sentence: "Flavio Bolsonaro".
    static func displayName(_ name: String) -> String {
        name.lowercased(with: Locale(identifier: "pt_BR")).capitalized(with: Locale(identifier: "pt_BR"))
    }

    /// How much is counted, kept but quiet.
    private var counted: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(ElectionResultsFormat.percent(state.sectionsCountedPercent)) totalizado")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Spacer(minLength: 8)
                if let details {
                    Text("\(ElectionResultsFormat.count(details.sectionsCounted)) de \(ElectionResultsFormat.count(details.sectionsTotal)) seções")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            ElectionResultsBar(fraction: state.sectionsCountedPercent / 100, color: ElectionResultsPalette.bar)
                .frame(height: 4)
            Text("Atualizado às \(state.updatedAtDate.formatted(date: .omitted, time: .shortened)) · Fonte: TSE")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, .spacing(.xxSmall))
    }
}

// MARK: - Turnout

/// Who chose no one: blank and null votes, and the voters who stayed home.
struct ElectionTurnoutSection: View {

    let turnout: ElectionLiveDetails.Turnout
    let isFinal: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing(.small)) {
            Text("BRANCOS, NULOS E ABSTENÇÃO")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: .spacing(.small)) {
                tile(
                    title: "Não foram votar",
                    percent: turnout.abstentionPercent,
                    detail: "\(ElectionResultsFormat.count(turnout.abstentions)) eleitores",
                    systemImage: "figure.walk.departure"
                )
                tile(
                    title: "Votos em branco",
                    percent: turnout.blankPercent,
                    detail: "\(ElectionResultsFormat.count(turnout.blankVotes)) votos",
                    systemImage: "square.dashed"
                )
                tile(
                    title: "Votos nulos",
                    percent: turnout.nullPercent,
                    detail: "\(ElectionResultsFormat.count(turnout.nullVotes)) votos",
                    systemImage: "xmark.square"
                )
            }
            // Same height for the three, whatever wraps.
            .fixedSize(horizontal: false, vertical: true)

            Text(isFinal
                 ? "Brancos e nulos sobre o total de votos. A abstenção, sobre o eleitorado."
                 : "Brancos e nulos sobre o total de votos, e a abstenção sobre o eleitorado, nas seções já apuradas.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func tile(title: String, percent: Double, detail: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(ElectionResultsPalette.accent)
                .frame(height: 20, alignment: .leading)
            Text(ElectionResultsFormat.percent(percent))
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.footnote)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.spacing(.small))
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
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

    /// Liquid Glass: prominent for the screen's main action, plain glass for the rest.
    /// Tinted with the election green either way.
    @ViewBuilder
    func electionButtonStyle(prominent: Bool) -> some View {
        if prominent {
            buttonStyle(.glassProminent)
                .tint(ElectionResultsPalette.accent)
        } else {
            buttonStyle(.glass)
                .tint(ElectionResultsPalette.accent)
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

    /// "1,87", without the percent sign.
    static func decimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)).locale(locale))
    }
}

// MARK: - Preview

#Preview("Results") {
    ElectionResultsView()
}
