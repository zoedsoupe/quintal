# quintal: especificação de produto e arquitetura

v0.2, agosto 2026. documento vivo, revisto a cada decisão.

> "isso aqui é o meu lugar na internet, e essas são as pessoas que eu escolhi dividir ele comigo."

---

## 1. o que é

uma plataforma coletiva de blogs sobre atproto, inspirada na web antiga: blogs pessoais, escrita humana, comunidades pequenas, descoberta por acaso. sem otimização de engajamento, sem métricas de popularidade, sem anúncios.

o quintal não é uma rede social. é uma vizinhança. cada pessoa tem seu canto, escreve suas prosas, recebe recados e escolhe quem quer ler. público por padrão, seu por princípio.

lar como verbo, não como substantivo: um lugar que se mantém, se arruma, se compartilha e recebe visitas.

## 2. princípios

1. **cronológico para sempre.** não existe função de ranqueamento e nunca existirá. não é uma feature faltando, é a constituição.
2. **sem métricas de popularidade.** sem contadores de seguidores, sem likes, sem números públicos de nada. o feedback são recados, respostas e depoimentos.
3. **privacidade = dignidade, não sigilo.** público por padrão, honestamente. sem rastreamento, sem anúncios, sem colheita de atenção. seus dados no seu pds, suas chaves, sua saída livre. nunca prometer na interface o que o protocolo não entrega.
4. **escrita humana.** um compromisso (pledge + selo), não um detector. manifesto, não policiamento.
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
| prosa      | a unidade de escrita. vale nota de duas linhas e ensaio longo. tipos internos (metadado, não rótulo): nota, pergunta, crônica, ensaio |
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

1. **canto.** perfil, prosas, arquivo, links, recados, cumadis. blocos reordenáveis por arrastar e soltar, com opção de ocultar. tema por preset.
2. **seguir e ler.** sem contadores. a vizinhança é sua e de mais ninguém: ninguém vê quantas pessoas te leem. o que é público por escolha é a lista de cumadis.
3. **feed cronológico.** só prosas de quem você escolheu ler, em ordem de publicação, paginação por cursor, sem fim infinito agressivo.
4. **respostas em duas marchas.** uma resposta é uma prosa com referência de reply: mesmo record, mesma estrutura. a nota rápida e a resposta ensaio diferem só na apresentação. uma resposta pode viver na thread e no seu canto ao mesmo tempo.
5. **livro de visitas.** qualquer pessoa pode deixar recado em qualquer canto. o dono do canto pode ocultar. o record fica intacto no repo de quem escreveu: sua fala, seu repo; minha parede, minhas regras.
6. **cumadis e depoimentos.** descoberta como ato de amor público. depoimentos só aparecem no canto depois de aceitos pelo dono.
7. **compromisso humano.** pledge visível no cadastro e selo no canto. sem detecção de ia, sem policiamento: é um manifesto.
8. **exportação total.** nativa via atproto, mais um zip de um clique com markdown, imagens e json dos records.
9. **passear com o axô.** caminhada aleatória sobre o grafo indexado. na v1.5, o passeio é enviesado pelas arestas de depoimentos: serendipia seguindo cartas de amor.
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

## 6. público-semente e convites

a semente é a comunidade pessoal: amigos mais a rede profissional da comunidade elixir e beam. 30 a 50 pessoas convidadas à mão. o cold start vira um problema de hospitalidade, não de growth.

### 6.1 mecânica de convites

- todo convite é um **código único**: um código, uma entrada, um uso.
- cada pessoa convidada recebe **até 5 convites** para distribuir, e só depois de ter criado o próprio canto.
- o admin pode gerar códigos avulsos a qualquer momento.
- sem expiração na v1. revogável pelo admin enquanto não usado.
- o convite é um artefato de marca: tela própria com o axô e o texto "o quintal é pequeno de propósito. você foi convidada."

### 6.2 modelo de dados dos convites

tabela `convites`: codigo (pk), criado_por (did ou "admin"), usado_por (did, nullable), criado_em, usado_em. contador derivado: convites restantes por pessoa (5 menos os usados, contados por criado_por).

## 7. identidade visual

### 7.1 tom geral

tudo minúsculo no chrome da interface: botões, títulos, nomes de coisas. "quintal" e "axô" nunca levam maiúscula. o texto dentro das prosas pertence ao autor, a interface não toca. a sensação desejada: uma casa arrumada com carinho, não um produto pedindo atenção.

### 7.2 temas: três presets

**papel** (default). um preset só, com duas luminosidades: **papel** de dia e **lamparina** de noite, com troca automática via `prefers-color-scheme`. sem toggle, sem configuração, sem manutenção de dois temas. mesma paleta, duas claridades.

| papel                   | papel (dia)            | lamparina (noite)            |
| ----------------------- | ---------------------- | ---------------------------- |
| fundo                   | `#faf6f1` papel quente | `#1d1923` aubergine profundo |
| tinta                   | `#2e2833`              | `#e8e2ee`                    |
| acento lilás            | `#8b7bb8`              | `#a493cc`                    |
| acento rosa             | `#d98bab`              | `#e2a3bf`                    |
| sussurro (bordas, meta) | `#b5a9be`              | `#4a4156`                    |

**madrugada.** dark-first, pra quem vive de noite. não é a lamparina: é mais fundo, mais saturado, feito para ser o estado principal e não a versão noturna de outra coisa.

| papel        | madrugada |
| ------------ | --------- |
| fundo        | `#14101c` |
| tinta        | `#ece6f2` |
| acento lilás | `#b9a7e0` |
| acento rosa  | `#f0a8cc` |
| sussurro     | `#5a4f6b` |

**gloss** (nome de trabalho). inspiração hyperpop: fofo, bem rosa, colorido, mas adaptado para conforto de leitura. a regra de design: a saturação mora no chrome (cabeçalho, bordas, links, detalhes), e a área de leitura fica calma, com contraste AA garantido. fofura sem dor de cabeça.

| papel            | gloss     |
| ---------------- | --------- |
| fundo            | `#fff5fa` |
| fundo de leitura | `#fffafd` |
| tinta            | `#3d2b3a` |
| acento rosa      | `#ff6fb5` |
| acento cyan      | `#57c9d8` |
| sussurro         | `#e5c4d8` |

hexes são ponto de partida, afinar no olho. piso de contraste: WCAG AA em texto corrido, sempre, nos três presets.

cada canto escolhe um preset e, opcionalmente, uma cor de acento própria dentro dele.

### 7.3 tipografia (fechado)

- **leitura (prosas)**: fraunces
- **chrome (interface)**: atkinson hyperlegible
- dois fontes e só. diacríticos pt-br impecáveis. self-hosted em woff2, subconjuntos latin, pesos limitados a 400, 600 e itálico.
- página de leitura: medida de 65 a 75 caracteres, line-height generoso, nada na tela além da prosa e do essencial.

### 7.4 o canto: arrastar e soltar

blocos fixos, reordenáveis e ocultáveis: **bio, prosas, recados, quem eu leio, links**. sem layout livre. no desktop, arrastar e soltar; no mobile, long-press ou setas. a ordem escolhida vive no record `canto.config`, ou seja, a decoração também é portátil.

### 7.5 notificações quietas

sem badges vermelhos, sem contagens permanentes, sem push, sem email. uma página **visitas** com o resumo desde a última passada: "3 recados, 1 resposta, 2 vizinhos novos te lendo". o resumo zera a cada visita. notificações são um resgate de orkut no melhor sentido: alguém passou aqui.

### 7.6 o axô: escalação

aparece em: botão de descoberta ("passear com o axô"), estados vazios, loading (nadando), 404, tela de convite. **máximo uma vez por tela, nunca dentro do fluxo de leitura.** mascote que interrompe leitura vira anúncio.

### 7.7 tom de voz

frases curtas, fala de amiga, sem ponto de exclamação em excesso, sem gerundismo corporativo. microcopy de referência:

- feed vazio: "por aqui ainda tá quieto. que tal escrever a primeira prosa?"
- botões: prosear · deixar um recado · passear com o axô · seguir esse canto
- publicado: "pronto, sua prosa tá no quintal"
- 404: "o axô procurou, procurou... e não achou essa página"
- apagar: "apagar essa prosa? ela sai do seu pds também."
- convite: "o quintal é pequeno de propósito. você foi convidada."
- visitas vazias: "ninguém passou por aqui desde sua última visita. aproveita o silêncio."
- erro genérico: "ih, algo deu errado. tenta de novo?"

## 8. arquitetura

### 8.1 a forma

o quintal é um **appview atproto, não um host**. a pessoa autentica com sua identidade atproto existente (byo-pds: bsky.social, self-hosted, qualquer um). cada prosa, recado e configuração de canto é um record no repo dela, no pds dela. o quintal roda três coisas: um consumidor de firehose que indexa nossos lexicons, uma camada de consulta (feed, cantos, descoberta) e uma interface web liveview que escreve de volta no repo da pessoa via oauth. custo marginal por usuário próximo de zero.

```
                 ┌─────────────┐
   firehose  --> │  ingestão   │ --> ┌────────────┐
  (relay wss)    │  (genstage) │     │  postgres  │
                 └─────────────┘     │  (índice)  │
                                     └─────┬──────┘
   ┌───────────────┐  oauth + xrpc         │ ecto
   │ pds da pessoa │ ◄───────────────┐     │
   │ (bsky/self)   │                │     ▼
   └───────────────┘          ┌───────────────┐
                              │ phoenix + lv  │ --> navegador
                              └───────────────┘
```

### 8.2 fluxos

1. **entrar.** oauth atproto com escopo restrito às coleções do quintal (nunca pedimos escrita no bluesky). depois do consentimento, criamos o record `canto.config` e um job de backfill indexa o histórico da pessoa.
2. **prosear.** interface otimista, `putRecord` no pds, e o eco do firehose confirma no índice. **ingestão idempotente por design**: nossas próprias escritas chegam duas vezes (otimista e firehose), então é upsert, nunca append.
3. **ler.** consulta direta no índice: prosas onde autor está na vizinhança, ordem cronológica, cursor. sem ranqueamento em nenhuma camada.
4. **passear.** sorteia um repo ativo do índice, sorteia uma prosa dele, serve com a carinha do axô.
5. **recado.** `createRecord` no repo de quem escreve, apontando o canto de destino. o dono do canto vê na página visitas e pode ocultar (flag local no índice).
6. **depoimento.** `createRecord` no repo de quem escreve. fica pendente até o aceite do dono do canto. na v1 o aceite é estado local do appview; na v2 pode virar record.
7. **convite.** código único validado no cadastro, marcado como usado, e a pessoa nova recebe sua cota de 5.

### 8.3 stack

estilo da casa: deps mínimas, behaviours em vez de use, pattern matching em vez de libs de validação, nix flake, finch, mox e bypass.

| peça        | escolha                                           | nota                                                                                                                          |
| ----------- | ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| web         | phoenix + liveview, ssr                           | sem spa. gettext desde a linha 1                                                                                              |
| atproto     | proto_rune (dogfood)                              | requisitos detalhados na seção 9                                                                                              |
| ingestão    | websocket do firehose, genstage, postgres         | broadway só se a contra-pressão aparecer; no alpha não aparece                                                                |
| banco       | postgres, jsonb mais colunas extraídas            | sqlite considerado e rejeitado: escrita de firehose concorrente com leitura web. backup: pg_dump agendado para object storage |
| jobs        | oban                                              | backfills, cache de blobs, eventos de visitas                                                                                 |
| http        | finch                                             |                                                                                                                               |
| testes      | mox na fronteira xrpc, bypass com fixtures de pds |                                                                                                                               |
| cache       | ets para resolução de identidade                  |                                                                                                                               |
| dev e infra | nix flake, um vps (hetzner ou fly), caddy         | 10 a 15 euros por mês no total                                                                                                |

### 8.4 o índice (postgres)

tabelas e colunas principais:

- **identidades**: did (pk), handle, pds_url, atualizado_em
- **prosas**: uri (pk), autor_did, cid, texto, tipo, reply_root, reply_parent, langs, created_at, indexed_at
- **prosa_imagens**: prosa_uri, posicao, blob_ref, alt
- **recados**: uri (pk), autor_did, subject_did, texto, oculto (bool), created_at
- **depoimentos**: uri (pk), autor_did, subject_did, texto, aceito (bool, null até decisão), created_at
- **blogrolls**: dono_did (pk), items (jsonb), updated_at
- **cantos**: dono_did (pk), tema, cor, blocos (jsonb), bio, links (jsonb), updated_at
- **follows**: seguidor_did, seguido_did, uri, created_at (pk composta; uri guardada para processar deletes)
- **convites**: codigo (pk), criado_por, usado_por, criado_em, usado_em
- **visitas_eventos**: id, dono_did, tipo (recado, resposta, novo_leitor, depoimento), ref_uri, autor_did, created_at
- **visitas_lido_em**: dono_did (pk), visto_em
- **firehose_cursor**: id, cursor

### 8.5 consistência

toda escrita é upsert idempotente por uri. deletes chegam pela firehose e viram tombstones (linha marcada, não apagada, para segurar threads órfãs com graça). eventos de identidade (handle trocado, conta desativada) invalidam o cache do ets e atualizam a tabela de identidades.

## 9. proto_rune: o que precisa existir

checklist para auditar o que já existe e o que falta. é o coração do m0.

### 9.1 oauth atproto

o fluxo inteiro de login e autorização:

- client metadata: `client_id` como url apontando para o documento de metadados servido pelo quintal
- descoberta por conta: handle resolve para did, did document aponta o pds, o pds expõe o authorization server (protected resource metadata e authorization server metadata)
- par (pushed authorization request), pkce, e dpop com tratamento de nonce (retry em `use_dpop_nonce`)
- **escopo por coleção**: pedir apenas `repo:place.quintal.feed.prosa`, `repo:place.quintal.canto.*` e `repo:place.quintal.graph.follow`. nunca escopo amplo, nunca coleções do bluesky
- refresh de token transparente, revogação no logout, sessão indexada por did
- surface em elixir: um behaviour `Quintal.Auth` com a implementação proto_rune atrás, testável com mox

### 9.2 identidade

- `com.atproto.identity.resolveHandle` e resolução de did (plc.directory e did:web)
- cache em ets com ttl curto
- invalidação dirigida pelos eventos `identity` e `handle` da firehose

### 9.3 leitura e backfill

- `com.atproto.repo.getRecord` e `listRecords` paginado: suficiente para o backfill da v1
- caminho robusto para depois: `com.atproto.sync.getRepo` com decode de CAR mais CBOR e caminhada na MST
- `com.atproto.repo.describeRepo` para descobrir coleções presentes

### 9.4 escrita

- `createRecord`, `putRecord`, `deleteRecord`
- `swapRecord` e `swapCommit` para concorrência otimista (edição segura do que a firehose ainda não ecoou)
- validação local do record contra o lexicon antes de escrever: falhar cedo, falhar em casa

### 9.5 firehose

- `com.atproto.sync.subscribeRepos` por websocket: frames CBOR, eventos commit, identity e handle
- cursor persistido em disco (tabela `firehose_cursor`), reconnect retomando do cursor
- filtro por coleção no consumidor: só processar `place.quintal.*` mais eventos de identidade
- dedupe: a escrita otimista e o eco da firehose são o mesmo evento chegando duas vezes

### 9.6 blobs

- `com.atproto.sync.getBlob` contra o pds de origem
- proxy no appview com cache em disco e headers de cache agressivos
- content-type preservado, limite de tamanho respeitado (2MB por imagem, vem do lexicon)

### 9.7 publicação de lexicons

- schemas servidos em `priv/static/lexicons/<nsid>.json`, via `Plug.Static`, acessíveis em `quintal.place/lexicons/...` (fly proxy termina TLS para ambos os domínios no mesmo app)
- versionamento no monorepo, tags `lexicons-v*`, changelog no spec
- resolução oficial (DNS TXT em `_lexicon.place.quintal` + record `com.atproto.lexicon.schema`) fica para quando houver interop externa; no dogfood o proto_rune carrega os schemas de disco

### 9.8 testes

- fixtures de pds com bypass: login, escrita, listRecords
- mox nas fronteiras: auth, repo, firehose
- um pds falso em memória para testes de integração ponta a ponta seria o sonho do m0 tardio

## 10. lexicons (rascunhos)

autoridade `place.quintal`, derivada de quintal.place. versionados e públicos desde o dia 1.

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
            "items": { "type": "ref", "ref": "app.bsky.richtext.facet" }
          },
          "tipo": {
            "type": "string",
            "knownValues": ["nota", "pergunta", "cronica", "ensaio"]
          },
          "reply": { "type": "ref", "ref": "#replyRef" },
          "images": {
            "type": "array",
            "maxLength": 4,
            "items": { "type": "ref", "ref": "#imagem" }
          },
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
    }
  }
}
```

decisões codificadas no schema: alt obrigatório em toda imagem, máximo de 4 imagens, 10.000 grafemes de texto. facets reusam o padrão do bluesky, o que dá interop de rich text de graça. o tipo `pergunta` não muda estrutura nem ordenação, só a ênfase visual na thread.

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

qualquer pessoa pode deixar recado em qualquer canto. o record vive no repo de quem escreveu. o dono do canto pode ocultar, e o ocultar é estado do appview: sua fala fica intacta no seu pds, a parede é minha.

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
              "knownValues": [
                "bio",
                "prosas",
                "recados",
                "quem-eu-leio",
                "links"
              ]
            }
          },
          "bio": { "type": "string", "maxGraphemes": 500 },
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

`blocos` guarda a ordem do arrastar e soltar: bloco ausente está escondido. `tema` é o preset, e a dupla luminosidade do papel é resolvida na renderização, não no dado. `cor` é o acento opcional dentro do preset.

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

### 10.7 reservado

`place.quintal.roda.*` para a v2. namespace segurado, nada mais por agora.

## 11. moderação (o chão, mesmo em alpha fechado)

- dono do canto oculta recados no próprio espaço; o record segue intacto no pds do autor
- depoimentos exigem aceite, o que já é uma camada de moderação embutida
- block e report caem numa fila de admin de uma pessoa
- convites são códigos únicos, revogáveis enquanto não usados
- conteúdo em pds da bsky herda a moderação de blobs deles, o que cobre o chão do assustador e ilegal no alpha
- labeler próprio: conversa de v2

## 12. marcos

| marco | conteúdo                                                                                        | sai do forno quando                 |
| ----- | ----------------------------------------------------------------------------------------------- | ----------------------------------- |
| m0    | lexicons publicados e resolvíveis; proto_rune com oauth, escrita, backfill e firehose (seção 9) | caminho crítico, a incógnita real   |
| m1    | criar canto, escrever e ler as próprias prosas, sem feed                                        | já dá para usar como diário público |
| m2    | follows, ingestão de firehose, feed cronológico                                                 | a vizinhança fica legível           |
| m3    | recados, cumadis, depoimentos com aceite, três presets de tema                                  | a vizinhança fica decorada          |
| m4    | axô e o passear, convites com cota de 5, polish                                                 | alpha com cerca de 30 amigos        |

## 13. custos

um vps de 10 a 15 euros por mês, object storage em trocos, domínios já pagos. total: menos que dois cafés por mês. modelo de dinheiro fica para depois, com a restrição de arquitetura "custo marginal por usuário próximo de zero" já embutida desde o início.

## 14. decisões fechadas

- lexicon próprio: a linguagem do lugar vira protocolo
- byo-pds na v1; pds gerenciado depois, no modelo da tangled
- imagens: máximo de 4 por prosa, alt obrigatório, proxy com cache no appview
- sem posts do bluesky no feed
- grafo de follow próprio
- pt-br only no dia 1, gettext-ready
- público por padrão; privacidade é dignidade, não sigilo
- features coletivas agora, governança depois
- oss primeiro, dinheiro depois
- semente: comunidade pessoal, 30 a 50 convidados
- domínios registrados: quintal.blog.br e quintal.place
- fontes: fraunces para leitura, atkinson hyperlegible para a interface
- depoimentos só aparecem após aceite
- recados abertos a qualquer pessoa
- prosa com limite de 10.000 grafemes
- tipo pergunta: apenas ênfase visual, sem mudança estrutural
- três presets: papel (default, com lamparina automática à noite), madrugada (dark-first), gloss (hyperpop adaptado para leitura)
- css customizado: v2, talvez
- notificações: só a página visitas, sem email
- mascote axô aprovado
- convites: códigos únicos, cada convidado pode convidar até 5 pessoas

## 15. questões abertas

1. nome final do preset hyperpop. gloss é nome de trabalho.
2. auditoria do proto_rune: o que da seção 9 já existe e o que falta de fato.
3. design visual do axô e mockup dos cantos. briefing em `quintal-mockup-briefing.md`.
4. anti-spam de recados: limite por dia por pessoa? aberto, mas provavelmente desnecessário em alpha fechado.
5. aceite de depoimento vira record na v2? afeta portabilidade do aceite.
