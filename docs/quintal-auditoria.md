# auditoria: quintal spec v0.2 vs implementação

documento derivado. confronta cada promessa da `quintal-spec.md` com o código em `lib/`, `priv/`, `assets/` e com a dep `proto_rune`. read-only: nada foi alterado na spec nem no código.

status usados:

- **implementado** — existe e bate com a promessa.
- **parcial** — existe, mas falta parte do prometido.
- **diferente** — implementado, mas desvia do que a spec descreve.
- **ausente** — prometido e não encontrado.
- **n/a** — fora do alcance do appview, ou deliberadamente futuro.

---

## resumo executivo

o quintal está **muito mais perto da spec do que longe dela**. features de v1, arquitetura, identidade visual, convites e moderação estão quase todos de pé. o que destoa se concentra em quatro frentes:

1. **dívida de infraestrutura declarada como feita.** quatro peças de §8.3 não existem: oban, genstage, cache ets de identidade e bypass. a função é cumprida por substitutos (task.supervisor, um genserver, query direta no banco, mox no adapter http). funciona, mas a spec descreve outra coisa.
2. **substrato da ingestão trocado sem registro.** a spec pede `com.atproto.sync.subscribeRepos` (firehose cru, cbor). o código consome `ProtoRune.Jetstream` (json, filtrado no servidor). é uma decisão boa, mas a spec e o marco m0 ainda dizem outra coisa. junto com isso, **deletes são hard delete**, não tombstones (§8.5).
3. **o protocolo andou à frente da spec.** os lexicons publicados têm campos e tipos que a spec não registra: áudio (`lero`) na prosa, o lexicon `place.quintal.richtext.facet`, `avatar` no `canto.config`. a própria spec se contradiz (§4 lista `lero`, §10.1 não).
4. **duas features de v1 ausentes por inteiro.** o **compromisso humano** (pledge + selo, §5.1.7) não existe em nenhuma forma, e a **fila de block/report** (§11) é processo manual, não software.

também apareceu, de brinde, **um bug real** no onboarding (ver §5) e uma **docstring que afirma algo falso** sobre o bootstrap criar `canto.config`.

---

## 1. prometido e não existe

| # | promessa | seção | onde deveria estar | nota |
| - | -------- | ----- | ------------------ | ---- |
| 1 | compromisso humano: pledge no cadastro | §5.1.7 | `lib/quintal_web/live/cadastro_live.ex` | nenhuma menção a pledge/manifesto na página de cadastro |
| 2 | compromisso humano: selo no canto | §5.1.7 | render do canto, `canto_live.ex` | nenhum selo/badge/marca em lugar nenhum |
| 3 | block + report em fila de admin | §11 | — | `conduta_live.ex:85-104` só descreve processo manual (recado/email); sem fila, sem botão, sem ação |
| 4 | exportação: **imagens** no zip | §5.1.8 | `lib/quintal/exportar.ex:66` | imagens saem só como referência de blob no json; a docstring admite a lacuna (`exportar.ex:11-13`) |
| 5 | axô nadando no loading | §7.6 | — | `axo-swimming.png` existe em `priv/static/images/` mas não é referenciado; o loading é só a barra lilás do topbar (`app.js:878-883`) |
| 6 | revogar convite pelo admin | §6.1, §11 | — | `Convites.revogar/1` existe, atômica e testada, mas sem ui, rota ou mix task: só console |
| 7 | convidado só convida **após criar o próprio canto** | §6.1 | `lib/quintal/convites.ex:45-51` | só checa cota; qualquer pessoa logada gera os 5 convites sem nunca ter tocado no canto |
| 8 | oban para jobs | §8.3 | `mix.exs` | ausente; backfill roda em `Task.Supervisor` (`bootstrap.ex:14-17`), que já reconhece o débito |
| 9 | genstage na ingestão | §8.3 | `application.ex` | ausente; ingestão é um `GenServer` único (`ingestao.ex:30`) |
| 10 | cache ets para resolução de identidade | §8.3, §9.2, §8.5 | `lib/quintal/identidade.ex:42-47` | sem `:ets` no código; `Identidade.buscar/1` lê o banco direto. o cache do proto_rune existe mas não é iniciado (ver §4) |
| 11 | bypass com fixtures de pds | §8.3 | `mix.exs` | ausente; a estratégia real é mox no adapter http (`ProtoRune.HTTPClient.Adapter`) e nos behaviours |
| 12 | finch como cliente próprio | §8.3 | `mix.exs`, `lib/` | só transitivo, via proto_rune/req; nenhuma dep direta, nenhum uso direto |
| 13 | deletes viram tombstones | §8.5 | `lib/quintal/ingestao.ex:138-153` | é **hard delete** (`Repo.delete_all`); o módulo admite adiar os tombstones (`ingestao.ex:14-17`) |
| 14 | proxy de blobs com cache em disco + headers | §9.6, §14 | `lib/quintal_web/formatacao.ex:90-128` | sem proxy: o navegador busca `getBlob` direto no pds do autor; marcado como "ponytail, adiado" |
| 15 | changelog dos lexicons no spec | §9.7 | `docs/quintal-spec.md` | existe a tag `lexicons-v0.1.0`, mas o spec não tem seção de changelog |
| 16 | nix flake | §8.3 | — | sem `flake.nix` |
| 17 | caddy | §8.3 | — | sem `Caddyfile`; tls é terminado pelo proxy do fly |
| 18 | toda string externalizada via gettext | §2.6, §14 | `*.heex` | só o domínio `errors` está externalizado; a microcopy do chrome é hardcoded (grep `gettext` em heex = 0) |

---

## 2. existe, mas ficou diferente

| # | promessa | seção | realidade | nota |
| - | -------- | ----- | --------- | ---- |
| 1 | firehose cru `subscribeRepos` + cbor + genstage | §8.1, §8.3, §9.5 | `ProtoRune.Jetstream` (json, filtrado no servidor) + genserver único | `ingestao.ex:5,49,79`. proto_rune oferece os dois; é escolha de consumo. §8.1 fala "relay wss", que o jetstream satisfaz |
| 2 | feed "só prosas de quem você escolheu ler" | §5.1.3 | inclui as **próprias** prosas | `feed.ex:31`. o moduledoc trata como decisão ("o canto é seu, o feed também") |
| 3 | canto público por padrão | §2.3, §5.1.2 | `CantoLive`/`ProsaLive`/`PassearLive` atrás da portaria (401 sem sessão) | `router.ex:48-62`, `portaria_plug.ex:18-31`. não existe url pública de canto. coerente com o alpha fechado, mas não com "público por padrão" |
| 4 | passear: sorteia repo ativo, depois prosa | §8.2.4 | um único `ORDER BY RANDOM()` sobre prosas | `passear.ex:31-40`. enviesa para quem escreve mais; não há noção de "repo ativo" nem assimetria repo→prosa |
| 5 | "qualquer pessoa" deixa recado | §5.1.5, §10.2 | exige login e recusa o próprio canto | `recados.ex:161-162` (`:recado_proprio_canto`), portaria na rota |
| 6 | interface otimista no prosear | §8.2.2 | prepend só **depois** do write retornar | `home_live.ex:85-90`. o eco via pubsub (`home_live.ex:128-148`) mitiga, mas não é o otimismo descrito |
| 7 | resumo de visitas "zera a cada visita" | §7.5 | janela de carência de 30 min | `visitas.ex:32-33,133-139`: eventos recentes sobrevivem à releitura |
| 8 | createRecord/putRecord conforme nomeado | §8.2.2 | prosear usa `create_record` (rkey tid); `put_record` só em edição/config/blogroll | `prosas.ex:116` vs `:142`. provável imprecisão da spec, não falha |
| 9 | seed de convite: "você foi convidada" | §6.1, §7.7 | "você foi **convidade**" | `convite_live.ex:25`. troca para linguagem neutra, provavelmente intencional |
| 10 | `cantos.blocos` como jsonb | §8.4 | array nativo `text[]` | `20260818010000_canto_blocos_native_array.exs:7` |
| 11 | `prosa_imagens.blob_ref` | §8.4 | coluna `blob` (jsonb, formato lexicon) | `20260819120000_create_prosa_imagens.exs:8-11` |
| 12 | pesos 400/600 + itálico | §7.3 | atkinson carrega 400 e **700**; fraunces é variável 100-900 | `tokens.css:105,121,129` |
| 13 | hexes papel e gloss | §7.2 | acentos trocados: papel `#7663ab`/`#c04075`; gloss `#dc006b`/`#1f7985` | `tokens.css:11-12,93-94`. o spec autoriza afinar, **mas** os swatches da ui (`canto_live.ex:51-55`, `boas_vindas_live.ex:21-25`) e o `manifest.webmanifest:9` ainda mostram os hexes antigos: o seletor promete cor que o css não aplica |
| 14 | nome do canto como conteúdo da pessoa | §7.1 | `.canto__nome` é `<h1>` e o reset força lowercase | `base.css:97` + `canto_live.ex:486`. o nome escolhido pela pessoa é rebaixado a minúsculas |

---

## 3. divergências de contrato (lexicons)

os lexicons publicados andaram à frente do rascunho §10.

**`place.quintal.feed.prosa`** (diferente):
- `tipo.knownValues` ganhou `"lero"` (spec: `nota, pergunta, cronica, ensaio`).
- `facets.items` virou **union**: `[app.bsky.richtext.facet, place.quintal.richtext.facet]` (spec: ref única para o facet do bluesky).
- `defs` ganhou `#audio` (blob `audio/*`, `maxSize 20000000`, `alt` opcional) e a property `audio`. **nada disso está na spec**; o escopo oauth já pede `blob:audio/*` (`config.exs:38`).

**`place.quintal.canto.config`** (diferente):
- `blocos.knownValues` perdeu `bio` e `links`: só `prosas, recados, quem-eu-leio`. isso **alinha com §7.4** ("bio e links moram no cabeçalho") e **diverge de §10.5**, que ainda os lista. a spec se contradiz.
- ganhou `avatar` (blob `image/*`, `maxSize 1000000`), não previsto em §7.4 nem §10.5.

**`place.quintal.richtext.facet`** (lexicon novo, ausente da spec):
- define `main` (`index`, `features`) + `byteSlice` + features `bold/italic/strike/code`. consumido por `lib/quintal/rich_text.ex`. faz parte do contrato público (aparece na union) e não tem registro de versão.

**iguais à spec**: `canto.recado`, `canto.depoimento`, `canto.blogroll`, `graph.follow` — campo a campo, idênticos.

**`roda.*`**: reservado, ausente como previsto.

---

## 4. bugs e inconsistências encontrados

1. **onboarding quebra com dados.** `boas_vindas_live.ex:46` faz `with true <- attrs == %{}`. se a pessoa digita nome ou bio, o `with` cai no `else`, que só cobre `{:error, _}`, levantando `WithClauseError`. só funciona com "pular" (attrs vazio). parece condição invertida.
2. **cache de identidade do proto_rune ocioso.** `ProtoRune.Atproto.Identity.Cache` existe, mas **não está no supervision tree** (`application.ex:12-19`), então todo lookup é miss. ttl default é 1h/1d, o oposto do "ttl curto" pedido em §9.2.
3. **invalidação de identidade incompleta.** a ingestão trata só eventos `:identity`, e só quando há handle, fazendo `update_all` no postgres (`ingestao.ex:123-134`). não há branch para `:handle` (a spec §9.2 pede os dois) nem invalidação de cache (não existe cache). desativação de conta também não é tratada.
4. **docstring falsa sobre convites.** `convites.ex:3-8` justifica a garantia "só após criar o canto" dizendo que o bootstrap cria o `canto.config` antes — mas o bootstrap **só lê**, nunca escreve (`bootstrap.ex:8-11,85-90`).
5. **delete de `canto.config` ignorado.** `ingestao.ex:147-148` descarta deletes do config sem tombstone nem limpeza.
6. **swapRecord/swapCommit incompletos.** `Quintal.PDS.ProtoRune` mapeia `:swap_commit` só no `put_record` e `:swap_record` só no `delete_record` (`pds/proto_rune.ex:73-76,87-90`), inverso do que "edição segura" sugere (§9.4). nenhum caller em produção usa as opções; só teste.
7. **contador de grafemes mede code points.** `app.js:279` usa `[...value].length`; o lexicon fala `maxGraphemes:10000` (`prosa.json:12`). emojis/combining marks divergem do limite real.
8. **`--acento-2` não acompanha o acento do canto.** só `--acento` é sobrescrito (`root.html.heex:5`, `tema_plug.ex:30`); hovers e a pílula de publicar seguem o acento do preset. provavelmente efeito colateral.

---

## 5. stack prometido vs real (§8.3)

| peça | spec | real | veredito |
| ---- | ---- | ---- | -------- |
| web | phoenix + liveview ssr, sem spa, gettext | phoenix 1.8 + lv 1.2, bandit, esbuild; gettext **só no domínio errors** | parcial |
| atproto | proto_rune | proto_rune 0.7.0 (dep `~> 0.5`) | implementado |
| ingestão | websocket, genstage, postgres | jetstream (genserver único), postgres | diferente |
| banco | postgres, jsonb + colunas extraídas | idem; `blocos` virou `text[]` | implementado |
| jobs | oban | task.supervisor | ausente |
| http | finch | finch transitivo (via proto_rune) | parcial |
| testes | mox na fronteira xrpc, bypass | mox no adapter http + behaviours; sem bypass | parcial |
| cache | ets para identidade | query direta no banco | ausente |
| dev/infra | nix flake, vps, caddy | fly (gru), sem flake, sem caddy | parcial |

---

## 6. §8.4 o índice (postgres)

tabelas da spec **todas presentes**, com o modelo divergindo em pontos pequenos:

- `prosa_imagens.blob_ref` → coluna `blob` (jsonb).
- `cantos.blocos` jsonb → `text[]`.
- **extras** não previstos: tabela `sessoes` (sessões oauth cifradas), `cantos.avatar` (map), `prosas.audio_blob`/`audio_alt`, e `visitas_eventos.tipo` aceitando `mencao`.
- `identidades`, `recados`, `depoimentos`, `blogrolls`, `follows`, `convites`, `visitas_eventos`, `visitas_lido_em`, `firehose_cursor`: fiéis, inclusive a unicidade `(tipo, ref_uri, autor_did)`.

---

## 7. decisões fechadas (§14) que não se sustentam

- **"imagens: proxy com cache no appview"** — não existe proxy (§9.6).
- **"toda string externalizada via gettext"** (§2.6/§14) — só `errors`.
- **"byo-pds na v1"** — implementado e limpo; base sólida para a discussão de host (ver §10).

as outras decisões fechadas se sustentam no código. destaques positivos: escopo oauth restrito às coleções `place.quintal.*` (`config.exs:36-38`), nenhum post do bluesky no feed, grafo de follow próprio, depoimentos só após aceite, recados abertos a qualquer sessão.

---

## 8. marcos (§12)

| marco | veredito | motivo |
| ----- | -------- | ------ |
| **m0** | parcial | oauth, escrita, backfill e lexicons de pé; ingestão é jetstream (não subscribeRepos/cbor); sem tombstones; `getRepo`+car/mst e `describeRepo` não usados (coerente com "depois") |
| **m1** | implementado | canto, escrever, ler as próprias prosas |
| **m2** | implementado | follows, ingestão, feed por cursor sem ranking |
| **m3** | implementado | recados, cumadis, depoimentos com aceite, três presets |
| **m4** | implementado | axô, passear, convites cota 5, polish; falta o loading com axô nadando |

---

## 9. questões abertas (§15): estado

1. **nome do preset hyperpop ("gloss")** — aberta; o código já congelou "gloss" no lexicon e na ui.
2. **auditoria do proto_rune (§9)** — resolvida por esta auditoria: oauth/escrita/leitura/backfill existem; ingestão via jetstream; sem car/mst/describerep repo; sem tombstones. **§9.1 (oauth) está 100% implementado**, incluindo par, pkce, dpop com nonce, escopo por coleção, refresh, revogação e sessão por did.
3. **design visual do axô e mockup** — parcial: 10 pngs de axô + briefing no repo; faltam logo, social card e a pose nadando em uso.
4. **anti-spam de recados** — aberta; sem limite por pessoa/dia (provavelmente ok no alpha).
5. **aceite de depoimento vira record na v2** — aberta; ainda coluna local `aceito`.

---

## 10. nota: hospedagem de pds (§5.2) e a auditoria

a spec corta "pds hospedado" da v1 (§5.2) e a decisão "byo-pds na v1" (§14) está limpa no código: `Quintal.PDS` sempre usa o `service_url` da sessão, nunca um pds próprio. **não há nenhuma fronteira de "host" no código** — nem provisionamento de conta, nem custódia de chave, nem noção de identidade criada pelo quintal.

ou seja: se a ideia de "abrir o quintal pra criar contas" sair do papel, é trabalho greenfield, não extensão de algo existente. o inventário de custo está em `quintal-spec.md` §5.2 ("modelo da tangled") e não foi tocado por nenhuma linha aqui.

o achado relevante pra essa decisão: o oauth do quintal (§9.1) está **integralmente implementado**, incluindo o escopo restrito. um pds próprio (`pds.zeetech.io`) eliminaria a dança oauth de terceiros para quem estiver nele — o que reduz bastante o custo de "usuário + senha" (`createSession` direto), mas continua sendo a fatia menor do problema de virar host.

---

## metodologia

cinco auditorias paralelas, read-only, cada uma com escopo fechado:

1. §5.1 features 1–5 e §8.2 fluxos 1–4
2. §5.1 features 6–10, §5.2, §6 convites, §11 moderação
3. §8.3 stack, §8.4 modelo, §8.5 consistência
4. §9 proto_rune e §10 lexicons
5. §7 identidade visual, §3, §12 marcos, §13, §14, §15

toda afirmação carrega evidência `arquivo:linha`. itens marcados "diferente" foram revisados contra o texto exato da spec; onde a spec é internamente contraditória (§4 vs §10.1; §7.4 vs §10.5), o achado aponta as duas.
