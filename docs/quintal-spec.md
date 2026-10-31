# quintal: especificação de produto e arquitetura

v0.3, outubro 2026. documento vivo, revisto a cada decisão. a auditoria que originou esta versão está em [`quintal-auditoria.md`](./quintal-auditoria.md).

> "isso aqui é o meu lugar na internet, e essas são as pessoas que eu escolhi dividir ele comigo."

---

## 0. changelog

- **v0.3 (outubro 2026)** — reconciliação spec↔código a partir da auditoria:
  - **ingestão**: jetstream (relay filtrado) no lugar de subscribeRepos/cbor; genserver único no lugar de genstage.
  - **jobs**: task.supervisor no alpha; oban quando a carga pedir.
  - **http**: via proto_rune (finch transitivo); sem bypass (mox no adapter http); cache de identidade do proto_rune ligado, com ttl curto.
  - **deletes**: hard delete no índice; tombstones cortados.
  - **leitura pública**: canto, prosa e passear legíveis sem login; o anônimo passeia; escrita exige sessão.
  - **passear**: sorteia um canto, depois uma prosa dele.
  - **compromisso humano**: pledge fica, selo cortado.
  - **moderação**: block/report como processo manual no alpha.
  - **lexicons**: `lero` + áudio na prosa, `place.quintal.richtext.facet` e `avatar` no config formalizados.
  - **deploy**: imagem OCI (docker multi-stage) + módulo nix no padrão do pesque; fly segue uma saída.
  - hexes das paletas ratificados a partir do css; pesos de fonte corrigidos.
- **v0.2 (agosto 2026)** — versão auditada.

---

## 1. o que é

uma plataforma coletiva de blogs sobre atproto, inspirada na web antiga: blogs pessoais, escrita humana, comunidades pequenas, descoberta por acaso. sem otimização de engajamento, sem métricas de popularidade, sem anúncios.

o quintal não é uma rede social. é uma vizinhança. cada pessoa tem seu canto, escreve suas prosas, recebe recados e escolhe quem quer ler. público por padrão, seu por princípio.

lar como verbo, não como substantivo: um lugar que se mantém, se arruma, se compartilha e recebe visitas.

## 2. princípios

1. **cronológico para sempre.** não existe função de ranqueamento e nunca existirá. não é uma feature faltando, é a constituição.
2. **sem métricas de popularidade.** sem contadores de seguidores, sem likes, sem números públicos de nada. o feedback são recados, respostas e depoimentos.
3. **privacidade = dignidade, não sigilo.** público por padrão, honestamente. sem rastreamento, sem anúncios, sem colheita de atenção. seus dados no seu pds, suas chaves, sua saída livre. nunca prometer na interface o que o protocolo não entrega.
4. **escrita humana.** um compromisso (o pledge), não um detector. manifesto, não policiamento.
5. **simples e rápido acima de tudo.** performance é feature. a página de leitura é o produto.
6. **pt-br primeiro.** internacional por arquitetura (toda string externalizada via gettext), brasileiro por alma.

## 3. nome, domínios e mascote

- **nome**: quintal, sempre minúsculo, em qualquer contexto
- **domínio do produto**: quintal.blog.br (registro.br), registrado
- **domínio dos lexicons**: quintal.place (cloudflare), registrado. autoridade NSID: `place.quintal.*`
- **mascote**: axô, um axolote. aprovado. axolotes regeneram, e seus dados também: você pode levar tudo e replantar em qualquer lugar. o trocadilho axô/achou vira a mecânica de descoberta: "o axô achou isso pra você".

## 4. vocabulário

a linguagem do lugar é a arquitetura da informação. registro cotidiano, popular, de padaria.

| palavra    | significado                                                                                                                           |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| quintal    | a plataforma, a vizinhança inteira                                                                                                    |
| canto      | sua home pessoal: perfil, prosas, recados, cumadis, links                                                                             |
| prosa      | a unidade de escrita. vale nota de duas linhas e ensaio longo. tipos internos (metadado, não rótulo): nota, pergunta, crônica, ensaio, lero |
| lero       | a prosa falada: em vez de texto, um áudio gravado no navegador. sem texto no record, o áudio é o conteúdo |
| recado     | entrada no livro de visitas de um canto                                                                                               |
| depoimento | testemunho público sobre uma pessoa. aparece no canto dela só depois de aceito                                                        |
| cumadi     | um canto que você lê e recomenda publicamente; sua lista de cumadis, o "quem eu leio". no protocolo, o record `canto.blogroll`        |
| vizinhança | seu grafo de leitura, quem você segue                                                                                                 |
| passear    | a descoberta serendipita, protagonizada pelo axô                                                                                      |
| roda       | comunidades temáticas pequenas. v2, namespace reservado                                                                               |
| prosear    | o verbo de publicar                                                                                                                   |
| visitas    | a página de notificações quietas                                                                                                      |

## 5. escopo v1

### 5.1 features

1. **canto.** perfil, prosas, arquivo, links, recados, cumadis. blocos reordenáveis por arrastar e soltar, com opção de ocultar. tema por preset. "arquivo" é o índice paginado de prosas, sem tela própria: o bloco de prosas com "ver mais" faz as vezes.
2. **seguir e ler.** sem contadores. a vizinhança é sua e de mais ninguém: ninguém vê quantas pessoas te leem. o que é público por escolha é a lista de cumadis. cantos e prosas são legíveis sem login (ver 8.2.3).
3. **feed cronológico.** as prosas de quem você escolheu ler **mais as suas**, em ordem de publicação, paginação por cursor, sem fim infinito agressivo. o canto é seu, o feed também.
4. **respostas em duas marchas.** uma resposta é uma prosa com referência de reply: mesmo record, mesma estrutura. a nota rápida e a resposta ensaio diferem só na apresentação. uma resposta pode viver na thread e no seu canto ao mesmo tempo.
5. **livro de visitas.** qualquer pessoa **logada** pode deixar recado em qualquer canto, menos no próprio. o dono do canto pode ocultar. o record fica intacto no repo de quem escreveu: sua fala, seu repo; minha parede, minhas regras.
6. **cumadis e depoimentos.** descoberta como ato de amor público. depoimentos só aparecem no canto depois de aceitos pelo dono.
7. **compromisso humano.** um **pledge** visível no cadastro: escrita humana como compromisso, não como detecção. o selo no canto foi cortado (v0.3): o compromisso é o gesto de entrar, não uma medalha. sem detecção de ia, sem policiamento.
8. **exportação total.** nativa via atproto, mais um zip de um clique com markdown, imagens e json dos records.
9. **passear com o axô.** caminhada aleatória sobre o grafo indexado: sorteia um canto, depois uma prosa dele. pode ser feita **sem login**. na v1.5, o passeio é enviesado pelas arestas de depoimentos: serendipia seguindo cartas de amor.
10. **onboarding por convite.** alpha fechado. mecânica na seção 6.

### 5.2 cortado da v1 (deliberadamente)

- rodas e webrings: v2. precisam de desenho de curadoria, rings apodrecem sem steward.
- qualquer affordance de audiência privada: atproto é público por padrão, e a interface não promete o que o substrato não entrega.
- comentários como sistema separado: respostas são prosas, fim.
- ferramentas de governança coletiva: features coletivas agora, governança depois.
- pds hospedado: byo-pds na v1, pds gerenciado depois, no modelo da tangled.
- posts do bluesky no feed: o quintal é o quintal.
- css customizado: v2, talvez. porta de poder explícita, nunca padrão.
- digest por email: a página visitas resolve.
- **selo de compromisso no canto**: cortado na v0.3. o pledge fica no cadastro (feature 7); o selo era decoração de virtude.

## 6. público-semente e convites

a semente é a comunidade pessoal: amigos mais a rede profissional da comunidade elixir e beam. 30 a 50 pessoas convidadas à mão. o cold start vira um problema de hospitalidade, não de growth.

### 6.1 mecânica de convites

- todo convite é um **código único**: um código, uma entrada, um uso.
- cada pessoa convidada recebe **até 5 convites** para distribuir, e só depois de ter criado o próprio canto (verificado: sem `canto.config` gravado, a cota não é liberada).
- o admin pode gerar códigos avulsos a qualquer momento, e revogar códigos não usados (na v1, pelo console do release: `Quintal.Release.convites_gerar/1` e `revogar_convite/1`).
- sem expiração na v1. revogável pelo admin enquanto não usado.
- o convite é um artefato de marca: tela própria com o axô e o texto "o quintal é pequeno de propósito. você foi convidade."

### 6.2 modelo de dados dos convites

tabela `convites`: codigo (pk), criado_por (did ou "admin"), usado_por (did, nullable), criado_em, usado_em. contador derivado: convites restantes por pessoa (5 menos os usados, contados por criado_por).

## 7. identidade visual

### 7.1 tom geral

tudo minúsculo no chrome da interface: botões, títulos, nomes de coisas. "quintal" e "axô" nunca levam maiúscula. o nome de exibição do canto é conteúdo da pessoa, mas renderiza em minúsculo, como "nome de coisa". o texto dentro das prosas pertence ao autor, a interface não toca. a sensação desejada: uma casa arrumada com carinho, não um produto pedindo atenção.

### 7.2 temas: três presets

**papel** (default). um preset só, com duas luminosidades: **papel** de dia e **lamparina** de noite, com troca automática via `prefers-color-scheme`. sem toggle, sem configuração, sem manutenção de dois temas. mesma paleta, duas claridades.

os hexes abaixo são a fonte da verdade (v0.3): batem com `assets/css/tokens.css` e com `priv/static/manifest.webmanifest`. `sussurro` é decoração (bordas) e não promete contraste de texto; `meta` é o texto secundário, com AA garantido sobre o fundo.

| papel                   | papel (dia)            | lamparina (noite)            |
| ----------------------- | ---------------------- | ---------------------------- |
| fundo                   | `#faf6f1` papel quente | `#1d1923` aubergine profundo |
| tinta                   | `#2e2833`              | `#e8e2ee`                    |
| acento lilás            | `#7663ab`              | `#a493cc`                    |
| acento rosa             | `#c04075`              | `#e2a3bf`                    |
| meta (texto secundário) | `#6f6280`              | `#9d91b2`                    |
| sussurro (bordas)       | `#b5a9be`              | `#4a4156`                    |

**madrugada.** dark-first, pra quem vive de noite. não é a lamparina: é mais fundo, mais saturado, feito para ser o estado principal e não a versão noturna de outra coisa.

| papel        | madrugada |
| ------------ | --------- |
| fundo        | `#14101c` |
| tinta        | `#ece6f2` |
| acento lilás | `#b9a7e0` |
| acento rosa  | `#f0a8cc` |
| meta         | `#a89cc4` |
| sussurro     | `#5a4f6b` |

**gloss** (nome de trabalho). inspiração hyperpop: fofo, bem rosa, colorido, mas adaptado para conforto de leitura. a regra de design: a saturação mora no chrome (cabeçalho, bordas, links, detalhes), e a área de leitura fica calma, com contraste AA garantido. fofura sem dor de cabeça.

| papel            | gloss     |
| ---------------- | --------- |
| fundo            | `#fff5fa` |
| fundo de leitura | `#fffafd` |
| tinta            | `#3d2b3a` |
| acento rosa      | `#dc006b` |
| acento cyan      | `#1f7985` |
| meta             | `#8f5c7d` |
| sussurro         | `#e5c4d8` |

piso de contraste: WCAG AA em texto corrido, sempre, nos três presets. cada canto escolhe um preset e, opcionalmente, uma cor de acento própria dentro dele.

### 7.3 tipografia (fechado)

- **leitura (prosas)**: fraunces, eixo variável (100–900; títulos por volta de 600)
- **chrome (interface)**: atkinson hyperlegible, pesos 400 e 700, mais itálico 400
- dois fontes e só. diacríticos pt-br impecáveis. self-hosted em woff2, subconjuntos latin, `font-display: swap`.
- página de leitura: medida de 65 a 75 caracteres (`--medida-leitura: 68ch`, 65ch na página de prosa), line-height generoso, nada na tela além da prosa e do essencial.

### 7.4 o canto: arrastar e soltar

blocos fixos, reordenáveis e ocultáveis: **prosas, recados, quem eu leio**. sem layout livre. bio e links não são blocos: moram no cabeçalho, sempre visíveis. o nome do canto é de exibição, guardado local no appview (não entra no record): o handle continua sendo o endereço oficial. no desktop, arrastar e soltar; no mobile, long-press ou setas. a ordem escolhida vive no record `canto.config`, ou seja, a decoração também é portátil.

### 7.5 notificações quietas

sem badges vermelhos, sem contagens permanentes, sem push, sem email. uma página **visitas** com o resumo desde a última passada: "3 recados, 1 resposta, 2 vizinhos novos te lendo". o resumo zera a cada visita, com uma janela de carência curta (30 min) para eventos que chegam enquanto a página está aberta não sumirem no meio. notificações são um resgate de orkut no melhor sentido: alguém passou aqui.

leitura nunca é rastreada. a visita de leitura só existe quando o leitor a deixa, com um toque em "li até aqui" na página da prosa. sem marcação passiva, sem contagem de views: quem decide dizer "eu li" é quem leu.

### 7.6 o axô: escalação

aparece em: botão de descoberta ("passear com o axô"), estados vazios, loading (nadando), 404, tela de convite. **máximo uma vez por tela, nunca dentro do fluxo de leitura.** mascote que interrompe leitura vira anúncio.

### 7.7 tom de voz

frases curtas, fala de amiga, sem ponto de exclamação em excesso, sem gerundismo corporativo. microcopy de referência:

- feed vazio: "por aqui ainda tá quieto. que tal escrever a primeira prosa?"
- botões: prosear · deixar um recado · passear com o axô · seguir esse canto
- publicado: "pronto, sua prosa tá no quintal"
- 404: "o axô procurou, procurou... e não achou essa página"
- apagar: "apagar essa prosa? ela sai do seu pds também."
- convite: "o quintal é pequeno de propósito. você foi convidade."
- visitas vazias: "ninguém passou por aqui desde sua última visita. aproveita o silêncio."
- erro genérico: "ih, algo deu errado. tenta de novo?"

## 8. arquitetura

### 8.1 a forma

o quintal é um **appview atproto, não um host**. a pessoa autentica com sua identidade atproto existente (byo-pds: bsky.social, self-hosted, qualquer um). cada prosa, recado e configuração de canto é um record no repo dela, no pds dela. o quintal roda três coisas: um consumidor do **jetstream** (relay filtrado) que indexa nossos lexicons, uma camada de consulta (feed, cantos, descoberta) e uma interface web liveview que escreve de volta no repo da pessoa via oauth. custo marginal por usuário próximo de zero.

```
                 ┌─────────────┐
   jetstream --> │  ingestão   │ --> ┌────────────┐
   (relay wss,   │ (genserver) │     │  postgres  │
   place.quintal)│             │     │  (índice)  │
                 └─────────────┘     └─────┬──────┘
                                          │ ecto
   ┌───────────────┐  oauth + xrpc         │
   │ pds da pessoa │ ◄───────────────┐     ▼
   │ (bsky/self)   │                │ ┌───────────────┐
   └───────────────┘          ┌───────┤ phoenix + lv  │ --> navegador
                              │       └───────────────┘
                              └── leitura pública (sem login) e escrita (com sessão)
```

### 8.2 fluxos

1. **entrar.** oauth atproto com escopo restrito às coleções do quintal (nunca pedimos escrita no bluesky). depois do consentimento, um job de backfill indexa o histórico da pessoa. o record `canto.config` não é criado no login: nasce na primeira arrumação (boas-vindas ou modo arrumar), já com a cara escolhida.
2. **prosear.** `createRecord` no pds (rkey tid, prosa nova; `putRecord` só em edição e nos records singleton), e o eco do jetstream confirma no índice. a tela atualiza após o write confirmar e propaga por pubsub. **ingestão idempotente por design**: nossas próprias escritas chegam duas vezes (write e jetstream), então é upsert, nunca append.
3. **ler.** consulta direta no índice: prosas onde autor está na vizinhança mais as próprias, ordem cronológica, cursor. **sem login**: canto, prosa e passear respondem a quem não tem sessão; só as ações de escrita é que pedem sessão. sem ranqueamento em nenhuma camada.
4. **passear.** sorteia um canto do índice, sorteia uma prosa dele, serve com a carinha do axô. funciona para visitante anônimo.
5. **recado.** `createRecord` no repo de quem escreve, apontando o canto de destino. o dono do canto vê na página visitas e pode ocultar (flag local no índice). exige sessão (o record precisa de um repo).
6. **depoimento.** `createRecord` no repo de quem escreve. fica pendente até o aceite do dono do canto. na v1 o aceite é estado local do appview; na v2 pode virar record.
7. **convite.** código único validado no cadastro, marcado como usado, e a pessoa nova recebe sua cota de 5 (liberada após criar o canto).

### 8.3 stack

estilo da casa: deps mínimas, behaviours em vez de use, pattern matching em vez de libs de validação, nix, finch via proto_rune, mox.

| peça        | escolha                                           | nota                                                                                                                          |
| ----------- | ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| web         | phoenix + liveview, ssr                           | sem spa. gettext desde a linha 1 (v1: só o domínio `errors` externalizado; a microcopy do chrome nasce em pt-br e migra depois) |
| atproto     | proto_rune (dogfood)                              | requisitos detalhados na seção 9                                                                                              |
| ingestão    | jetstream (relay filtrado), genserver único, postgres | genstage/broadway só se a contra-pressão aparecer; no alpha não aparece                                                    |
| banco       | postgres, jsonb mais colunas extraídas            | sqlite considerado e rejeitado: escrita do jetstream concorrente com leitura web. backup: pg_dump agendado para object storage |
| jobs        | task.supervisor no alpha                          | backfill e eventos síncronos; oban quando a carga pedir (não antes)                                                            |
| http        | via proto_rune                                    | finch fica transitivo; o quintal não fala http direto                                                                          |
| testes      | mox na fronteira (adapter http + behaviours)      | `ProtoRune.HTTPClient.Adapter`, `Quintal.Auth`, `Quintal.PDS`; bypass com fixtures de pds se um dia valer a pena               |
| cache       | ets para resolução de identidade                  | o cache do proto_rune (`ProtoRune.Atproto.Identity.Cache`), ligado no supervision tree, com ttl curto                          |
| dev e infra | imagem OCI + módulo nix, um vps, fly              | dockerfile multi-stage gera a imagem; flake expõe `nixosModules.quintal` rodando a imagem pinada (padrão do pesque). fly continua uma saída |

### 8.4 o índice (postgres)

tabelas e colunas principais:

- **identidades**: did (pk), handle, pds_url, atualizado_em
- **prosas**: uri (pk), autor_did, cid, texto, tipo, reply_root, reply_parent, langs, audio_blob, audio_alt, created_at, indexed_at (áudio sustenta o lero)
- **prosa_imagens**: prosa_uri, posicao, blob (jsonb no formato do lexicon), alt
- **recados**: uri (pk), autor_did, subject_did, texto, oculto (bool), created_at
- **depoimentos**: uri (pk), autor_did, subject_did, texto, aceito (bool, null até decisão), created_at
- **blogrolls**: dono_did (pk), items (jsonb), updated_at
- **cantos**: dono_did (pk), tema, cor, blocos (array de texto), bio, links (jsonb), avatar (map), nome (de exibição, local do appview, fora do record), updated_at
- **follows**: seguidor_did, seguido_did, uri, created_at (pk composta; uri guardada para processar deletes)
- **convites**: codigo (pk), criado_por, usado_por, criado_em, usado_em
- **visitas_eventos**: id, dono_did, tipo (recado, resposta, novo_leitor, depoimento, leitura, mencao), ref_uri, autor_did, created_at. único por (tipo, ref_uri, autor_did): leituras são uma por pessoa por prosa
- **visitas_lido_em**: dono_did (pk), visto_em
- **firehose_cursor**: id, cursor
- **sessoes**: did (pk), blob cifrado (sessões oauth em repouso)

### 8.5 consistência

toda escrita é upsert idempotente por uri (singletons por dono_did). deletes chegam pelo jetstream e são **hard delete** no índice (v0.3): a linha sai. sem tombstones no alpha; a thread órfã degrada com graça (a prosa-mãe apagada vira "prosa não encontrada" e a resposta fica solta), e tombstones entram só se/quando valer guardar o buraco. eventos de identidade (handle trocado) atualizam a tabela de identidades e invalidam o cache de resolução.

## 9. proto_rune: o que precisa existir

checklist para auditar o que já existe e o que falta. é o coração do m0. **estado (v0.3): oauth, escrita, leitura, backfill e identidade estão completos; a ingestão usa jetstream no lugar do firehose cru.**

### 9.1 oauth atproto — implementado

o fluxo inteiro de login e autorização:

- client metadata: `client_id` como url apontando para o documento de metadados servido pelo quintal
- descoberta por conta: handle resolve para did, did document aponta o pds, o pds expõe o authorization server (protected resource metadata e authorization server metadata)
- par (pushed authorization request), pkce, e dpop com tratamento de nonce (retry em `use_dpop_nonce`)
- **escopo por coleção**: pedir apenas `repo:place.quintal.feed.prosa`, os quatro `repo:place.quintal.canto.<nome>` (config, blogroll, depoimento, recado) e `repo:place.quintal.graph.follow`. nunca escopo amplo, nunca coleções do bluesky. atenção: a spec de permissões do atproto não aceita wildcard parcial (`canto.*`), só `repo:*` ou coleção exata
- refresh de token transparente, revogação no logout, sessão indexada por did
- surface em elixir: um behaviour `Quintal.Auth` com a implementação proto_rune atrás, testável com mox

### 9.2 identidade

- `com.atproto.identity.resolveHandle` e resolução de did (plc.directory e did:web)
- cache em ets com ttl curto (o `ProtoRune.Atproto.Identity.Cache`, ligado no boot)
- invalidação dirigida pelo evento `identity` do jetstream: atualiza a tabela de identidades e derruba o cache do handle

### 9.3 leitura e backfill

- `com.atproto.repo.getRecord` e `listRecords` paginado: suficiente para o backfill da v1
- caminho robusto para depois: `com.atproto.sync.getRepo` com decode de CAR mais CBOR e caminhada na MST
- `com.atproto.repo.describeRepo` para descobrir coleções presentes

### 9.4 escrita

- `createRecord`, `putRecord`, `deleteRecord`
- `swapRecord` e `swapCommit` para concorrência otimista (edição segura do que o jetstream ainda não ecoou): o wrapper mapeia `swap_commit` no `putRecord` e `swap_record` no `deleteRecord`; estender quando a edição concorrente aparecer
- validação local do record contra o lexicon antes de escrever: falhar cedo, falhar em casa

### 9.5 ingestão

- **jetstream** (relay filtrado) por websocket: frames json, filtro por coleção `place.quintal.*` no próprio servidor
- alternativa documentada: `com.atproto.sync.subscribeRepos` cru com frames CBOR, se um dia precisarmos dos eventos completos do repo
- cursor persistido (tabela `firehose_cursor`), reconnect retomando do cursor
- eventos tratados: commit, identity (handle). deleção vira hard delete
- dedupe: a escrita e o eco do jetstream são o mesmo evento chegando duas vezes

### 9.6 blobs

- leitura de blob contra o pds de origem: usada na exportação (zip com as imagens) via a fronteira `Quintal.PDS`
- `com.atproto.sync.getBlob` disponível no proto_rune
- proxy no appview com cache em disco e headers de cache agressivos: **para depois**. no alpha a interface serve as imagens direto do pds do autor
- content-type preservado, limite de tamanho respeitado (2MB por imagem, 1MB por avatar, 20MB por áudio, vindos dos lexicons)

### 9.7 publicação de lexicons

- schemas servidos em `priv/static/lexicons/<nsid>.json`, via `Plug.Static`, acessíveis em `quintal.place/lexicons/...` (fly proxy termina TLS para ambos os domínios no mesmo app)
- versionamento no monorepo, tags `lexicons-v*`, com o changelog nas duas primeiras seções deste documento (seção 0 e aqui)
- resolução oficial (DNS TXT em `_lexicon.place.quintal` + record `com.atproto.lexicon.schema`) fica para quando houver interop externa; no dogfood o proto_rune carrega os schemas de disco

### 9.8 testes

- mox nas fronteiras: auth, pds, adapter http
- fixtures de pds com bypass: quando um pds falso em memória justificar o custo; no alpha, mox no adapter http cobre

## 10. lexicons

autoridade `place.quintal`, derivada de quintal.place. versionados e públicos desde o dia 1. estado (v0.3): os lexicons publicados são a fonte da verdade; os rascunhos abaixo batem com `priv/static/lexicons/`.

### 10.1 `place.quintal.feed.prosa`

```json
{
  "lexicon": 1,
  "id": "place.quintal.feed.prosa",
  "defs": {
    "main": {
      "type": "record",
      "key": "tid",
      "record": {
        "type": "object",
        "required": ["text", "createdAt"],
        "properties": {
          "text": { "type": "string", "maxGraphemes": 10000 },
          "facets": {
            "type": "array",
            "items": {
              "type": "union",
              "refs": [
                "app.bsky.richtext.facet",
                "place.quintal.richtext.facet"
              ]
            }
          },
          "tipo": {
            "type": "string",
            "knownValues": ["nota", "pergunta", "cronica", "ensaio", "lero"]
          },
          "reply": { "type": "ref", "ref": "#replyRef" },
          "images": {
            "type": "array",
            "maxLength": 4,
            "items": { "type": "ref", "ref": "#imagem" }
          },
          "audio": { "type": "ref", "ref": "#audio" },
          "langs": {
            "type": "array",
            "items": { "type": "string", "format": "language" }
          },
          "createdAt": { "type": "string", "format": "datetime" }
        }
      }
    },
    "replyRef": {
      "type": "object",
      "required": ["root", "parent"],
      "properties": {
        "root": { "type": "ref", "ref": "com.atproto.repo.strongRef" },
        "parent": { "type": "ref", "ref": "com.atproto.repo.strongRef" }
      }
    },
    "imagem": {
      "type": "object",
      "required": ["image", "alt"],
      "properties": {
        "image": {
          "type": "blob",
          "accept": ["image/jpeg", "image/png", "image/webp"],
          "maxSize": 2000000
        },
        "alt": { "type": "string", "maxGraphemes": 1000 }
      }
    },
    "audio": {
      "type": "object",
      "required": ["audio"],
      "properties": {
        "audio": {
          "type": "blob",
          "accept": ["audio/mpeg", "audio/mp4", "audio/ogg", "audio/webm", "audio/wav"],
          "maxSize": 20000000
        },
        "alt": { "type": "string", "maxGraphemes": 1000 }
      }
    }
  }
}
```

decisões codificadas no schema: alt obrigatório em toda imagem, máximo de 4 imagens, 10.000 grafemes de texto. o tipo `lero` traz um blob `audio` (até 20MB): a prosa falada, gravada no navegador, sem texto no record. facets são uma **union** dos facets do bluesky com `place.quintal.richtext.facet` (ênfase em markdown: negrito, itálico, riscado, código inline). o tipo `pergunta` não muda estrutura nem ordenação, só a ênfase visual na thread.

### 10.2 `place.quintal.canto.recado`

```json
{
  "lexicon": 1,
  "id": "place.quintal.canto.recado",
  "defs": {
    "main": {
      "type": "record",
      "key": "tid",
      "record": {
        "type": "object",
        "required": ["subject", "text", "createdAt"],
        "properties": {
          "subject": { "type": "string", "format": "did" },
          "text": { "type": "string", "maxGraphemes": 500 },
          "createdAt": { "type": "string", "format": "datetime" }
        }
      }
    }
  }
}
```

qualquer pessoa **logada** pode deixar recado em qualquer canto, menos no próprio. o record vive no repo de quem escreveu. o dono do canto pode ocultar, e o ocultar é estado do appview: sua fala fica intacta no seu pds, a parede é minha.

### 10.3 `place.quintal.canto.depoimento`

```json
{
  "lexicon": 1,
  "id": "place.quintal.canto.depoimento",
  "defs": {
    "main": {
      "type": "record",
      "key": "tid",
      "record": {
        "type": "object",
        "required": ["subject", "text", "createdAt"],
        "properties": {
          "subject": { "type": "string", "format": "did" },
          "text": { "type": "string", "maxGraphemes": 1000 },
          "createdAt": { "type": "string", "format": "datetime" }
        }
      }
    }
  }
}
```

só aparece no canto do subject depois de aceito. na v1 o aceite é estado local do appview (coluna `aceito` na tabela de depoimentos). na v2, avaliar virar record, para o aceite também ser portátil.

### 10.4 `place.quintal.canto.blogroll`

```json
{
  "lexicon": 1,
  "id": "place.quintal.canto.blogroll",
  "defs": {
    "main": {
      "type": "record",
      "key": "literal:self",
      "record": {
        "type": "object",
        "required": ["items", "updatedAt"],
        "properties": {
          "items": {
            "type": "array",
            "maxLength": 150,
            "items": {
              "type": "object",
              "required": ["did"],
              "properties": {
                "did": { "type": "string", "format": "did" },
                "note": { "type": "string", "maxGraphemes": 280 }
              }
            }
          },
          "updatedAt": { "type": "string", "format": "datetime" }
        }
      }
    }
  }
}
```

record único com `literal:self`: uma escrita, lista limitada a 150 cantos, simplicidade total. na interface, esse record aparece como "cumadis que recomendo" (spec 4).

### 10.5 `place.quintal.canto.config`

```json
{
  "lexicon": 1,
  "id": "place.quintal.canto.config",
  "defs": {
    "main": {
      "type": "record",
      "key": "literal:self",
      "record": {
        "type": "object",
        "required": ["tema", "blocos", "updatedAt"],
        "properties": {
          "tema": {
            "type": "string",
            "knownValues": ["papel", "madrugada", "gloss"]
          },
          "cor": { "type": "string", "maxLength": 7 },
          "blocos": {
            "type": "array",
            "items": {
              "type": "string",
              "knownValues": ["prosas", "recados", "quem-eu-leio"]
            }
          },
          "bio": { "type": "string", "maxGraphemes": 500 },
          "avatar": {
            "type": "blob",
            "accept": ["image/jpeg", "image/png", "image/webp"],
            "maxSize": 1000000
          },
          "links": {
            "type": "array",
            "maxLength": 8,
            "items": {
              "type": "object",
              "required": ["titulo", "url"],
              "properties": {
                "titulo": { "type": "string", "maxGraphemes": 60 },
                "url": { "type": "string", "format": "uri" }
              }
            }
          },
          "updatedAt": { "type": "string", "format": "datetime" }
        }
      }
    }
  }
}
```

`blocos` guarda a ordem do arrastar e soltar: bloco ausente está escondido. os únicos blocos são `prosas`, `recados` e `quem-eu-leio`: **bio e links não são blocos**, moram no cabeçalho (spec 7.4). `avatar` é o blob do retrato do canto (até 1MB). `tema` é o preset, e a dupla luminosidade do papel é resolvida na renderização, não no dado. `cor` é o acento opcional dentro do preset.

### 10.6 `place.quintal.graph.follow`

```json
{
  "lexicon": 1,
  "id": "place.quintal.graph.follow",
  "defs": {
    "main": {
      "type": "record",
      "key": "tid",
      "record": {
        "type": "object",
        "required": ["subject", "createdAt"],
        "properties": {
          "subject": { "type": "string", "format": "did" },
          "createdAt": { "type": "string", "format": "datetime" }
        }
      }
    }
  }
}
```

grafo próprio, separado do bluesky de propósito: ninguém quer seus follows de lá vazando para a lista de leitura daqui.

### 10.7 `place.quintal.richtext.facet`

```json
{
  "lexicon": 1,
  "id": "place.quintal.richtext.facet",
  "defs": {
    "main": {
      "type": "object",
      "required": ["index", "features"],
      "properties": {
        "index": { "type": "ref", "ref": "#byteSlice" },
        "features": {
          "type": "array",
          "items": {
            "type": "union",
            "refs": ["#bold", "#italic", "#strike", "#code"]
          }
        }
      }
    },
    "byteSlice": {
      "type": "object",
      "required": ["byteStart", "byteEnd"],
      "properties": {
        "byteStart": { "type": "integer", "minimum": 0 },
        "byteEnd": { "type": "integer", "minimum": 0 }
      }
    },
    "bold": { "type": "object", "required": [], "properties": {} },
    "italic": { "type": "object", "required": [], "properties": {} },
    "strike": { "type": "object", "required": [], "properties": {} },
    "code": { "type": "object", "required": [], "properties": {} }
  }
}
```

facet próprio para a ênfase do markdown (negrito, itálico, riscado, código inline): o markdown da prosa é convertido em facets no momento da escrita, então a formatação viaja no record e não depende de o leitor adivinhar a fonte. entra na union de facets de `place.quintal.feed.prosa` (10.1).

### 10.8 reservado

`place.quintal.roda.*` para a v2. namespace segurado, nada mais por agora.

## 11. moderação (o chão, mesmo em alpha fechado)

- dono do canto oculta recados no próprio espaço; o record segue intacto no pds do autor
- depoimentos exigem aceite, o que já é uma camada de moderação embutida
- **block e report: processo manual no alpha.** a conduta descreve o caminho (recado ou email para a administradora); uma fila de admin de software entra quando houver escala, não antes. 30 a 50 convidados não justificam ferramenta
- convites são códigos únicos, revogáveis pelo admin enquanto não usados
- conteúdo em pds da bsky herda a moderação de blobs deles, o que cobre o chão do assustador e ilegal no alpha
- labeler próprio: conversa de v2

## 12. marcos

| marco | conteúdo                                                                                        | sai do forno quando                 | estado (v0.3) |
| ----- | ----------------------------------------------------------------------------------------------- | ----------------------------------- | ------------- |
| m0    | lexicons publicados e resolvíveis; proto_rune com oauth, escrita, backfill e ingestão            | caminho crítico, a incógnita real   | feito (ingestão por jetstream) |
| m1    | criar canto, escrever e ler as próprias prosas, sem feed                                         | já dá para usar como diário público | feito         |
| m2    | follows, ingestão, feed cronológico                                                              | a vizinhança fica legível           | feito         |
| m3    | recados, cumadis, depoimentos com aceite, três presets de tema                                   | a vizinhança fica decorada          | feito         |
| m4    | axô e o passear, convites com cota de 5, polish                                                  | alpha com cerca de 30 amigos        | feito (falta o loading nadando e a leitura pública) |

## 13. custos

um vps de 10 a 15 euros por mês, object storage em trocos, domínios já pagos. total: menos que dois cafés por mês. a imagem OCI roda igual em docker compose, no fly ou sob o módulo nix do flake (padrão do pesque). modelo de dinheiro fica para depois, com a restrição de arquitetura "custo marginal por usuário próximo de zero" já embutida desde o início.

## 14. decisões fechadas

- lexicon próprio: a linguagem do lugar vira protocolo
- byo-pds na v1; pds gerenciado depois, no modelo da tangled
- imagens: máximo de 4 por prosa, alt obrigatório; proxy com cache no appview fica para depois da leitura pública
- sem posts do bluesky no feed
- grafo de follow próprio
- pt-br only no dia 1, gettext-ready (v1: só o domínio `errors`)
- público por padrão; privacidade é dignidade, não sigilo
- **leitura pública**: canto, prosa e passear sem login; escrita exige sessão (record vive no repo da pessoa)
- features coletivas agora, governança depois
- oss primeiro, dinheiro depois
- semente: comunidade pessoal, 30 a 50 convidados
- domínios registrados: quintal.blog.br e quintal.place
- fontes: fraunces para leitura, atkinson hyperlegible para a interface
- depoimentos só aparecem após aceite
- recados abertos a qualquer pessoa logada; recusa o próprio canto
- prosa com limite de 10.000 grafemes
- tipo pergunta: apenas ênfase visual, sem mudança estrutural
- lero: prosa falada com áudio no record; facet próprio para ênfase de markdown
- três presets: papel (default, com lamparina automática à noite), madrugada (dark-first), gloss (hyperpop adaptado para leitura)
- css customizado: v2, talvez
- notificações: só a página visitas, sem email
- mascote axô aprovado
- convites: códigos únicos, cada convidado pode convidar até 5 pessoas (após criar o canto)
- **ingestão por jetstream**, não firehose cru; deletes são hard delete, sem tombstones
- **jobs no task.supervisor** no alpha; oban quando a carga pedir
- **infra**: imagem OCI + módulo nix (padrão do pesque); fly segue uma saída
- **compromisso humano**: pledge no cadastro; selo cortado

## 15. questões abertas

1. nome final do preset hyperpop. gloss é nome de trabalho.
2. ~~auditoria do proto_rune~~ resolvida: ver [`quintal-auditoria.md`](./quintal-auditoria.md). falta a leitura pública e o loading nadando.
3. design visual do axô e mockup dos cantos. briefing em `quintal-mockup-briefing.md`. faltam logo e social card.
4. anti-spam de recados: limite por dia por pessoa? aberto, mas provavelmente desnecessário em alpha fechado.
5. aceite de depoimento vira record na v2? afeta portabilidade do aceite.
6. ux do visitante anônimo: o que o anônimo vê no lugar dos botões de escrita (esconder vs "entre para responder")?
