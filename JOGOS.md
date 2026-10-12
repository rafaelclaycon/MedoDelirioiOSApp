# Jogos

Ideias para os jogos da aba Você. A regra é começar simples e expandir: cada jogo novo deve reaproveitar o que já existe (motor de rodadas, cards, baralho, música de fundo) antes de pedir peças novas.

## O que já existe

- **De quem é essa fuça?** Uma foto, quatro nomes. As fotos vêm em cartas de baralho que viram a cada rodada, com uma música do app tocando no fundo (dá pra silenciar).
- **Eu já ouvi essa voz antes…** Um som, quatro autores.
- Partidas de 10 rodadas, pontuação = acertos, recorde salvo só no aparelho.
- Rodadas reserva substituem fotos que não carregam.
- Peças reaproveitáveis: `GameRoundFactory`, `GameSession`, `GameScoreStore`, `GameEntryCard`, `CardDeckView`, `GameMusicPlayer`, `GameSoundPlayer` (em `Sources/Core/Games` e `Sources/Views/You/Games`).

## Ideias escolhidas

### Qual é a música?

Toca uns 3 segundos de uma música do app; a pessoa escolhe o título entre quatro.

- **Dados:** as músicas do app (mesma fonte da música de fundo da fuça), respeitando o filtro de conteúdo explícito.
- **Reaproveita:** quase tudo do jogo de voz. A diferença é o trecho: começar num ponto aleatório (não na introdução) e parar depois de 3 segundos.
- **Cuidados:** músicas com títulos parecidos ou versões da mesma música não podem aparecer juntas como opções. Pular músicas curtas demais.
- **Por que primeiro:** é o mais barato e tem a cara do app, puro programa de auditório.

### Fuça pixelada

Uma evolução da fuça: a foto começa pixelada e vai ficando nítida; quanto antes a resposta, mais pontos.

- **Pontuação:** deixa de ser só acertos e passa a ser pontos por velocidade, o que espalha as notas (pré-requisito para rankings, ver SCH-437).
- **Reaproveita:** o baralho de cartas; a carta da frente ganha o efeito de pixelização (shader ou redução de resolução animada).
- **Cuidados:** decidir se vira um modo separado ou substitui a fuça atual. Mudar a pontuação quebra a comparação com recordes antigos.

### Voz em modo difícil

O jogo de voz com o som alterado: ao contrário, acelerado ou com a voz mais grave ou aguda.

- **Como liberar:** modo bônus depois de gabaritar o jogo de voz, ou um card próprio.
- **Técnica:** `AVAudioEngine` com `AVAudioUnitTimePitch` (velocidade e tom); ao contrário exige inverter o buffer antes de tocar.
- **Cuidados:** calibrar para continuar adivinhável. A graça é rir, não frustrar.

### Desafio do dia

Uma partida curta, a mesma para todo mundo naquele dia, com um resultado em emojis para compartilhar no WhatsApp (estilo Wordle).

- **Formato:** pode sortear o jogo do dia entre os existentes em vez de ser um jogo novo.
- **Mesma partida para todos:** semente derivada da data (o `GameRoundFactory` já aceita um gerador de números aleatórios). Precisa que o catálogo seja o mesmo para todo mundo, então talvez usar só conteúdo do pacote do app, ou uma lista de rodadas definida pelo servidor.
- **Compartilhamento:** texto com emojis (🟩🟥) e link para o app. O app já gira em torno de compartilhar no WhatsApp, então é o que mais pode trazer gente nova.
- **Cuidados:** uma partida por dia (guardar a data jogada); combinar com o ranking semanal do Game Center (SCH-437).

### Em que episódio foi?

Um trecho de transcrição ou o título de um capítulo; a pessoa escolhe o episódio (ou o ano).

- **Dados:** transcrições e capítulos já baixados pelo app.
- **Cuidados:** só funciona com episódios que têm transcrição ou capítulos. Escolher trechos marcantes, não frases genéricas. Opções erradas de episódios próximos no tempo deixam mais difícil; de anos diferentes, mais fácil.
- **Público:** fãs dedicados. Bom candidato a jogo "avançado".

## Ordem sugerida

1. **Qual é a música?** Pouco esforço, prova que o motor aguenta um terceiro jogo.
2. **Fuça pixelada** com pontos por velocidade. Prepara a pontuação para o Game Center.
3. **Desafio do dia** com compartilhamento.
4. **Voz em modo difícil.**
5. **Em que episódio foi?**

## Outras ideias (não escolhidas por enquanto)

- **Quem disse isso?** A frase escrita, adivinhar o autor. Jogável no mudo; precisa filtrar títulos que já trazem o nome da pessoa.
- **Complete a frase.** Bordão com uma palavra faltando.
- **Mais ou menos compartilhado?** Dois sons, qual a audiência compartilhou mais. Por sequência; depende dos dados de Tendências (internet).
- **Linha do tempo.** Ordenar sons pela data em que entraram no app.

## Relacionados

- SCH-437: integrar os jogos com o Game Center.
- SCH-395: gamificação ("top x%").
