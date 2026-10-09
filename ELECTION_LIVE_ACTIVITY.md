# Live Activity da apuração presidencial

Resumo do trabalho feito até 04/10/2026, o dia do 1º turno, e do que falta para o 2º. Objetivo: uma Live Activity (Tela Bloqueada + Dynamic Island) que mostra em tempo real a apuração para Presidente, com dados oficiais do TSE.

## Situação em 04/10

- **1º turno feito.** A Live Activity acompanhou a apuração no `.com` do começo ao fim, espelhando o site do TSE. Pelo menos 1.905 instalações iniciaram pelo banner, entre 9% e 13% delas fora do Brasil (ver "1º turno (04/10)"). **Vai ter 2º turno, dia 25/10, entre Lula (13) e Flávio Bolsonaro (22).**
- **Na loja:** a 13.1 (tela de resultados, cartão para compartilhar e link do TSE) saiu em 03/10, e a 13.2 foi aprovada em 04/10. A 13.0 também tem a Live Activity.
- **Servidor:** fonte `official`, round 1, `live`, `enabled` ligado. Tudo do 1º turno está no ar, menos o endpoint de analytics (`c68eff0`), que fica para o deploy de 05/10.
- **Próximo passo, 05/10:** desligar o banner, voltar a `dryRun` e fazer o deploy do endpoint (ver "O que falta").

## Datas que importam

| Quando | O quê |
|---|---|
| 28 e 29/09, 14h às 16h | Janela de teste no simulado do TSE ("3ª semana de testes (semana extra)", aba Simulados da página técnica do TSE, conferido em 25/09) |
| 28/09 | Versão 13 aprovada pela revisão |
| 03/10 | Versão 13.1 aprovada e liberada, depois de uma recusa e de um pedido de revisão urgente |
| 04/10 | 1º turno. Totalização a partir das 17h de Brasília. Versão 13.2 aprovada |
| 25/10 | 2º turno, confirmado: trocar `round` para 2. A tela de novidades deixa de aparecer a partir do dia 26 |

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
- Oficial: `https://resultados.tse.jus.br`, ambiente `oficial`. Pleito 3220, ciclo `ele2026`, eleição 6257 (Presidente, 1º turno). Arquivo de Presidente: `https://resultados.tse.jus.br/oficial/ele2026/6257/dados/br/br-c0001-e006257-u.json`.
- Máximo de 100 requisições por segundo por IP; 304 também conta. Se passar: bloqueio de 10 min, renovado a cada nova tentativa.
- Vários 404 também bloqueiam o IP. Por isso o servidor nunca monta URL no chute: descobre ciclo e código da eleição pelo `ele-c.json`.
- Arquivo de Presidente: `<base>/<ambiente>/<ciclo>/<eleicao>/dados/br/br-c0001-e<eleicao com 6 dígitos>-u.json`.
- Fotos (não documentado, visto no app de resultados do TSE): `<base>/<ambiente>/<ciclo>/<eleicao>/fotos/<uf>/<sqcand>.jpeg`. O `sqcand` vem no `-u.json`.
- **Os arquivos publicados durante a apuração não têm todos os campos do arquivo final.** No simulado de 28/09, os candidatos vieram sem `dvt` (destino do voto) no meio da contagem, e o arquivo final (16h36) tinha o campo em todos. Nossas fixtures são arquivos finais, então não mostravam isso. Por isso, só o que identifica o arquivo e o candidato é obrigatório (ver `TSEResultFile`).
- **Antes da apuração começar, o arquivo vem sem horário de totalização.** No simulado de 29/09, o arquivo de 0% tinha `dt` e `ht` vazios; só `dg` e `hg` (data e hora em que o TSE gerou o arquivo) estavam preenchidos.
- **No oficial, o arquivo de 0% sai na véspera.** Em 04/10 de manhã, a eleição 6257 já estava no `ele-c.json`, com um arquivo de 0% gerado em 03/10 às 14h47 (geração `1070425`, `dt`/`ht` vazios). O primeiro arquivo não é o sinal de que a contagem começou: o sinal é a % passar de zero, depois das 17h.
- **"Atualizado às" é a hora de totalização do arquivo,** não a do push. No começo da noite, o TSE ficou uns 11 minutos sem publicar (de 17h58 a 18h09). Isso parece atraso no celular, mas não é.
- No simulado, o 1º colocado é um candidato "Anulado sub judice" que vai para o 2º turno. Por isso o snapshot mantém os anulados na lista, marcados com `hasValidVotes = false`.
- Documentação: https://www.tse.jus.br/eleicoes/informacoes-tecnicas-sobre-a-divulgacao-de-resultados

## O que foi feito

### Servidor (`medo-delirio-api`, branch `main`)

Commits `04a37b1` (parser e replay), `3d3d037` (poller e endpoints), `463526b` (broadcaster da APNs), `b517463` (replay realista e offline) e `39ad257` (frases finais).

- `Sources/App/Election/` (só Foundation, testável sem Vapor):
  - `TSEElectionConfig`: lê o `ele-c.json` e encontra a eleição de Presidente de cada turno.
  - `TSEEndpoint`: endereços do simulado e do oficial, e a montagem das URLs.
  - `TSEResultFile`: os campos do arquivo `-u.json` que usamos.
  - `ElectionSnapshot`: nosso modelo do resultado, com candidatos na ordem `seq` do TSE, nome de urna (`nmu`), status (`counting`, `elected`, `runoff`, `notElected`) e horário de Brasília (com fallback fixo em UTC-3 se o servidor não tiver `tzdata`). Campos de contagem vazios ou ausentes (votos, porcentagens, seções) contam como 0, posição vazia vai para o fim, por votos, `dvt` ausente conta como voto válido, nome de urna ausente cai para o nome completo e depois para "Candidato 13", e sem `and` a apuração não é final. Sem `dt`/`ht`, o horário é o de geração do arquivo (`dg`/`hg`): usar a hora atual fazia o estado "mudar" a cada tick e disparava um push por intervalo sem dado novo. Só código da eleição, turno, geração, a estrutura de cargos e o número do candidato são obrigatórios (commits `560b630`, `185114b` e `eed02d0`).
  - `ElectionReplay`: simula a apuração de 0 a 100% a partir do resultado final, com troca de liderança no caminho. Avança em saltos de `replayStepSeconds` (padrão 60s, como arquivos novos do TSE), cada salto com o próprio horário de totalização, e numa curva rápida no começo e lenta no fim (metade da apuração em um quarto do tempo).
  - `ElectionReplayFixture`: o resultado final do simulado (eleição 21270) embutido no servidor. O replay usa esse resultado com `replayOffline: true`, ou sozinho quando o TSE não responde ou não lista o simulado. Um teste garante que ele é idêntico à fixture.
  - `ElectionLiveContentState`: o formato dos dados da activity. Tem que ser **idêntico** ao `ElectionActivityAttributes.ContentState` do app (ver "Contrato com o app").
  - `ElectionSettings` e `ElectionLiveStore`: configuração em runtime e estado em memória do poller. As configurações decodificam com valores padrão para chaves ausentes, então um campo novo não quebra o JSON já salvo no banco.
  - `ElectionBroadcastPlanner`: decide quando mandar push, com qual prioridade, e monta o payload (ver "Broadcaster").
- `Services/ElectionPollingService.swift`: loop a cada 10s com `If-None-Match`. Ignora 304 e `idg` repetido. Depois de um 404, esquece a URL e só consulta o `ele-c.json` de novo após 60s. Outros erros: espera de 60s. Um retry imediato quando a CDN derruba a conexão keep-alive (`remoteConnectionClosed`).
- `Services/APNsBroadcastClient.swift`: HTTP/2 direto para a APNs (o APNSwift 4.0.1 não tem Live Activity nem broadcast), com JWT ES256 assinado pela mesma chave `.p8` e reaproveitado por 50 min. Envia broadcast (`POST /4/broadcasts/apps/<bundle>`), cria e lista canais (Channel Management API, portas 2195/2196). O ambiente segue o `APNS_ENVIRONMENT`.
- `Controllers/ElectionController.swift` e rotas:
  - `GET api/v4/election/live?bundleId=<bundle>`: pública, usada pelo app. O `channelId` é o do bundle pedido (sem `bundleId`, o de prod; sem fallback do beta para o de prod, porque um canal só serve para o app dele). Também traz `details` (todos os candidatos, com votos, e as seções; `ElectionLiveDetails`, fora do payload do push, que tem limite de 5 KB) e `officialResultsURL` (o link "App do TSE" do app). Apps antigos ignoram os dois (`472b4a7`). No resultado final, traz também `finalTheme`, o `theme` da frase final escolhida (ver "Frases finais").
  - `GET api/v4/election/status/:password`: diagnóstico, com o último push (`lastBroadcastAt`, `lastBroadcastEvent`, `lastBroadcastPriority`, `lastBroadcastReason`, `lastBroadcastError`). Campos vazios não aparecem na resposta.
  - `POST api/v4/election/settings/:password`: atualização parcial das configurações.
  - `POST api/v4/election/channels/:password[?bundleId=]`: cria o canal de cada app que ainda não tem um (ou só do bundle pedido), no ambiente atual da APNs, e salva nas configurações.
  - `GET api/v4/election/channels/:password`: mostra o ambiente da APNs, os canais configurados e os que a APNs conhece para cada bundle.
  - `GET api/v4/election-live-analytics/:password` (senha de analytics, `c68eff0`, deploy em 05/10): instalações que iniciaram e pararam pelo banner, estimativa de quem ainda está acompanhando, fechamentos da tela de novidades, por hora (UTC) e por versão. `?since=` em ISO 8601, padrão 24 h atrás.
  - `GET api/v4/election-live-analytics/series/:password` (senha de analytics, `4a7dc09`): a mesma contagem como série para gráfico, em intervalos de `?bucketMinutes=` (5, 10, 15, 30 ou 60; padrão 10) entre `?since=` e `?until=` (no máximo 48 h). Cada intervalo traz quem iniciou, quem iniciou pela primeira vez, o total acumulado (a linha principal), quem parou e a estimativa de quem ainda estava acompanhando, com o horário em UTC e em Brasília. Para o 1º turno: `?since=2026-10-04T20:00:00Z&until=2026-10-05T06:00:00Z`.
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
- Se todos os canais falham, nada é registrado e o servidor **espera pelo menos 60 s** (ou `minPushIntervalSeconds`, se for maior) antes de tentar de novo (`4e942d0`). Antes, tentava no tick seguinte, a cada 10 s, e isso mantinha o canal bloqueado pelo APNs (429). A Apple pede para repetir `TooManyRequests` "com um intervalo" e diz que erros 4XX reduzem a vazão do provedor; não publica limite numérico por canal. Se só um canal falha, o envio conta como feito (repetir mandaria de novo para o outro) e o erro aparece no status.

#### Frases finais

O push de fim sai assim que o TSE encerra a apuração, então as frases são escritas **com antecedência**, uma por desfecho. O servidor escolhe a mais específica: `elected:13`, `elected`, `runoff:13-22` (números em ordem crescente), `runoff`, `default`. Sem frase, sai o texto neutro.

- `text` aparece na activity em negrito, entre a barra e o rodapé. O rodapé continua neutro, com "Fonte: TSE".
- `alertTitle` e `alertBody` substituem o alerta neutro "Apuração encerrada".
- `{diferença}` (ou `{diferenca}`, sem cedilha) vira a diferença de votos entre o 1º e o 2º no resultado final, como "2.003.696", no texto e nos dois campos do alerta. O servidor faz a troca, então funciona em qualquer versão do app. A frase salva continua com o marcador. Exemplo: `"elected:13":{"text":"Lula venceu por {diferença} votos. Um deles foi seu."}`.
- `theme` (`celebration` ou `comfort`) decide como a tela de resultados do app veste o resultado final: `celebration` é confete, vibração de fogos e o cartão em vermelho; `comfort` é o cartão virando noite com estrelas aparecendo, sem som nem vibração. A imagem de compartilhar usa o mesmo fundo. Vai só no `GET election/live` (`finalTheme`), nunca no push, e só depois do fim. Outro valor é recusado pelo servidor, e o app ignora valores que não conhece. Sem `theme`, a tela fica verde, como sempre.
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

# Replay em loop: 15 min de contagem, 5 min no resultado final, e recomeça do 0%.
# Cada volta termina com o push de fim, que encerra as Live Activities; a próxima volta precisa de uma nova.
curl -s -X POST -H 'Content-Type: application/json' -d '{"source":"replay","replayOffline":true,"replayLoop":true,"replayLoopPauseMinutes":5,"replayStepSeconds":45,"replayDurationMinutes":15,"restartReplay":true,"broadcastMode":"live"}' https://<servidor>/api/v4/election/settings/<senha> | jq

# Replay do 2º turno: os dois finalistas do simulado (57 e 89, candidatos de teste do TSE), com o 89 virando perto do fim
# e terminando eleito com 50,83%. Mudar o round apaga o estado do turno anterior.
curl -s -X POST -H 'Content-Type: application/json' -d '{"round":2,"source":"replay","replayOffline":true,"replayLoop":true,"replayLoopPauseMinutes":5,"replayDurationMinutes":30,"replayStepSeconds":60,"restartReplay":true,"broadcastMode":"live"}' https://<servidor>/api/v4/election/settings/<senha> | jq

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

# Link "App do TSE" do app (string vazia volta ao padrão, o app Resultados na App Store)
curl -X POST -H 'Content-Type: application/json' -d '{"officialResultsURL":"https://resultados.tse.jus.br/oficial/app/index.html"}' https://<servidor>/api/v4/election/settings/<senha>

# Frases finais
curl -X POST -H 'Content-Type: application/json' -d '{"finalMessages":{"runoff:13-22":{"text":"Segura que tem 2º turno. Bora!"},"default":{"text":"Acabou a apuração."}}}' https://<servidor>/api/v4/election/settings/<senha>

# Frases finais do 2º turno, com o clima da tela de resultados
curl -s -X POST -H 'Content-Type: application/json' -d '{"finalMessages":{"elected:13":{"text":"Lula venceu por {diferença} votos. Um deles foi seu.","theme":"celebration"},"elected:22":{"text":"Hoje não precisa ser forte. Larga o celular, abraça alguém.","theme":"comfort"}}}' https://<servidor>/api/v4/election/settings/<senha> | jq
```

Campos aceitos: `enabled`, `previewVersions` (lista de versões do app, como `"13.1"`, que veem o banner com `enabled` desligado; substitui a lista, `[]` limpa), `source` (`simulation`, `official`, `replay`), `round` (1 ou 2), `channelIds` (mapa bundle ID → canal, mesclado; string vazia apaga), `broadcastMode` (`off`, `dryRun`, `live`), `minPushIntervalSeconds`, `candidateColors`, `finalMessages`, `replayDurationMinutes`, `replayStepSeconds` (0 = avança a cada poll), `replayOffline`, `replayLoop` (recomeça do 0% depois do resultado final), `replayLoopPauseMinutes` (quanto o resultado final fica antes de recomeçar, padrão 5), `restartReplay`, `officialResultsURL` (só https).

#### Conferir um servidor sem os logs

Nesta ordem, porque as rotas com senha derrubam o processo se a senha faltar:

1. `GET api/v2/status-check` → 200.
2. `GET api/v4/election/live` → 200 com `state` preenchido (poller rodando). 404 = código da eleição não subiu.
3. Conferir no servidor que `ELECTION_PASSWORD` está no `.env` (`grep -c "^ELECTION_PASSWORD=." .env`), e só então `GET election/status/<senha>`. Os campos `finalMessages`, `replayStepSeconds` e `replayOffline` em `settings` provam que é a versão mais recente.
4. `GET election/channels/<senha>` → `apnsEnvironment: production` e `errors` vazio.
5. `GET election/live?bundleId=<bundle>` → `channelId` preenchido.
6. Replay em `dryRun` e ver `lastBroadcastAt` e `lastBroadcastReason` avançando, sem `lastBroadcastError`.

**Monitor** (uma linha a cada 10 s: hora, eleição, geração, % apurado, FINAL, último motivo de push, erro):

```bash
while true; do curl -s https://<servidor>/api/v4/election/status/<senha> | python3 -c 'import sys,json,datetime; d=json.load(sys.stdin); print(datetime.datetime.now().strftime("%H:%M:%S"), d.get("electionCode"), d.get("generationId"), round(d.get("sectionsCountedPercent") or 0, 2), "FINAL" if d.get("isFinal") else "", d.get("lastBroadcastReason") or "", d.get("lastBroadcastError") or d.get("lastError") or "")'; sleep 10; done
```

A penúltima coluna é o motivo do **último** push, não um push por linha: ela só muda quando sai um push novo. Um `JSONDecodeError` do Python durante um deploy é a página de erro do nginx, não problema do servidor.

#### Serviço nos servidores (systemd)

Os dois servidores rodam a API como o serviço `medo-delirio-api` do systemd, que reinicia sozinho se o processo cair e sobe no boot. O `.com` foi migrado do `screen` em agosto, e o `.club` em 08/10 (usuário `root`, pasta `/root/medo-delirio-api`).

O arquivo do `.club` (`/etc/systemd/system/medo-delirio-api.service`):

```ini
[Unit]
Description=Medo e Delírio API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/medo-delirio-api
ExecStart=/root/medo-delirio-api/.build/release/Run serve --hostname 0.0.0.0 --env production
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

- **Sem `EnvironmentFile`.** O Vapor lê o `.env` da pasta de trabalho sozinho. Com `EnvironmentFile`, o systemd interpreta as barras invertidas do `.env`, e os `\n` da `APNS_PRIVATE_KEY` deixam de ser `\n`. Como o Vapor não sobrescreve uma variável que já existe, a chave chega estragada e o servidor cai no boot com `JWTKit error: signing algorithm error: bioConversionFailure`, reiniciando em loop (nginx responde 502). Foi o que aconteceu na migração do `.club`.
- **Variáveis só no `.env`.** O serviço não herda nada do terminal: uma variável que antes ia na linha do `screen` (como `ELECTION_POLLING_ENABLED=true`) precisa estar no `.env`.

**Migrar um servidor do `screen` para o serviço:**

1. Ler como ele roda hoje: `pgrep -af 'Run serve'` (comando e PID), `ps -o user= -p <PID>` (usuário), `sudo readlink /proc/<PID>/cwd` (pasta).
2. Conferir as variáveis do processo contra o `.env`: `sudo cat /proc/<PID>/environ | tr '\0' '\n' | cut -d= -f1` e `grep -oE '^[A-Z_]+' <pasta>/.env`. O que faltar no `.env` vai para lá.
3. Criar o arquivo acima com o usuário, a pasta e o comando do passo 1, e rodar `sudo systemctl daemon-reload` e `sudo systemctl enable medo-delirio-api`.
4. Parar o `screen` (`screen -ls`, `screen -S <nome> -X quit`), conferir que `pgrep -af 'Run serve'` não mostra nada, e `sudo systemctl start medo-delirio-api`.
5. Conferir: `systemctl status medo-delirio-api --no-pager` (`active (running)`, sem o contador de reinícios subindo) e o `status-check` respondendo 200.

**No dia a dia:**

```bash
# Deploy: compila com o servidor no ar e só reinicia no fim
cd <pasta> && git pull && swift build -c release && sudo systemctl restart medo-delirio-api

# Logs ao vivo (antes ficavam dentro do screen)
journalctl -u medo-delirio-api -f

# Pushes e arquivos do TSE de uma noite, para medir a cadência
journalctl -u medo-delirio-api --since "2026-10-04 20:00" | grep -E 'Election push|Election poll: generation'

# Parar e subir
sudo systemctl stop medo-delirio-api
sudo systemctl start medo-delirio-api
```

#### Rodar localmente

Banco em memória e sem APNs, não precisa das chaves de produção:

```bash
cd medo-delirio-api
ELECTION_POLLING_ENABLED=true ELECTION_PASSWORD=local-test swift run Run serve --env testing --port 8089
```

**Toolchain:** os Xcode 27 e 27.1 beta (e as Command Line Tools, com o mesmo Swift 6.4) geram binários para o runtime do macOS 27. No macOS 26.7, o `swift test` compila mas falha ao carregar o bundle (`Symbol not found: _swift_initBorrow`). Manter o Xcode 26.6 instalado (pelo Xcodes) e rodar os testes da API com ele:

```bash
DEVELOPER_DIR=/Applications/Xcode_26.6.app/Contents/Developer swift test
```

### App (`MedoDelirioiOSApp`, branch `main`)

Commits de 24 e 25/09: `c2e03f5b` (Live Activity e flag), `f67997c1` (banner), `a8f09c0b` (canal por app). De 26 e 27/09: `aa88ce0b` (servidor da eleição no beta), `d083256a` (redesign), `a36220fd` (fotos e frase final), `9880433a` (fontes fixas), `0cec3004` (Dynamic Island), `2baeee60` (banner), `2d34f27f` (fim da flag), `7ad79c46` (tela de novidades), `c7fb25c1` (tecla CONFIRMA), `25a5d896` (texto da data), `60743c3d` (limites da Tela Bloqueada e da Island). De 29/09: `3d3b247c` (tela de resultados, cartão e link do TSE).

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

#### Tela de resultados (`Sources/Views/Election/ElectionResultsView.swift`)

Para a próxima versão, depois da 13. Enquanto a Live Activity é a espiada, esta tela é onde a pessoa vai para ver o resto.

- **Como se chega:** pelo link `medodelirio://apuracao` (`DeepLink.electionResults`), que abre uma sheet no `MainView`. Tocar na Live Activity (`widgetURL` na Tela Bloqueada e na Dynamic Island) e o botão "Ver Resultados" do banner usam esse link. Se ele chegar com a tela de novidades aberta, os resultados abrem quando ela fechar (duas sheets não trocam no mesmo instante).
- **Topo verde**, no estilo da Live Activity: "PRESIDENTE · 1º TURNO · AO VIVO" com o ponto vermelho (ou "RESULTADO"), o totalizado grande, a barra amarela, "X de Y seções", o horário com a fonte e a frase final.
- **Para o 2º turno (versão seguinte à 13.3):** o topo verde virou um frente a frente dos dois primeiros, com o líder à esquerda (foto, porcentagem, nome, partido, votos e selo "ELEITO"/"2º TURNO"), uma barra dividida entre os dois com uma marca nos 50%, e o totalizado discreto embaixo. A lista de todos os candidatos saiu.
- **Brancos, nulos e abstenção** (`details.turnout`, servidor a partir do commit que lê `e.te`, `e.c`, `e.a`, `v.tv`, `v.vb` e `v.tvn` do arquivo do TSE): três cartões no lugar da lista. Brancos e nulos sobre o total de votos, abstenção sobre o eleitorado, nas seções já apuradas. Sem o bloco (servidor antigo, campo estranho no arquivo), a seção não aparece.
- **Ações:** "Acompanhar na Tela Bloqueada"/"Parar de Acompanhar", "Compartilhar" e "App do TSE".
- **Atualização:** a cada 20 s com a tela aberta, e puxando para baixo. Se uma atualização falha, os últimos números ficam.
- **Casos especiais:** "A apuração ainda não começou" (sem estado) e erro de conexão, com link para o app do TSE.
- **Cartão para compartilhar** (`ElectionShareCard`, na tela `ElectionShareView`): quadrado (1080 × 1080) ou stories (1080 × 1920), com o fundo verde e os teclados de urna, os dois primeiros com foto e porcentagem, o totalizado, a logo e o nome do app, a fonte e o horário, e a frase final. As fotos do TSE têm só 161 px e ficam um pouco suaves no cartão.
  - **Stories:** 84 pt livres em cima e embaixo (a área que o Instagram cobre), blocos em grupos com espaçadores flexíveis, "Criado com o app Medo e Delírio para iOS" no rodapé e, no resultado final, o título quebrado antes de "RESULTADO". O conteúdo quase preenche a área livre: nomes em duas linhas junto com frase final em duas linhas é o caso a conferir.
  - **Na tela:** com stories escolhido, um chamado para marcar o podcast, e tocar no @medoedelirioembrasiliapodcast copia o nome. O botão mostra um spinner da hora do toque até a share sheet fechar (gerar a imagem e abrir a sheet levam 1 ou 2 s). Depois de um compartilhamento concluído, a tela fecha e os resultados mostram um toast ("Imagem salva nas Fotos." ou "Imagem compartilhada com sucesso.").
- **Link "App do TSE":** no banner (abaixo de "Acompanhar ao Vivo", com um respiro a mais) e na tela. Por padrão abre o app **Resultados**, do Tribunal Superior Eleitoral, na App Store (`apps.apple.com/br/app/resultados/id1136359313`); quem já tem o app instalado abre direto de lá. O endereço vem do servidor (`officialResultsURL`) e pode mudar sem nova revisão. O site de resultados (`resultados.tse.jus.br/oficial/app`) dava 404 em 29/09.
- **Fotos no app:** as cinco (13, 14, 22, 30, 70) estão também no catálogo do app, além do widget.
- **Sem o `details` no servidor** (antes do deploy do `472b4a7`), a tela mostra só o topo, sem a lista.
- **Analytics:** a partir da versão seguinte à 13.2, iniciar e parar a Live Activity por aqui manda os mesmos eventos do banner (`election_live_activity_started` e `_stopped`), com `originatingScreen` `ElectionResults`. Os endpoints de analytics contam as duas origens. Na 13.1 e na 13.2 a tela não manda eventos.

#### Tela de novidades (`Sources/Views/Onboarding/WhatsNew/IntroducingElectionLiveView.swift`)

- Aparece uma vez, depois do onboarding, antes das telas de Clipes e Transcrições. **Não aparece a partir de 26/10.**
- **Header:** as fotos do Lula e do Flávio se chocam e voltam; a cada choque, um anel amarelo explode no ponto de contato e o "% TOTALIZADO" e a barra andam um passo, até 100% e recomeçar. Com Reduzir Movimento, fica parado.
- **Fundo do header:** mini teclados de urna (1 a 9, 0 embaixo do 8, BRANCO, CORRIGE e CONFIRMA nas cores reais, ponto de braille em cada tecla), poucos, grandes e apagados, sumindo atrás das fotos e do título. Menores ou mais densos viram ruído.
- **Itens:** Na Tela Bloqueada; Dados Oficiais do TSE; a data. Até a 13.2, "4 de Outubro, às 17h de Brasília"; a partir da versão seguinte, "2º Turno: 25 de Outubro, às 17h" (Lula e Flávio Bolsonaro).
- **Botão:** a tecla CONFIRMA da urna (face verde sobre um degrau mais escuro, "CONFIRMA" em fonte monoespaçada, o texto em braille embaixo). Afunda ao apertar, com vibração forte e o "piririm" da urna (`Resources/ElectionStuff/urna_confirma.caf`, tocado como som de sistema: respeita a chave de silencioso e não interrompe outros áudios).
- As fotos do Lula e do Flávio também estão no catálogo do app (`ElectionCandidate13` e `22`), porque o app não enxerga o catálogo do widget.
- **Dev Options:** "Reexibir Election Live What's New" e "Resetar Election Live What's New" (vale na próxima abertura do app).

### Também na versão 13 (fora da eleição)

- **Splash** (`36f09137`): o logo dos 4 anos saiu. Logo preto no fundo claro e branco no escuro, com as @2x geradas das @3x. Os arquivos originais vieram com `light` e `dark` trocados em relação à convenção do projeto (`light` = modo claro = logo preto); foram aplicados pelo conteúdo. O iOS guarda a splash em cache: se a antiga aparecer depois de atualizar, reiniciar o aparelho.
- **Tela de autor** (`81ba2caa`): no layout largo (Duo aberto, iPad), a descrição, os links e a contagem se alinham com o nome em vez de centralizar ao lado da foto. Os links das redes sociais foram para a linha do "15 SONS" (`SoundCountAndLinks`), com fallback para botões só com ícone e depois para duas linhas.

## Revisão da App Store

Na versão 13, só os revisores tinham esse código no app de prod, e bastava ligar `enabled`. **A partir da 13.1, a 13.0 está na loja com o banner**: ligar `enabled` mostraria o replay de teste ("CANDIDATO 9999") para todo mundo. Por isso o servidor libera o banner só para as versões em `previewVersions`. Desde a 13.1, o app manda a versão no `?appVersion=` do `v4/election/live`; a 13.0 não manda e só vê o banner com `enabled` ligado. (O primeiro build da 13.1, que ainda não mandava a versão, foi recusado pela revisão porque o banner estava desligado, e depois retirado. Por um tempo, o servidor separou as versões pelo build no User-Agent; isso foi trocado pela versão.)

1. Ligar a **Broadcast Capability** no App ID de prod antes de arquivar.
2. Arquivar sem o Dev Options aberto.
3. Enviar com **liberação manual** e as notas abaixo.
4. Durante a revisão, deixar o `.com` assim, com a versão em revisão em `previewVersions` (replay de 24h; se a revisão passar de um dia, mandar de novo):

```bash
curl -s -X POST -H 'Content-Type: application/json' -d '{"enabled":false,"previewVersions":["13.1"],"source":"replay","replayOffline":true,"replayDurationMinutes":1440,"replayStepSeconds":60,"restartReplay":true,"broadcastMode":"live"}' https://api.medodelirioios.com/api/v4/election/settings/<senha> | jq
```

   Conferir antes de enviar: o mesmo build pelo TestFlight mostra o banner, e a versão da loja não.

5. Depois da aprovação, **antes de liberar:**

```bash
curl -s -X POST -H 'Content-Type: application/json' -d '{"enabled":false,"previewVersions":[],"broadcastMode":"dryRun"}' https://api.medodelirioios.com/api/v4/election/settings/<senha> | jq
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

## 1º turno (04/10)

**Como foi:**

- Às 10h, um teste no `.club` (fonte `official`, `dryRun`, banner desligado) já achou a eleição 6257 e o arquivo de 0% da véspera, idêntico ao do TSE.
- 16h: `.com` em `official`, `live`, `minPushIntervalSeconds` 60, banner desligado. O arquivo de 0% entrou e saiu como `first push`, num canal ainda sem inscritos.
- Até 17h12 a geração continuou a de 0%, e o próprio arquivo do TSE confirmava: nada publicado ainda. O banner foi ligado depois que a % passou de zero. Não houve erro de push na noite.
- **Latência:** o arquivo totalizado às 18h09:09 foi gerado pelo TSE às 18h10:48, e o nosso push saiu às 18h11:16, menos de 30 s depois.
- Às 99,04%, os números do app e os do site do TSE batiam.

**Uso** (eventos `election_live_activity_started` e `_stopped` do banner desde as 17h):

| | |
|---|---|
| **Instalações que iniciaram, na última consulta da noite** | **1.905** (soma da consulta por fuso horário) |
| Na consulta das ~19h30 | 1.536 instalações (1.720 inícios), 157 pararam pelo banner |
| Por hora de Brasília, às ~19h30 | 17h: 861 · 18h: 628 · 19h: 161 (hora incompleta) |
| Por versão, às ~19h30 | 13.1: 1.047 · 13.2: 324 · 13: 204 |

É um piso: a tela de resultados da 13.1 não manda evento, e só entram os inícios que deram certo. As horas e as versões somam mais que o total porque a mesma instalação pode aparecer em mais de uma.

**Fora do Brasil** (pelo `currentTimeZone`, a abreviação que o aparelho escolhe, que muda com o idioma do sistema): 1.646 no Brasil com certeza (BRT 1.613, AMT 32, ACT 1); 177 fora com certeza (Europa 131, com Portugal, Reino Unido e Europa central; costa oeste dos EUA 24; Ásia e Oceania 19, incluindo Sydney na segunda de manhã); 82 ambíguos (GMT−4, −5 e −3, que podem ser o Brasil num aparelho em outro idioma ou as Américas). Entre 9% e 13% acompanharam de fora.

**Tropeços:**

- Um `apt install sqlite3` no servidor rodou o `needrestart`, que reiniciou o nginx no meio da noite. Voltou em cerca de um segundo. O processo do Vapor não reiniciou, e o TSE e os pushes não passam pelo nginx.
- O primeiro `sqlite3 db.sqlite ".backup …"` falhou com "database is locked": o app grava eventos o tempo todo. Funcionou consultar direto, só para leitura, com espera (`sqlite3 -readonly -cmd ".timeout 5000" db.sqlite "…"`), usando o índice `idx_UsageMetric_dateTime` do `777de0f`.

**Na revisão da 13.1:** o primeiro build foi recusado porque o banner estava desligado para a revisão. Desde então, o servidor libera o banner por versão do app, com `previewVersions` (ver "Revisão da App Store"). Responder no Resolution Center não põe o app de volta na fila: é preciso reenviar o build, e só então pedir a revisão urgente.

## O que falta

### Versão 13

- [x] Build de revisão no TestFlight interno do app de prod, com replay `live` no `.com`: os pushes chegaram (27/09).
- [x] Aprovada pela revisão (28/09). `.com` de volta a `enabled: false` e `dryRun`.

### Versão 13.1 (tela de resultados)

- [x] Deploy do `472b4a7` (`details` e `officialResultsURL`), testes no aparelho, revisão e liberação em 03/10.
- [x] Eventos de analytics na tela de resultados: feitos para a versão seguinte à 13.2 (ver "Tela de resultados").

### Teste no simulado (28 e 29/09, 14h às 16h)

**28/09, o que aconteceu:**

- O TSE só publicou o primeiro arquivo novo às 14h39, e ele já veio com 50,01% apurado (não recomeçou do 0%).
- O servidor detectou a nova rodada sozinho (mesma eleição 21270, geração `173854587`) e mandou o primeiro push.
- A partir de 14h40, todos os arquivos falharam com `Key 'dvt' not found`: o TSE tirou o campo dos candidatos durante a contagem. O servidor ficou parado em 50,01% e não mandou mais nenhum push até o fim da janela. Corrigido em `185114b`.
- Não deu para medir a cadência dos arquivos, porque o servidor parou de lê-los.

**29/09, o que aconteceu:**

- Deploy do `185114b` feito. O primeiro arquivo novo foi o de 0% (geração `175528807`, gerado às 13h18), e o `dvt` não derrubou mais nada.
- Às 14h04, o APNs recusou os pushes do canal do beta com **429 `TooManyRequests`**. Duas causas nossas somadas:
  1. O arquivo de 0% vem sem `dt`/`ht`. O servidor usava a hora atual como horário, o estado mudava a cada tick e saía um push por intervalo sem dado novo. Se o `minPushIntervalSeconds` estava em 10 (valor sugerido num teste de 27/09; não confirmado), eram pushes a cada 10 s.
  2. Depois de uma falha, o servidor tentava de novo a cada 10 s, o que mantinha o canal bloqueado.
- Correções: `4e942d0` (espera de 60 s depois de falhar) e `eed02d0` (horário de geração quando falta o de totalização). Testado localmente contra o arquivo real: o horário ficou fixo em 13:18:27 e saiu um único push em 30 s.
- Depois do deploy do `4e942d0`, com `live` e `minPushIntervalSeconds` em 60: primeiro push às 14h23, sem erro, e a Live Activity iniciou no iPhone pelo beta.
- A cadência dos arquivos do TSE ainda não foi medida.

**Pendências de 29/09:** o horário de geração (`eed02d0`) funcionou no oficial, e o `minPushIntervalSeconds` do dia 4 ficou em 60. A espera progressiva depois de falhas no APNs (60 s, 2 min, 4 min, até ~10 min) ainda não foi feita.

### Em 05/10

- [ ] `.com`: `{"enabled":false,"broadcastMode":"dryRun"}`.
- [ ] Conferir o `.club`: em 04/10 ficou com `official`, `dryRun` e banner desligado.
- [ ] Push e deploy do `c68eff0` e consultar `GET api/v4/election-live-analytics/<senha de analytics>?since=2026-10-04T20:00:00Z` para ter a noite inteira.

### Até o 2º turno

- [ ] Enviar a versão seguinte à 13.2 com folga (uns 10 dias antes do dia 25), com `previewVersions` e liberação manual. Ela traz o evento de analytics na tela de resultados e a data do 2º turno na tela de novidades, e precisa do deploy da API que conta a origem `ElectionResults`.
- [x] Tirar o papel de parede do iOS 27 (`ElectionStoriesWallpaper`, 859 KB) do app: ele foi para a loja na 13.2 só por causa da ferramenta de vídeo do Dev Options. Agora a ferramenta pede o papel de parede na fototeca (versão seguinte à 13.3).
- [ ] Espera progressiva depois de falhas no APNs.
- [ ] Decidir o horário do "Atualizado às" para quem está fora do Brasil: hoje ele usa o fuso do aparelho (o arquivo das 18h09 apareceu como 22h09 em Lisboa), enquanto o TSE e o noticiário usam o horário de Brasília.

### No dia 25/10

- [ ] `{"round":2}` e, se o `ele-c.json` listar a eleição do 2º turno, o servidor resolve sozinho, apagando o estado do 1º como na troca de fonte. Conferir as fotos dos finalistas (o app tem 13, 14, 22, 30 e 70).
- [ ] Frases finais do 2º turno: só `elected:<número>`, `elected` e `default` fazem sentido. As de `runoff` não disparam mais.
- [ ] Seguir o checklist do 1º turno, com o ajuste de ligar o banner só quando a % passar de zero.

### Depois do 2º turno

- [ ] Trocar o `APNsBroadcastClient` pela biblioteca. O APNSwift 7.0.0 (jul/2026) já tem broadcast (envio e gestão de canais) e os campos de Live Activity do iOS 18, mas o vapor/apns 5.0.0 só aceita APNSwift abaixo da 7, e o SwiftPM não deixa ter duas versões do mesmo pacote. Então a migração é: tirar o vapor/apns (hoje na 3.0.0, com APNSwift 4.0.1), usar o APNSwift 7 direto (ou o vapor/apns, se já aceitar a 7) e reescrever todos os pushes: novo episódio, destaques da semana, sync de conteúdo em background e o envio manual.
- [ ] Desligar `enabled` nos dois servidores.

## Decisões em aberto

- Mostrar ou não candidatos anulados ("Anulado sub judice") na Live Activity. Hoje eles aparecem, como no app do TSE.
- Push-to-start (iniciar a activity remotamente) fica para depois: exige um token por aparelho.
- Ler as regras de divulgação da Resolução TSE 23.751, arts. 264 a 269.
- O alerta do resultado final acende a Tela Bloqueada de todo mundo que está acompanhando (sem som). Tirar é só remover o `alert` do `end` no `ElectionBroadcastPlanner`.
- Uma Live Activity dura no máximo 8h ativa. Quem iniciar às 17h passa da meia-noite; a apuração costuma terminar antes.
- Ideias ainda não feitas: reações da apuração (sons do podcast para a noite, pelo conteúdo da aba Reações), pushes normais nos momentos-chave ("virou a liderança", "vai ter 2º turno") e o widget da tela inicial.
- Banner dinâmico como plano B: ele já aceita botão `openLink`. Se a Live Activity falhar no dia, dá para publicar um banner "Acompanhe no app Resultados, do TSE" pelo servidor.

## Lições

- Se o estado depende do relógio, o servidor acha que sempre há novidade. O fallback para a hora atual no `updatedAt` virou um push por intervalo e, somado ao retry sem espera, um 429 do APNs. Qualquer campo do estado precisa vir do arquivo, não do momento em que ele é lido.
- Valores de teste esquecidos no servidor viram configuração de produção. Suspeita (não confirmada) de que o `minPushIntervalSeconds: 10` de um teste de 27/09 ficou no `.club` e multiplicou o problema de 29/09. Conferir `settings` no status antes de cada janela.
- Arquivo final não é amostra de arquivo intermediário. O parser era rígido com campos que só o arquivo final garante, e o teste de 28/09 parou dois minutos depois de começar. Qualquer campo que não identifique o candidato precisa ter valor padrão.
- Minhas renderizações no Mac não aplicam o Dynamic Type nem o limite de 160 pt, e não sabem o raio dos cantos da Island. O que parecia certo no Mac cortou no aparelho três vezes: porcentagens truncadas, frase final cortada e barra da Island. Para a Live Activity, medir a altura e simular os tamanhos de texto antes de dar por pronto, e conferir a Island no aparelho.
- Rodar o servidor num notebook que dorme engana: o `Task.sleep` pausa junto com o sistema e parece que o poller travou.
- A CDN do TSE às vezes derruba conexões keep-alive ociosas; o retry imediato no `get` cobre isso.
- `broadcastMode` começa em `dryRun`: se a activity não atualizar num teste, o primeiro suspeito é ter esquecido `"broadcastMode":"live"`.
- Uma variável de ambiente faltando derruba a API inteira (`fatalError` em `ReleaseConfigs`), não só a eleição. Conferir o `.env` antes de chamar rotas com senha.
- O `EnvironmentFile` do systemd não lê o `.env` como o Vapor: ele interpreta as barras invertidas e estragou a chave do APNs na migração do `.club` (08/10). O serviço não usa `EnvironmentFile`; o Vapor lê o `.env` sozinho.
- O site do TSE (e o DivulgaCandContas) bloqueia clientes que não sejam navegador: `curl` recebe 403.
- O primeiro arquivo do oficial não marca o começo da contagem: o arquivo de 0% sai na véspera. Ligar o banner cedo demais gasta as 8 horas da Live Activity e mostra "Atualização atrasada" depois de 15 minutos sem push. O sinal é a % passar de zero.
- Não instalar pacotes no servidor durante a apuração: o `needrestart` reinicia serviços sozinho, e reiniciou o nginx.
- Para consultar o SQLite de produção, só para leitura e com espera, e só consultas que usem o índice por data. Sem `.timeout`, o `sqlite3` desiste na primeira gravação do app.
- Número de build não separa versões: ele recomeça a cada versão e pode repetir o da loja. Para liberar algo só para a revisão, usar a versão (`previewVersions`).
- O "Atualizado às" mostra a hora do TSE, e o TSE fica vários minutos sem publicar no começo da noite. Antes de suspeitar do servidor, comparar a geração do status com o `idg` do arquivo do TSE.
