# Live Activity da apuração presidencial

Resumo do trabalho feito até 25/09/2026 e do que falta. Objetivo: uma Live Activity (Tela Bloqueada + Dynamic Island) que mostra em tempo real a apuração para Presidente, com dados oficiais do TSE.

## Datas que importam

| Quando | O quê |
|---|---|
| 28 e 29/09, 14h às 16h | Janela de teste no simulado do TSE (a página do TSE só lista as semanas de 15 a 17 e 22 a 24/09; confirmar onde essa foi anunciada) |
| Até 29/09 à noite | Enviar o app para review, com o banner desligado no servidor |
| 04/10 | 1º turno: trocar a fonte para `official` e ligar `enabled` |
| 25/10 | 2º turno: trocar `round` para 2 |

## Arquitetura

```
TSE CDN --(poll a cada 10s, ETag)--> Vapor no Linode --(1 broadcast push)--> APNs --> Live Activities
                                            |
                                            +-- GET v4/election/live <-- app (estado inicial + channelId + enabled)
```

- Só o servidor fala com o TSE. O app só consome a nossa API.
- As atualizações da activity não passam pelo app: o servidor manda um push por **canal de broadcast** (iOS 18+) e o iOS atualiza todas as activities inscritas.

## Regras do TSE

- Simulado: `https://resultados-sim.tse.jus.br/simulado`, ambiente `simulado2026`. Os arquivos continuam no ar fora das janelas, parados no resultado final.
- Oficial: `https://resultados.tse.jus.br`, ambiente `oficial`. Pleito 3220, eleição federal 6257 (ainda não aparece no `ele-c.json` oficial).
- Máximo de 100 requisições por segundo por IP; 304 também conta. Se passar: bloqueio de 10 min, renovado a cada nova tentativa.
- Vários 404 também bloqueiam o IP. Por isso o servidor nunca monta URL no chute: descobre ciclo e código da eleição pelo `ele-c.json`.
- Arquivo de Presidente: `<base>/<ambiente>/<ciclo>/<eleicao>/dados/br/br-c0001-e<eleicao com 6 dígitos>-u.json`.
- No simulado, o 1º colocado é um candidato "Anulado sub judice" que vai para o 2º turno. Por isso o snapshot mantém os anulados na lista, marcados com `hasValidVotes = false`.
- Documentação: https://www.tse.jus.br/eleicoes/informacoes-tecnicas-sobre-a-divulgacao-de-resultados

## O que foi feito

### Servidor (`medo-delirio-api`, branch `main`)

Commits `04a37b1` (parser e replay) e `3d3d037` (poller e endpoints).

- `Sources/App/Election/` (só Foundation, testável sem Vapor):
  - `TSEElectionConfig`: lê o `ele-c.json` e encontra a eleição de Presidente de cada turno.
  - `TSEEndpoint`: endereços do simulado e do oficial, e a montagem das URLs.
  - `TSEResultFile`: os campos do arquivo `-u.json` que usamos.
  - `ElectionSnapshot`: nosso modelo do resultado, com candidatos na ordem `seq` do TSE, status (`counting`, `elected`, `runoff`, `notElected`) e horário de Brasília (com fallback fixo em UTC-3 se o servidor não tiver `tzdata`).
  - `ElectionReplay`: simula a apuração de 0 a 100% a partir do resultado final, com troca de liderança no caminho.
  - `ElectionLiveContentState`: o formato dos dados da activity. Tem que ser **idêntico** ao `ElectionActivityAttributes.ContentState` do app.
  - `ElectionSettings` e `ElectionLiveStore`: configuração em runtime e estado em memória do poller.
- `Services/ElectionPollingService.swift`: loop a cada 10s com `If-None-Match`. Ignora 304 e `idg` repetido. Depois de um 404, esquece a URL e só consulta o `ele-c.json` de novo após 60s. Outros erros: espera de 60s. Um retry imediato quando a CDN derruba a conexão keep-alive (`remoteConnectionClosed`).
- `Controllers/ElectionController.swift` e rotas:
  - `GET api/v4/election/live`: pública, usada pelo app. Devolve o estado mesmo com `enabled` desligado, para testers com a flag local.
  - `GET api/v4/election/status/:password`: diagnóstico.
  - `POST api/v4/election/settings/:password`: atualização parcial das configurações.
- Testes: `ElectionSnapshotTests` e `ElectionLiveTests`, com fixtures reais do simulado em `Tests/AppTests/Fixtures/Election/`. 40 testes passando.

**Variáveis de ambiente novas (obrigatórias antes do deploy):**

- `ELECTION_PASSWORD`: sem ela, as rotas de admin derrubam o processo com `fatalError`.
- `ELECTION_POLLING_ENABLED=true`: liga o poller.

**Configurações em runtime** (um JSON em `ServerSetting`, chave `election-settings`):

```bash
# Ver o estado
curl https://<servidor>/api/v4/election/status/<senha>

# Trocar para o oficial no dia 4
curl -X POST -H 'Content-Type: application/json' -d '{"source":"official"}' https://<servidor>/api/v4/election/settings/<senha>

# Lançamento público
curl -X POST -H 'Content-Type: application/json' -d '{"enabled":true}' https://<servidor>/api/v4/election/settings/<senha>

# Replay de 15 minutos (recomeça do 0%)
curl -X POST -H 'Content-Type: application/json' -d '{"source":"replay","replayDurationMinutes":15,"restartReplay":true}' https://<servidor>/api/v4/election/settings/<senha>

# Cores por número de urna
curl -X POST -H 'Content-Type: application/json' -d '{"candidateColors":{"13":"#D62828","22":"#1D4E89"}}' https://<servidor>/api/v4/election/settings/<senha>
```

Campos aceitos: `enabled`, `source` (`simulation`, `official`, `replay`), `round` (1 ou 2), `channelId` (string vazia apaga), `candidateColors`, `replayDurationMinutes`, `restartReplay`.

**Rodar localmente** (banco em memória e sem APNs, não precisa das chaves de produção):

```bash
cd medo-delirio-api
ELECTION_POLLING_ENABLED=true ELECTION_PASSWORD=local-test swift run Run serve --env testing --port 8089
```

Testado assim contra o simulado real: o poller encontrou a eleição 21270, os 304 funcionaram, e um replay de 3 minutos rodou 18 ciclos de 10s sem erro, com o líder trocando a 93,68%.

### App (`MedoDelirioiOSApp`, branch `main`)

Commits `c2e03f5b` (Live Activity e flag) e `f67997c1` (banner).

- `MedoDelirioWidget/Election/ElectionActivityAttributes.swift`: formato dos dados, compartilhado com o app pela exception set do projeto (mesmo mecanismo do `PlayRandomSoundIntent`). Sem `Date` e com chaves camelCase, para o mesmo JSON servir no endpoint (decoder do app com ISO 8601 e snake case) e no push (decoder padrão do ActivityKit).
- `MedoDelirioWidget/Election/ElectionLiveActivity.swift`: Tela Bloqueada (top 4 com barras, % apurado, rodapé "Fonte: TSE", aviso de atualização atrasada, resultado final) e Dynamic Island (compacto: líder e %; minimal: anel da apuração; expandido: top 3). Tem previews.
- `Info.plist` do app: `NSSupportsLiveActivities` e `NSSupportsLiveActivitiesFrequentUpdates`.
- `Sources/Helpers/ElectionLiveActivityManager.swift`: inicia com `pushType: .channel(channelId)`, não duplica activity do mesmo turno, mensagens de erro em português, `endAll()`.
- `Sources/Networking/APIClient+Election.swift`: `GET v4/election/live`.
- `Sources/Views/Banners/ElectionLiveBannerView.swift`: banner no topo do `BannersView` com "Acompanhar ao Vivo" e "Parar de Acompanhar", alerta quando as Atividades ao Vivo estão desligadas e eventos de analytics.
- **Feature flag `electionLiveActivity`** (Dev Options): o banner aparece se o `enabled` do servidor **ou** a flag local estiver ligada. Beta e prod usam o mesmo servidor, então é assim que se testa sem vazar para prod.

Só passou por typecheck com `swiftc`. **Ainda não teve build completo nem rodou em aparelho.**

## O que falta

### 1. Antes de tudo, na máquina nova

- [ ] `git pull` nos dois repositórios (todos os commits acima já estão no remoto).
- [ ] Build completo do app no Xcode e conferir os previews da Live Activity.

### 2. Broadcaster da APNs (servidor)

O ponto de encaixe é `didReceive(_:)` no `ElectionPollingService`.

- [ ] Ver se a dependência atual (`apns` 3.0.0 / `apnswift` 4.0.1) suporta Live Activity e broadcast. Se não suportar, fazer HTTP/2 direto com JWT (ES256), reaproveitando a chave `.p8`.
- [ ] Criar o canal pela Channel Management API da APNs e guardar o `channelId` nas configurações.
- [ ] **Canal por bundle ID:** beta (`com.rafaelschmitt.MedoDelirioBrasilia.beta`) e prod (`com.rafaelschmitt.MedoDelirioBrasilia`) são apps diferentes para a APNs, então precisam de canais diferentes. Hoje o `v4/election/live` devolve um `channelId` só: o app precisa mandar o próprio bundle ID (ou o servidor devolve um mapa) e o broadcaster precisa enviar para os dois canais.
- [ ] Payload: `aps.timestamp`, `aps.event` (`update` ou `end`), `aps.content-state` (o `ElectionLiveContentState`), `aps.stale-date` e, no fim, `aps.dismissal-date`. Header `apns-push-type: liveactivity`.
- [ ] Throttle: no máximo 1 push a cada 30 a 60s. Prioridade 10 só em momentos relevantes (troca de liderança, marcos de %, resultado final), o resto em prioridade 5.
- [ ] Mandar `end` quando `isFinal` virar `true`.
- [ ] Modo dry-run (só registra o payload no log).

### 3. Portal da Apple

- [ ] Ativar a capability de Broadcast Push no App ID de prod e no de beta.

### 4. Deploy e testes

- [ ] Deploy no Linode com `ELECTION_PASSWORD` e `ELECTION_POLLING_ENABLED=true`.
- [ ] Teste ponta a ponta com replay, via TestFlight (APNs de produção). Um build rodado direto do Xcode usa sandbox e não recebe pushes de um canal de produção.
- [ ] 28/09: teste no simulado ao vivo. Medir a cadência real dos arquivos e ajustar o throttle.
- [ ] 29/09: enviar para review com `enabled` desligado.

### 5. No dia 04/10

- [ ] Quando o pleito 3220 aparecer no `ele-c.json` oficial: `{"source":"official"}`.
- [ ] Configurar as cores dos candidatos reais.
- [ ] `{"enabled":true}` e mandar um push normal "a apuração começou" para a base.

## Decisões em aberto

- Mostrar ou não candidatos anulados ("Anulado sub judice") na Live Activity. Hoje eles aparecem, como no app do TSE.
- Fotos dos candidatos (fora do MVP). Caminho possível: o app baixa para o App Group e a extensão lê de lá.
- Push-to-start (iniciar a activity remotamente) fica para depois: exige um token por aparelho.
- Ler as regras de divulgação da Resolução TSE 23.751, arts. 264 a 269.

## Lições

- Rodar o servidor num notebook que dorme engana: o `Task.sleep` pausa junto com o sistema e parece que o poller travou. No teste do dia 28, a máquina precisa estar acordada e na tomada (ou usar o Linode).
- A CDN do TSE às vezes derruba conexões keep-alive ociosas; o retry imediato no `get` cobre isso.
