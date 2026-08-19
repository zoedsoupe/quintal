# quintal

> "isso aqui é o meu lugar na internet, e essas são as pessoas que eu escolhi dividir ele comigo."

uma plataforma coletiva de blogs sobre atproto, inspirada na web antiga: blogs pessoais, escrita humana, comunidades pequenas, descoberta por acaso. sem otimização de engajamento, sem métricas de popularidade, sem anúncios.

o quintal não é uma rede social. é uma vizinhança. cada pessoa tem seu canto, escreve suas prosas, recebe recados e escolhe quem quer ler. público por padrão, seu por princípio.

## status

mvp em alpha. as coisas mudam, quebram e mudam de novo. use por sua conta e risco.

## princípios

- **cronológico para sempre.** não existe função de ranqueamento e nunca existirá. não é uma feature faltando, é a constituição.
- **sem métricas de popularidade.** sem contadores de seguidores, sem likes, sem números públicos de nada. o feedback são recados, respostas e depoimentos.
- **privacidade = dignidade, não sigilo.** sem rastreamento, sem anúncios, sem colheita de atenção. seus dados no seu pds, suas chaves, sua saída livre.
- **escrita humana.** um compromisso, não um detector. manifesto, não policiamento.
- **simples e rápido acima de tudo.** performance é feature. a página de leitura é o produto.
- **pt-br primeiro.** internacional por arquitetura, brasileiro por alma.

## vocabulário

| palavra    | significado                                                      |
| ---------- | ---------------------------------------------------------------- |
| canto      | sua home pessoal: perfil, prosas, recados, blogroll, links       |
| prosa      | a unidade de escrita. vale nota de duas linhas e ensaio longo    |
| recado     | entrada no livro de visitas de um canto                          |
| depoimento | testemunho público sobre uma pessoa, visível só depois de aceito |
| blogroll   | "quem eu leio": lista curada e pública de cantos                 |
| vizinhança | seu grafo de leitura, quem você escolheu ler                     |
| passear    | a descoberta serendipita, protagonizada pelo axô                 |
| axô        | o mascote, um axolote. axolotes regeneram, e seus dados também   |

## axô

![axô dando oi](./priv/static/images/axo-front-gretting.png)

o axô é o mascote do quintal, um axolote rosa que mora aqui: na logo ele vive no laguinho em frente à cabana, e no app ele aparece guiando os passeios pela vizinhança, nadando no loading e espiando o 404 de dentro d'água. axolotes regeneram partes do corpo inteiras, e aqui seus dados também: se você sair, leva tudo com você, e se voltar, nada se perdeu. o trocadilho axô/achou vira a mecânica de descoberta: "o axô achou isso pra você". ele também se esconde no ícone do pwa como easter egg. as artes oficiais moram em [`priv/static/images`](./priv/static/images).

## a forma

o quintal é um **appview atproto, não um host**. você autentica com sua identidade atproto existente (byo-pds), e cada prosa, recado e configuração de canto é um record no seu repo, no seu pds. o quintal roda três coisas: um consumidor de firehose que indexa nossos lexicons, uma camada de consulta e uma interface web liveview que escreve de volta no seu repo via oauth.

```
                 ┌─────────────┐
   firehose  --> │  ingestão   │ --> ┌────────────┐
  (relay wss)    │             │     │  postgres  │
                 └─────────────┘     │  (índice)  │
                                     └─────┬──────┘
   ┌───────────────┐  oauth + xrpc         │
   │ pds da pessoa │ ◄───────────────┐     ▼
   │ (bsky/self)   │                │ ┌────────────┐
   └───────────────┘                └─┤ phoenix+lv │ --> navegador
                                      └────────────┘
```

## stack

| peça        | escolha                                                         |
| ----------- | --------------------------------------------------------------- |
| web         | phoenix + liveview, ssr. sem spa, gettext desde a linha 1       |
| atproto     | [proto_rune](https://github.com/zoedsoupe/proto_rune) (dogfood) |
| ingestão    | websocket do firehose, upsert idempotente por uri               |
| banco       | postgres, jsonb mais colunas extraídas                          |
| jobs        | oban                                                            |
| http        | finch                                                           |
| testes      | mox na fronteira xrpc, bypass com fixtures de pds               |
| dev e infra | nix flake, fly.io, caddy                                        |

## rodando localmente

precisa de elixir 1.20, otp 28 e postgres.

```sh
mix setup          # deps, banco, assets
mix phx.server     # sobe em localhost:4000
```

outros atalhos:

```sh
mix test           # cria e migra o banco de teste antes de rodar
mix ecto.reset     # derruba e recria o banco de dev
mix precommit      # compile --warnings-as-errors + format + test
```

# licenca

[AGPLv3](./LICENSE)

> a linguagem do lugar vira protocolo. o resto é decoração, e decoração também é portátil.
