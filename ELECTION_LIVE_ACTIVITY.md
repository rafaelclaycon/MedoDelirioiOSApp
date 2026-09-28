# Live Activity da apuração presidencial

Resumo do trabalho feito até 27/09/2026 e do que falta. Objetivo: uma Live Activity (Tela Bloqueada + Dynamic Island) que mostra em tempo real a apuração para Presidente, com dados oficiais do TSE.

## Situação em 27/09

- **Beta:** testado ponta a ponta. Replay offline no `.club` com `broadcastMode: live`, e a activity do app beta (TestFlight) atualizou sozinha.
- **Servidor de prod (`.com`):** código no ar, canal de prod criado, poller e broadcaster conferidos em `dryRun`, `enabled` desligado.
- **App de prod:** versão 13 pronta para arquivar e enviar, com a Live Activity redesenhada, fotos, frases finais e a tela de novidades. Falta o envio para revisão.

## Datas que importam

| Quando | O quê |
|---|---|
| 28 e 29/09, 14h às 16h | Janela de teste no simulado do TSE ("3ª semana de testes (semana extra)", aba Simulados da página técnica do TSE, conferido em 25/09) |
| Até 29/09 à noite | Enviar o app para revisão, com liberação manual (ver "Revisão da App Store") |
| 04/10 | 1º turno. Totalização a partir das 17h de Brasília (notícia do TSE de 06/07/2026). Trocar a fonte para `official` e ligar `enabled` |
| 25/10 | 2º turno: trocar `round` para 2. A tela de novidades deixa de aparecer a partir do dia 26 |

## Arquitetura

```
TSE CDN --(poll a cada 10s, ETag)--> Vapor no Linode --(1 broadcast push por app)--> APNs --> Live Activities
                                            |
                                            +-- GET v4/election/live?bundleId= <-- app (estado inicial + channelId + enabled)
```

- Só o servidor fala com o TSE. O app só consome a nossa API.
- As atualizações da activity não passam pelo app: o servidor manda um push por **canal de broadcast** (iOS 18+) e o iOS atualiza todas as activities inscritas.
- **Dois servidores:** o app beta pergunta ao `.club` (`api.medodelirioios.club`) e o de prod ao `.com` (`api.medodelirioios.com`), só para a eleição (ver `APIConfig.electionAPIURL`). Cada um tem o próprio canal e o próprio `enabled`.

## Regras do TSE

- Simulado: `https://resultados-sim.tse.jus.br/simulado`, ambiente `simulado2026`. Os arquivos continuam no ar fora das janelas, parados no resultado final. O `ele-c.json` não muda desde 14/09 e todas as rodadas usaram a eleição 21270.
- Oficial: `https://resultados.tse.jus.br`, ambiente `oficial`. Pleito 3220, eleição federal 6257 (ainda não aparece no `ele-c.json` oficial).
- Máximo de 100 requisições por segundo por IP; 304 também conta. Se passar: bloqueio de 10 min, renovado a cada nova tentativa.
- Vários 404 também bloqueiam o IP. Por isso o servidor nunca monta URL no chute: descobre ciclo e código da eleição pelo `ele-c.json`.
- Arquivo de Presidente: `<base>/<ambiente>/<ciclo>/<eleicao>/dados/br/br-c0001-e<eleicao com 6 dígitos>-u.json`.
- Fotos (não documentado, visto no app de resultados do TSE): `<base>/<ambiente>/<ciclo>/<eleicao>/fotos/<uf>/<sqcand>.jpeg`. O `sqcand` vem no `-u.json`.
- **Os arquivos publicados durante a apuração não têm todos os campos do arquivo final.** No simulado de 28/09, os candidatos vieram sem `dvt` (destino do voto) no meio da contagem, e o arquivo final (16h36) tinha o campo em todos. Nossas fixtures são arquivos finais, então não mostravam isso. Por isso, só o que identifica o arquivo e o candidato é obrigatório (ver `TSEResultFile`).
- No simulado, o 1º colocado é um candidato "Anulado sub judice" que vai para o 2º turno. Por isso o snapshot mantém os anulados na lista, marcados com `hasValidVotes = false`.
- Documentação: https://www.tse.jus.br/eleicoes/informacoes-tecnicas-sobre-a-divulgacao-de-resultados

## O que foi feito

### Servidor (`medo-delirio-api`, branch `main`)

Commits `04a37b1` (parser e replay), `3d3d037` (poller e endpoints), `463526b` (broadcaster da APNs), `b517463` (replay realista e offline) e `39ad257` (frases finais).

- `Sources/App/Election/` (só Foundation, testável sem Vapor):
  - `TSEElectionConfig`: lê o `ele-c.json` e encontra a eleição de Presidente de cada turno.
  - `TSEEndpoint`: endereços do simulado e do oficial, e a montagem das URLs.
  - `TSEResultFile`: os campos do arquivo `-u.json` que usamos.
  - `ElectionSnapshot`: nosso modelo do resultado, com candidatos na ordem `seq` do TSE, nome de urna (`nmu`), status (`counting`, `elected`, `runoff`, `notElected`) e horário de Brasília (com fallback fixo em UTC-3 se o servidor não tiver `tzdata`). Campos de contagem vazios ou ausentes (votos, porcentagens, seções) contam como 0, posição vazia vai para o fim, por votos, `dvt` ausente conta como voto válido, nome de urna ausente cai para o nome completo e depois para "Candidato 13", e sem `and` a apuração não é final. Só código da eleição, turno, geração, a estrutura de cargos e o número do candidato são obrigatórios (commits `560b630` e `185114b`).
  - `ElectionReplay`: simula a apuração de 0 a 100% a partir do resultado final, com troca de liderança no caminho. Avança em saltos de `replayStepSeconds` (padrão 60s, como arquivos novos do TSE), cada salto com o próprio horário de totalização, e numa curva rápida no começo e lenta no fim (metade da apuração em um quarto do tempo).
  - `ElectionReplayFixture`: o resultado final do simulado (eleição 21270) embutido no servidor. O replay usa esse resultado com `replayOffline: true`, ou sozinho quando o TSE não responde ou não lista o simulado. Um teste garante que ele é idêntico à fixture.
  - `ElectionLiveContentState`: o formato dos dados da activity. Tem que ser **idêntico** ao `ElectionActivityAttributes.ContentState` do app (ver "Contrato com o app").
  - `ElectionSettings` e `ElectionLiveStore`: configuração em runtime e estado em memória do poller. As configurações decodificam com valores padrão para chaves ausentes, então um campo novo não quebra o JSON já salvo no banco.
  - `ElectionBroadcastPlanner`: decide quando mandar push, com qual prioridade, e monta o payload (ver "Broadcaster").
- `Services/ElectionPollingService.swift`: loop a cada 10s com `If-None-Match`. Ignora 304 e `idg` repetido. Depois de um 404, esquece a URL e só consulta o `ele-c.json` de novo após 60s. Outros erros: espera de 60s. Um retry imediato quando a CDN derruba a conexão keep-alive (`remoteConnectionClosed`).
- `Services/APNsBroadcastClient.swift`: HTTP/2 direto para a APNs (o APNSwift 4.0.1 não tem Live Activity nem broadcast), com JWT ES256 assinado pela mesma chave `.p8` e reaproveitado por 50 min. Envia broadcast (`POST /4/broadcasts/apps/<bundle>`), cria e lista canais (Channel Management API, portas 2195/2196). O ambiente segue o `APNS_ENVIRONMENT`.
- `Controllers/ElectionController.swift` e rotas:
  - `GET api/v4/election/live?bundleId=<bundle>`: pública, usada pelo app. O `channelId` é o do bundle pedido (sem `bundleId`, o de prod; sem fallback do beta para o de prod, porque um canal só serve para o app dele).
  - `GET api/v4/election/status/:password`: diagnóstico, com o último push (`lastBroadcastAt`, `lastBroadcastEvent`, `lastBroadcastPriority`, `lastBroadcastReason`, `lastBroadcastError`). Campos vazios não aparecem na resposta.
  - `POST api/v4/election/settings/:password`: atualização parcial das configurações.
  - `POST api/v4/election/channels/:password[?bundleId=]`: cria o canal de cada app que ainda não tem um (ou só do bundle pedido), no ambiente atual da APNs, e salva nas configurações.
  - `GET api/v4/election/channels/:password`: mostra o ambiente da APNs, os canais configurados e os que a APNs conhece para cada bundle.
- Testes: `ElectionSnapshotTests`, `ElectionLiveTests` e `ElectionBroadcastPlannerTests`, com fixtures reais do simulado em `Tests/AppTests/Fixtures/Election/`. 68 testes passando.

#### Broadcaster

Roda no fim de todo tick do poller (não só quando chega arquivo novo, para um update retido pelo throttle sair assim que der). Erro de APNs não dispara o backoff do polling.

- **Modo** (`broadcastMode`): `off`, `dryRun` (padrão: decide tudo e só registra o payload no log) e `live`.
- **Prioridade 10:** primeiro push, novo líder, cada 10% apurado, resultado final e recomeço do replay. O resto sai em prioridade 5, que o iOS pode atrasar ou agrupar.
- **Throttle:** no máximo um push a cada `minPushIntervalSeconds` (padrão 30, mínimo 10). Novo líder e marcos de % também esperam o intervalo; o resultado final não espera.
- **Fim:** quando `isFinal` vira `true`, manda `event: end` com `dismissal-date` de 4h e um `alert` ("Apuração encerrada" + eleito ou os dois do 2º turno, ou o texto da frase final).
- **Resultado já final no boot:** se o primeiro estado que o servidor vê já é final (o simulado entre janelas, ou um restart depois da apuração), não manda nada. Sem isso, cada restart reanunciaria um resultado velho.
- `stale-date` de 15 min, igual ao `staleInterval` do app. `apns-expiration`: 15 min para update, 4h para o fim.
- Canal criado com `message-storage-policy: 1` (guarda a última mensagem para quem estava offline).
- Se todos os canais falham, nada é registrado e o próximo tick tenta de novo. Se só um falha, o envio conta como feito (repetir mandaria de novo para o outro) e o erro aparece no status.

#### Frases finais

O push de fim sai assim que o TSE encerra a apuração, então as frases são escritas **com antecedência**, uma por desfecho. O servidor escolhe a mais específica: `elected:13`, `elected`, `runoff:13-22` (números em ordem crescente), `runoff`, `default`. Sem frase, sai o texto neutro.

- `text` aparece na activity em negrito, entre a barra e o rodapé. O rodapé continua neutro, com "Fonte: TSE".
- `alertTitle` e `alertBody` substituem o alerta neutro "Apuração encerrada".
- `null` apaga uma chave. Editar a frase depois do fim reenvia o `end` em prioridade 5 e sem alerta.
- Os números nunca mudam de tom: a opinião fica só nesse campo, separada dos dados do TSE.

#### Contrato com o app

Depois que uma versão do app é aprovada, o servidor **nunca** pode renomear ou remover um campo do `ContentState`, nem criar um valor novo de `status`: o iOS descarta o push em silêncio. Adicionar campos opcionais pode (o app ignora).

#### Variáveis de ambiente

- `ELECTION_PASSWORD`: sem ela, a primeira rota de admin da eleição derruba o processo inteiro com `fatalError` (e com ele a API do app). Aconteceu no `.com` em 27/09.
- `ELECTION_POLLING_ENABLED=true`: liga o poller.
- `APNS_ENVIRONMENT`: vazio ou ausente é produção, que é o que TestFlight e App Store usam. `sandbox` só para apps instalados pelo Xcode. Os canais pertencem a um ambiente só.

#### Comandos

```bash
# Ver o estado
curl https://<servidor>/api/v4/election/status/<senha>

# Trocar para o oficial no dia 4
curl -X POST -H 'Content-Type: application/json' -d '{"source":"official"}' https://<servidor>/api/v4/election/settings/<senha>

# Lançamento público
curl -X POST -H 'Content-Type: application/json' -d '{"enabled":true}' https://<servidor>/api/v4/election/settings/<senha>

# Replay sem o TSE, com um "arquivo novo" a cada 45s, pushes de verdade
curl -X POST -H 'Content-Type: application/json' -d '{"source":"replay","replayOffline":true,"replayStepSeconds":45,"replayDurationMinutes":15,"restartReplay":true,"broadcastMode":"live"}' https://<servidor>/api/v4/election/settings/<senha>

# Cores por número de urna (só para candidatos sem foto; sem cor, 1º vermelho e 2º azul)
curl -X POST -H 'Content-Type: application/json' -d '{"candidateColors":{"55":"#1D4E89"}}' https://<servidor>/api/v4/election/settings/<senha>

# Criar o canal de um app no ambiente atual da APNs
curl -X POST "https://<servidor>/api/v4/election/channels/<senha>?bundleId=com.rafaelschmitt.MedoDelirioBrasilia"

# Conferir canais e ambiente
curl https://<servidor>/api/v4/election/channels/<senha>

# Voltar a não mandar pushes
curl -X POST -H 'Content-Type: application/json' -d '{"broadcastMode":"dryRun"}' https://<servidor>/api/v4/election/settings/<senha>

# Ajustar o throttle depois de medir a cadência do TSE
curl -X POST -H 'Content-Type: application/json' -d '{"minPushIntervalSeconds":45}' https://<servidor>/api/v4/election/settings/<senha>

# Frases finais
curl -X POST -H 'Content-Type: application/json' -d '{"finalMessages":{"runoff:13-22":{"text":"Segura que tem 2º turno. Bora!"},"default":{"text":"Acabou a apuração."}}}' https://<servidor>/api/v4/election/settings/<senha>
```

Campos aceitos: `enabled`, `source` (`simulation`, `official`, `replay`), `round` (1 ou 2), `channelIds` (mapa bundle ID → canal, mesclado; string vazia apaga), `broadcastMode` (`off`, `dryRun`, `live`), `minPushIntervalSeconds`, `candidateColors`, `finalMessages`, `replayDurationMinutes`, `replayStepSeconds` (0 = avança a cada poll), `replayOffline`, `restartReplay`.

#### Conferir um servidor sem os logs

Nesta ordem, porque as rotas com senha derrubam o processo se a senha faltar:

1. `GET api/v2/status-check` → 200.
2. `GET api/v4/election/live` → 200 com `state` preenchido (poller rodando). 404 = código da eleição não subiu.
3. Conferir no servidor que `ELECTION_PASSWORD` está no `.env` (`grep -c "^ELECTION_PASSWORD=." .env`), e só então `GET election/status/<senha>`. Os campos `finalMessages`, `replayStepSeconds` e `replayOffline` em `settings` provam que é a versão mais recente.
4. `GET election/channels/<senha>` → `apnsEnvironment: production` e `errors` vazio.
5. `GET election/live?bundleId=<bundle>` → `channelId` preenchido.
6. Replay em `dryRun` e ver `lastBroadcastAt` e `lastBroadcastReason` avançando, sem `lastBroadcastError`.

#### Rodar localmente

Banco em memória e sem APNs, não precisa das chaves de produção:

```bash
cd medo-delirio-api
ELECTION_POLLING_ENABLED=true ELECTION_PASSWORD=local-test swift run Run serve --env testing --port 8089
```

**Toolchain:** os Xcode 27 e 27.1 beta (e as Command Line Tools, com o mesmo Swift 6.4) geram binários para o runtime do macOS 27. No macOS 26.7, o `swift test` compila mas falha ao carregar o bundle (`Symbol not found: _swift_initBorrow`). Desde 28/09 o Xcode 26.6 não está mais instalado, então os testes da API não rodam neste Mac: rodar no servidor (`swift test` no Linode, antes de reiniciar o serviço) ou reinstalar o Xcode 26.6 pelo Xcodes e usar:

```bash
DEVELOPER_DIR=/Applications/Xcode_26.6.app/Contents/Developer swift test
```

### App (`MedoDelirioiOSApp`, branch `main`)

Commits de 24 e 25/09: `c2e03f5b` (Live Activity e flag), `f67997c1` (banner), `a8f09c0b` (canal por app). De 26 e 27/09: `aa88ce0b` (servidor da eleição no beta), `d083256a` (redesign), `a36220fd` (fotos e frase final), `9880433a` (fontes fixas), `0cec3004` (Dynamic Island), `2baeee60` (banner), `2d34f27f` (fim da flag), `7ad79c46` (tela de novidades), `c7fb25c1` (tecla CONFIRMA), `25a5d896` (texto da data), `60743c3d` (limites da Tela Bloqueada e da Island).

#### Live Activity (`MedoDelirioWidget/Election/`)

- `ElectionActivityAttributes.swift`: formato dos dados, compartilhado com o app pela exception set do projeto (mesmo mecanismo do `PlayRandomSoundIntent`). Sem `Date` e com chaves camelCase, para o mesmo JSON servir no endpoint e no push. Inclui o `finalMessage` opcional.
- `ElectionLiveActivity.swift`, inspirado num app indie de 2022:
  - **Só os 2 mais votados**, com o líder sempre à esquerda. O servidor ainda manda 4 no 1º turno; o app mostra 2.
  - **Tela Bloqueada:** faixa de cima verde-escura com foto (36 pt) e porcentagem (duas casas, `title3`) de cada um e o selo "1º TURNO" no meio, com um ponto vermelho enquanto a apuração está ao vivo (some no resultado final). Embaixo, os nomes numa linha própria, "X% TOTALIZADO", a barra amarela e o rodapé com a logo do app e "Atualizado às HH:mm · Fonte: TSE" (ou "Atualização atrasada", ou o resultado final). No fim, a frase final em negrito **no lugar do rodapé**, numa linha só.
  - **Limite de 160 pt:** a Tela Bloqueada corta uma Live Activity mais alta que isso. Medido em 27/09: 148 pt contando e 151 pt no final com frase. Os espaçamentos verticais estão justos de propósito; qualquer linha nova precisa sair de algum lugar.
  - **Fundo sempre verde-escuro**, em dois tons. A parte de baixo pinta o próprio fundo: no modo claro, o sistema pode pôr branco por baixo mesmo com `activityBackgroundTint`.
  - **Fontes fixas:** porcentagens e nomes não encolhem. Os nomes têm uma linha própria, com metade da largura para cada lado, porque ao lado da foto "FLAVIO BOLSONARO" não cabe. "ESCRITOR AUGUSTO CURY" contra "FLAVIO BOLSONARO" cabe inteiro.
  - **Tamanho de texto fixo no padrão** (`.dynamicTypeSize(.large)`): com o turno entre as porcentagens, tamanhos maiores empurram as fotos para fora num iPhone estreito (xLarge já encosta no SE, xxLarge sai da tela). Quem usa texto grande no sistema vê a Live Activity no tamanho padrão.
  - **Dynamic Island:** compacta com os dois (foto + %); expandida com foto e % de cada lado, e embaixo os nomes, "● 1º TURNO   X% TOTALIZADO" e a barra (sem região do meio, que roubava largura das porcentagens); mínima só com o logo do podcast em branco (`ElectionPodcastLogo`). A barra da expandida fica afastada 18 pt das bordas e 6 pt acima do fundo: os cantos arredondados da Island cortavam as pontas.
  - **Previews:** Lock Screen (apurando, com fotos, final, final com frase), Island expandida, compacta e mínima.
- **Fotos:** fotos oficiais de candidatura do TSE (DivulgaCandContas, eleição 20322002026) no catálogo do widget como `ElectionCandidate<número>`, para 13 (Lula), 14 (Renan Santos), 22 (Flávio Bolsonaro), 30 (Zema) e 70 (Escritor Augusto Cury). Recortadas em círculo pela view, alinhadas pelo topo. Sem foto, o candidato aparece como um círculo na cor dele com o número. Para trocar ou adicionar, nomeie os arquivos pelo número (`13.jpg`) e rode `scripts/import-election-photos.sh <pasta>`. O site do TSE bloqueia downloads fora do navegador: baixe pelo navegador.
- **Logo:** `ElectionAppLogo` (ícone padrão do app, 22 pt) no rodapé.

#### App

- `Info.plist`: `NSSupportsLiveActivities` e `NSSupportsLiveActivitiesFrequentUpdates`.
- `Sources/Helpers/ElectionLiveActivityManager.swift`: inicia com `pushType: .channel(channelId)`, não duplica activity do mesmo turno, mensagens de erro em português, `endAll()`. Activities já encerradas (que ficam na Tela Bloqueada até a `dismissal-date`) não contam como "acompanhando" nem impedem uma nova.
- `Sources/Networking/APIClient+Election.swift`: `GET v4/election/live?bundleId=<Bundle.main.bundleIdentifier>`, no servidor de `APIConfig.electionAPIURL`.
- **Servidor da eleição no beta:** `APIConfig.electionAPIURL` manda só o `v4/election/live` do bundle beta para o `.club`; o resto do beta continua no servidor de prod. Motivo: o `api_environment` do scheme só vale rodando pelo Xcode, então um build de TestFlight sempre caía no servidor de prod. Com `api_environment` ligado no scheme, ele continua mandando.
- **Banner** (`Sources/Views/Banners/ElectionLiveBannerView.swift`): no topo das Vírgulas, com "Acompanhar ao Vivo" e "Parar de Acompanhar", alerta quando as Atividades ao Vivo estão desligadas e eventos de analytics. O texto não cita a Dynamic Island (não há API para saber se o aparelho tem uma).
  - O `BannersView` pergunta ao servidor quando aparece **e sempre que o app volta ao primeiro plano**: quem deixou o app aberto de manhã vê o banner às 17h. Se a requisição falhar, o banner fica como estava.
- **Sem feature flag:** o banner aparece só quando o `enabled` do servidor está ligado. A flag `electionLiveActivity` foi removida em 27/09; os testers do beta entram com `{"enabled":true}` no `.club`.
- **Dev Options** só aparece com o argumento `-SHOW_MORE_DEV_OPTIONS`, que não chega a builds de TestFlight. Para um build especial de TestFlight, trocar por `if true` no `SettingsView` sem commitar e reverter depois.

#### Tela de novidades (`Sources/Views/Onboarding/WhatsNew/IntroducingElectionLiveView.swift`)

- Aparece uma vez, depois do onboarding, antes das telas de Clipes e Transcrições. **Não aparece a partir de 26/10.**
- **Header:** as fotos do Lula e do Flávio se chocam e voltam; a cada choque, um anel amarelo explode no ponto de contato e o "% TOTALIZADO" e a barra andam um passo, até 100% e recomeçar. Com Reduzir Movimento, fica parado.
- **Fundo do header:** mini teclados de urna (1 a 9, 0 embaixo do 8, BRANCO, CORRIGE e CONFIRMA nas cores reais, ponto de braille em cada tecla), poucos, grandes e apagados, sumindo atrás das fotos e do título. Menores ou mais densos viram ruído.
- **Itens:** Na Tela Bloqueada; Dados Oficiais do TSE; "4 de Outubro, às 17h de Brasília" (banner no topo das Vírgulas, 2º turno no dia 25).
- **Botão:** a tecla CONFIRMA da urna (face verde sobre um degrau mais escuro, "CONFIRMA" em fonte monoespaçada, o texto em braille embaixo). Afunda ao apertar, com vibração forte e o "piririm" da urna (`Resources/ElectionStuff/urna_confirma.caf`, tocado como som de sistema: respeita a chave de silencioso e não interrompe outros áudios).
- As fotos do Lula e do Flávio também estão no catálogo do app (`ElectionCandidate13` e `22`), porque o app não enxerga o catálogo do widget.
- **Dev Options:** "Reexibir Election Live What's New" e "Resetar Election Live What's New" (vale na próxima abertura do app).

### Também na versão 13 (fora da eleição)

- **Splash** (`36f09137`): o logo dos 4 anos saiu. Logo preto no fundo claro e branco no escuro, com as @2x geradas das @3x. Os arquivos originais vieram com `light` e `dark` trocados em relação à convenção do projeto (`light` = modo claro = logo preto); foram aplicados pelo conteúdo. O iOS guarda a splash em cache: se a antiga aparecer depois de atualizar, reiniciar o aparelho.
- **Tela de autor** (`81ba2caa`): no layout largo (Duo aberto, iPad), a descrição, os links e a contagem se alinham com o nome em vez de centralizar ao lado da foto. Os links das redes sociais foram para a linha do "15 SONS" (`SoundCountAndLinks`), com fallback para botões só com ícone e depois para duas linhas.

## Revisão da App Store

Enquanto a versão está em revisão, só os revisores têm esse código no app de prod (o beta usa o `.club`, e as versões antigas não têm o banner). Então:

1. Ligar a **Broadcast Capability** no App ID de prod antes de arquivar.
2. Arquivar sem o Dev Options aberto.
3. Enviar com **liberação manual** e as notas abaixo.
4. Durante a revisão, deixar o `.com` assim (replay de 24h; se a revisão passar de um dia, mandar de novo):

```bash
curl -X POST -H 'Content-Type: application/json' -d '{"enabled":true,"source":"replay","replayOffline":true,"replayDurationMinutes":1440,"replayStepSeconds":60,"restartReplay":true,"broadcastMode":"live"}' https://api.medodelirioios.com/api/v4/election/settings/<senha>
```

5. Depois da aprovação, **antes de liberar:**

```bash
curl -X POST -H 'Content-Type: application/json' -d '{"enabled":false,"broadcastMode":"dryRun"}' https://api.medodelirioios.com/api/v4/election/settings/<senha>
```

**Notas para o revisor:**

```text
ELECTION LIVE ACTIVITY (new in this version)

This version adds a Live Activity that follows the vote count for President of Brazil in real time, on the Lock Screen and in the Dynamic Island, using the official public results published by Brazil's Superior Electoral Court (TSE, Tribunal Superior Eleitoral).

The feature is switched on by our server only on election days (October 4 and October 25, 2026). To allow review, it is switched on now and runs a simulated count built from the TSE's official public test data (their "simulado" environment). This is why the candidates show placeholder names such as "CANDIDATO 9999": those are the TSE's own test candidates, not real people.

HOW TO TEST
1. Make sure Live Activities are enabled in Settings.
2. Open the app. On the first tab ("Vírgulas"), a green banner titled "Apuração ao Vivo" appears at the top.
3. Tap "Acompanhar ao Vivo". A Live Activity starts.
4. Lock the device. The Live Activity shows the two leading candidates with their share of valid votes, the percentage of ballots counted and the time of the last update.
5. Leave the device locked for a few minutes: the count advances roughly every minute through push notifications, without opening the app. On devices with a Dynamic Island, the same data appears there.
6. To stop, open the app and tap "Parar de Acompanhar" in the same banner, or dismiss the Live Activity from the Lock Screen.

NOTES
- No account or login is required.
- The app only displays the TSE's public data without changing it. The Live Activity credits the source ("Fonte: TSE").
- Updates are sent by our server through an APNs broadcast channel. Starting and stopping the Live Activity sends an anonymous analytics event, and nothing else is collected.
- After election day, the server switches the feature off and the banner disappears.
```

**Novidades desta versão (App Store):**

```text
APURAÇÃO AO VIVO
Acompanhe a apuração para Presidente em tempo real na Tela Bloqueada, com dados oficiais do TSE. Os dois mais votados, a porcentagem de cada um e quanto já foi totalizado, atualizando sozinho, sem abrir o app.

No dia 4 de outubro, a partir das 17h (horário de Brasília), um banner aparece no topo das Vírgulas. É só tocar em "Acompanhar ao Vivo". Se tiver 2º turno, dia 25 tem de novo.

IPHONE DUO E JANELAS REDIMENSIONÁVEIS
• O app se adapta ao tamanho da janela, e não mais ao tipo de aparelho: no iPhone Duo aberto e no iPad em Split View, as grades e os espaçamentos acompanham o espaço disponível.
• No iPhone Duo aberto, a tela de Reproduzindo Agora ocupa a tela toda. Com a dobra na vertical, a capa e os controles ficam de um lado e as abas do outro.
• Na tela de autor, o texto se alinha ao nome, e os links das redes sociais ficam na mesma linha da contagem de sons, sobrando mais espaço para as vírgulas.

Mais: nova tela de abertura, correções de layout em telas estreitas e deslizar para apagar marcadores no iOS 27.
```

## O que falta

### Antes do envio (até 29/09)

- [ ] Conferir no aparelho a barra da Island expandida (não dá para renderizar no Mac) e a tela de novidades (animação do header, tecla CONFIRMA afundando, som e vibração).
- [ ] Conferir a tela de autor no iPhone Duo aberto e num iPhone comum (ver "Também na versão 13").
- [ ] Gerar um build novo: o que está no TestFlight ainda tem a splash de aniversário e o layout antigo da Live Activity.
- [ ] Portal: Broadcast Capability no App ID `com.rafaelschmitt.MedoDelirioBrasilia`.
- [ ] Commitar o `APP_VERSION` 13 (build 3), arquivar sem Dev Options e enviar com liberação manual e as notas.
- [x] Build de revisão no TestFlight interno do app de prod, com replay `live` no `.com`: os pushes chegaram (27/09). Confirma servidor, canal de prod, Broadcast Capability e APNs de produção com o app da versão 13.
- [ ] Configurar o `.com` para a revisão (comando acima).

### Teste no simulado (28 e 29/09, 14h às 16h)

**28/09, o que aconteceu:**

- O TSE só publicou o primeiro arquivo novo às 14h39, e ele já veio com 50,01% apurado (não recomeçou do 0%).
- O servidor detectou a nova rodada sozinho (mesma eleição 21270, geração `173854587`) e mandou o primeiro push.
- A partir de 14h40, todos os arquivos falharam com `Key 'dvt' not found`: o TSE tirou o campo dos candidatos durante a contagem. O servidor ficou parado em 50,01% e não mandou mais nenhum push até o fim da janela. Corrigido em `185114b`.
- Não deu para medir a cadência dos arquivos, porque o servidor parou de lê-los.

**29/09:**

- [ ] Rodar `swift test` no `.club` com o `185114b` e fazer o deploy antes das 14h.
- [ ] `{"source":"simulation","broadcastMode":"live"}` no `.club` e acompanhar pelo beta.
- [ ] Conferir que a última coluna do monitor fica vazia depois do primeiro arquivo novo (sem `DecodingError`).
- [ ] Conferir o `electionCode` no status quando a janela abrir. Se o TSE publicar outro código e deixar o antigo no ar, trocar a fonte para `replay` e de volta para `simulation` para o servidor resolver de novo.
- [ ] Anotar de quanto em quanto tempo o `generationId` muda e ajustar `minPushIntervalSeconds`.

### Depois da aprovação

- [ ] `{"enabled":false,"broadcastMode":"dryRun"}` no `.com` e só então liberar a versão.
- [ ] Decidir o `.club` no dia 4: configurar igual ao `.com` (os testers do beta seguem acompanhando) ou deixar desligado.

### No dia 04/10

- [ ] Quando o pleito 3220 aparecer no `ele-c.json` oficial: `{"source":"official"}` e `{"broadcastMode":"live"}`.
- [ ] Escrever as frases finais (`finalMessages`). No 1º turno, o mais provável é `runoff:13-22`.
- [ ] Cores para candidatos sem foto que possam chegar aos 2 primeiros (ex.: Caiado, 55).
- [ ] Ligar `enabled` **só depois** de o status mostrar o primeiro arquivo oficial (sem estado, o app responde "ainda não está disponível"). Mandar um push normal "a apuração começou" para a base.

### No dia 25/10

- [ ] `{"round":2}` e, se o `ele-c.json` listar a eleição do 2º turno, o servidor resolve sozinho. Conferir as fotos dos finalistas.

### Depois do 2º turno

- [ ] Trocar o `APNsBroadcastClient` pela biblioteca. O APNSwift 7.0.0 (jul/2026) já tem broadcast (envio e gestão de canais) e os campos de Live Activity do iOS 18, mas o vapor/apns 5.0.0 só aceita APNSwift abaixo da 7, e o SwiftPM não deixa ter duas versões do mesmo pacote. Então a migração é: tirar o vapor/apns (hoje na 3.0.0, com APNSwift 4.0.1), usar o APNSwift 7 direto (ou o vapor/apns, se já aceitar a 7) e reescrever todos os pushes: novo episódio, destaques da semana, sync de conteúdo em background e o envio manual.
- [ ] Desligar `enabled` nos dois servidores.

## Decisões em aberto

- Mostrar ou não candidatos anulados ("Anulado sub judice") na Live Activity. Hoje eles aparecem, como no app do TSE.
- Push-to-start (iniciar a activity remotamente) fica para depois: exige um token por aparelho.
- Ler as regras de divulgação da Resolução TSE 23.751, arts. 264 a 269.
- O alerta do resultado final acende a Tela Bloqueada de todo mundo que está acompanhando (sem som). Tirar é só remover o `alert` do `end` no `ElectionBroadcastPlanner`.
- Uma Live Activity dura no máximo 8h ativa. Quem iniciar às 17h passa da meia-noite; a apuração costuma terminar antes.

## Lições

- Arquivo final não é amostra de arquivo intermediário. O parser era rígido com campos que só o arquivo final garante, e o teste de 28/09 parou dois minutos depois de começar. Qualquer campo que não identifique o candidato precisa ter valor padrão.
- Minhas renderizações no Mac não aplicam o Dynamic Type nem o limite de 160 pt, e não sabem o raio dos cantos da Island. O que parecia certo no Mac cortou no aparelho três vezes: porcentagens truncadas, frase final cortada e barra da Island. Para a Live Activity, medir a altura e simular os tamanhos de texto antes de dar por pronto, e conferir a Island no aparelho.
- Rodar o servidor num notebook que dorme engana: o `Task.sleep` pausa junto com o sistema e parece que o poller travou.
- A CDN do TSE às vezes derruba conexões keep-alive ociosas; o retry imediato no `get` cobre isso.
- `broadcastMode` começa em `dryRun`: se a activity não atualizar num teste, o primeiro suspeito é ter esquecido `"broadcastMode":"live"`.
- Uma variável de ambiente faltando derruba a API inteira (`fatalError` em `ReleaseConfigs`), não só a eleição. Conferir o `.env` antes de chamar rotas com senha.
- O site do TSE (e o DivulgaCandContas) bloqueia clientes que não sejam navegador: `curl` recebe 403.
