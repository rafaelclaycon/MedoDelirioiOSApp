import SwiftUI

struct TrendsSettingsView: View {

    @State var trendsEnabled = false
    @State var soundsMostSharedByTheAudienceEnabled = false
    @State var mostSharedSoundsByTheUserEnabled = false
    @State var dayOfTheWeekTheUserSharesTheMostEnabled = false
    //@State var appsThroughWhichTheUserSharesTheMostEnabled = false
    @State var shareUserPersonalTrendsEnabled = false
    
    @State private var showDeleteAllUserShareLogsConfirmationAlert: Bool = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Habilitar Tendências", isOn: $trendsEnabled)
                    .onChange(of: trendsEnabled) { _, newValue in
                        UserSettings().setEnableTrends(to: newValue)
                    }
            } footer: {
                Text("Nenhum dado coletado identifica você. O propósito dessa funcionalidade é apenas matar a sua curiosidade (e a dos demais usuários) sobre a popularidade dos sons.")
            }
            
            Section {
                Toggle("Vírgulas Mais Compartilhadas Pela Audiência (iOS)", isOn: $soundsMostSharedByTheAudienceEnabled)
                    .onChange(of: soundsMostSharedByTheAudienceEnabled) { _, newValue in
                        UserSettings().setEnableSoundsMostSharedByTheAudience(to: newValue)
                    }
//                Toggle("Sons Mais Compartilhados Por Mim", isOn: $mostSharedSoundsByTheUserEnabled)
//                    .onChange(of: mostSharedSoundsByTheUserEnabled) { newValue in
//                        UserSettings().setEnableMostSharedSoundsByTheUser(to: newValue)
//                    }
//                Toggle("Dia da semana no qual você mais compartilha", isOn: $dayOfTheWeekTheUserSharesTheMostEnabled)
//                    .onChange(of: dayOfTheWeekTheUserSharesTheMostEnabled) { newValue in
//                        UserSettings().setEnableDayOfTheWeekTheUserSharesTheMost(to: newValue)
//                    }
//                Toggle("Apps Pelos Quais Você Mais Compartilha", isOn: $appsThroughWhichTheUserSharesTheMostEnabled)
//                    .onChange(of: appsThroughWhichTheUserSharesTheMostEnabled) { newValue in
//                        UserSettings().setEnableAppsThroughWhichTheUserSharesTheMost(to: newValue)
//                    }
                Toggle("Compartilhar minhas tendências", isOn: $shareUserPersonalTrendsEnabled)
                    .onChange(of: shareUserPersonalTrendsEnabled) { _, newValue in
                        UserSettings().setEnableShareUserPersonalTrends(to: newValue)
                    }
            } header: {
                Text("Escolha o que deseja usar")
            } footer: {
                Text("Se a opção acima estiver ativada, os seguintes dados serão enviados:\n · ID de instalação\n · ID do conteúdo compartilhado\n · tipo do conteúdo (som, música ou vídeo)\n · quantidade total de compartilhamentos\n · nome do app pelo qual o conteúdo foi compartilhado")
            }
            .disabled(trendsEnabled == false)
            
            Section("Histórico local de compartilhamento") {
                Button("Apagar todos os registros locais") {
                    showDeleteAllUserShareLogsConfirmationAlert = true
                }
                .alert(isPresented: $showDeleteAllUserShareLogsConfirmationAlert) {
                    Alert(title: Text("Apagar Todos os Registros Locais de Compartilhamento?"),
                          message: Text("Ter dados salvos localmente não significa que eles serão enviados para o servidor; você pode desativar o envio na opção acima. A ação de apagar não pode ser desfeita."),
                          primaryButton: .destructive(Text("Apagar")) {
                              try? LocalDatabase.shared.deleteAllUserShareLogs()
                          },
                          secondaryButton: .cancel(Text("Cancelar")))
                }
            }
        }
        .navigationTitle("Tendências")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            trendsEnabled = UserSettings().getEnableTrends()
            //mostSharedSoundsByTheUserEnabled = UserSettings().getEnableMostSharedSoundsByTheUser()
            soundsMostSharedByTheAudienceEnabled = UserSettings().getEnableSoundsMostSharedByTheAudience()
            shareUserPersonalTrendsEnabled = UserSettings().getEnableShareUserPersonalTrends()
        }
    }

}

struct TrendsSettingsView_Previews: PreviewProvider {

    static var previews: some View {
        TrendsSettingsView()
    }

}
