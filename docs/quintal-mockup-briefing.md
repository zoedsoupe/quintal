# quintal: briefing de ui e mockups

v2, agosto 2026. cobre o design system, todos os componentes e todas as telas do produto, além do mascote axô e da logo. uso previsto: gerar referências visuais para guiar a implementação real em css e liveview. os prompts de imagem estão em inglês porque geradores respondem melhor assim.

atenção: geradores de imagem costumam estragar texto renderizado. trate qualquer texto nos mockups como placeholder; o que importa é layout, cor, tipografia aproximada e clima.

---

## 1. contexto do produto

o quintal é uma plataforma brasileira de blogs pessoais sobre atproto. vizinhança, não rede social. escrita humana, feed cronológico, sem métricas de popularidade. a estética: uma casa arrumada com carinho, gentil, íntima, tudo em letras minúsculas. nada chamativo, nada corporativo.

referências de clima: bear blog (simplicidade), blogosfera brasileira de 2005 (livro de visitas, carinho), orkut (recados, depoimentos, visitas), hyperpop contido (só no preset gloss).

## 2. princípios de ux

1. **uma ação principal por tela.** se duas coisas brigam por atenção, a tela está errada.
2. **simplicidade é redução, não pobreza.** cada tela tem tudo o que precisa e nada além.
3. **o polegar manda no mobile.** navegação e ações principais ao alcance do polegar, alvos de toque de no mínimo 44px.
4. **progressive disclosure.** interfaces nascem pequenas e crescem com a intenção: o composer colapsado, as opções de tipo que só aparecem ao escrever.
5. **otimista por padrão.** publicar, recadar e seguir acontecem na hora na tela; a confirmação do pds chega quieta depois.
6. **estados vazios são convites, não erros.** toda tela vazia tem uma frase de microcopy e uma ação sugerida.
7. **fim de feed declarado.** nada de scroll infinito ansioso: quando acaba, acaba, com uma despedida amiga. anti-doomscroll por design.
8. **sem vermelho de urgência.** notificação nova é um pontinho lilás quieto, nunca um badge vermelho com número.
9. **acessibilidade é base, não camada.** contraste AA em texto corrido nos três presets, foco visível, navegação por teclado completa, alt obrigatório em imagem (vem do lexicon).
10. **loading com cara.** axô nadando só na primeira pintura de uma tela; depois, skeletons suaves.
11. **medida de leitura de 65 a 75 caracteres** em qualquer texto longo, em qualquer tela.
12. **um acento por tela.** em cada momento, uma só cor de acento comanda a atenção.

## 3. navegação

quatro destinos e só: **início, passear, visitas, canto**.

- **mobile**: barra inferior fixa, quatro ícones com rótulos minúsculos. início (casinha), passear (axô com lupa), visitas (cartinha), canto (silhueta ou mini avatar). ponto lilás quieto em visitas quando há novidade.
- **desktop**: barra superior fina, logo miúda à esquerda, os quatro destinos como links textuais à direita. sem sidebar, sem rail, sem menu hambúrguer.
- configurações não são destino: moram dentro do próprio canto, no modo arrumar.
- a navegação some durante a leitura de uma prosa no mobile (esconde ao rolar para baixo, volta ao rolar para cima).

## 4. componentes

### 4.1 botões

- **primário**: pill arredondada, fundo no acento do preset, texto na cor de tinta invertida. uma por tela, no máximo.
- **secundário**: ghost, texto no acento, sem borda ou borda fina de sussurro.
- **destrutivo**: nunca vermelho vivo; vinho fechado e sempre com confirmação em linguagem humana ("apagar essa prosa? ela sai do seu pds também").
- estados: hover escurece 8%, foco com anel visível, disabled com 50% de opacidade. sem sombras pesadas em nenhum estado.

### 4.2 card de prosa (no feed)

- cabeçalho: nome do canto em peso 600, handle e tempo relativo em sussurro ("há 2h"). sem avatar grande: avatar miúdo de 32px ou nenhum.
- corpo: texto na tipografia de leitura, cortado em torno de 400 grafemes com "ler no canto" se passar disso.
- imagens: grid quieto de até 4, cantos arredondados.
- ações: uma só, **responder**. sem curtir, sem repost, sem contadores. respostas existentes aparecem como "3 respostas" em sussurro, clicável para a thread.
- badge "fora do quintal" quando for mirror de site externo (v1.5), com ícone de casinha com seta.
- separação entre cards: espaço em branco e uma hairline de sussurro, sem caixas pesadas. o feed é uma folha, não uma grade de cartões.

### 4.3 composer (prosear)

detalhado na tela 5.2, porque ele mora na home.

### 4.4 bloco de recados (livro de visitas)

- no canto: lista de recados com nome de quem deixou e tempo relativo. sem paginação agressiva: "ver mais recados" no fim.
- campo de entrada sempre visível no fim da lista: "deixar um recado", com limite quieto de 500 grafemes.
- para o dono do canto, cada recado tem um olho discreto para ocultar, visível só para ele.

### 4.5 bloco quem eu leio (blogroll + depoimentos)

- lista de cantos e sites com nota curta opcional ("leio sempre", "escreve como ninguém").
- depoimentos recebidos aparecem como cartõezinhos com aspas tipográficas, depois de aceitos.
- itens externos levam o badge "fora do quintal".

### 4.6 item de visita

- linha única por evento: "fulana deixou um recado", "ciclano respondeu sua prosa", "beltrana começou a ler seu canto", "fulana te deixou um depoimento, quer pendurar na parede?"
- depoimentos pendentes trazem duas ações inline: aceitar, deixar quieto.
- agrupamento por dia, cabeçalhos de data em sussurro.

### 4.7 inputs e formulários

- campos com borda de sussurro, raio generoso, foco com borda no acento. label sempre visível, nunca placeholder como label.
- erros em linguagem humana embaixo do campo, sem vermelho agressivo.

### 4.8 estados vazios

- ilustração do axô, uma frase de microcopy, uma ação. nunca uma tela morta.
- ex.: visitas vazias: axô dormindo + "ninguém passou por aqui desde sua última visita. aproveita o silêncio."

### 4.9 selo humano

- selo pequeno no canto de quem assinou o compromisso: um ícone de mão escrevendo, com tooltip "essa pessoa assinou o compromisso de escrita humana".

## 5. telas

### 5.1 home deslogada (login + convite)

**objetivo**: uma tela, uma ação. nada de landing page longa.

**composição**: centrada. logo da cabana com o laguinho em tamanho médio, o nome "quintal" em fraunces, uma linha de apresentação ("seu canto na vizinhança"), botão primário "entrar com atproto". abaixo, uma linha quieta: "tem um convite? ele entra junto no primeiro acesso". rodapé com três links: sobre, compromisso de escrita humana, código aberto. axô acenando perto da logo, única aparição dele na tela.

**decisões de ux**: sem muro de marketing, sem carrossel de features, sem prints. quem chega aqui já foi convidada por um humano; a tela só precisa ser bonita, calma e rápida.

```
minimal cozy login page for a personal blogging platform, warm cream
paper background (#faf6f1), centered composition: a tiny cabin logo
with a small pond, a literary serif wordmark below, one rounded
primary button in muted lilac, one quiet line of secondary text, a
cute small pink axolotl waving next to the logo, generous negative
space, flat clean vector style, calm 2005-era personal web warmth
with modern restraint, desktop web layout, no metrics, no text-heavy
sections
```

### 5.2 home logada: feed + prosear

**sim, o prosear mora na home.** escrever é a ação central do produto, e esconder o composer atrás de um botão ou de uma rota é atrito contra a própria razão de existir do quintal. a home logada é: composer no topo, feed cronológico embaixo. a mesma rota da tela 5.1, dois estados.

**o composer em detalhe**:

- **colapsado**: uma caixa quieta com o placeholder "o que tá passando no seu quintal?". parece um campo de texto comum, sem avatar obrigatório, sem opções visíveis.
- **ao focar**: expande suavemente. textarea com auto-grow, tipografia de leitura (escrever e ler têm a mesma cara).
- **tipos**: pills quietas abaixo do campo: nota (default, selecionada), pergunta, crônica, ensaio. são metadado, não cerimônia: trocar o tipo não muda nada além da pill.
- **imagens**: um ícone de clipe adiciona até 4 imagens; cada imagem anexada abre um campo de alt obrigatório inline ("descreve essa imagem pra quem não vê"). sem alt, não publica.
- **contador**: invisível até faltar pouco. aparece só nos últimos 500 grafemes, em sussurro ("tá chegando no limite, faltam 320"). nunca um número permanente.
- **ensaio**: ao escolher o tipo ensaio, surge um link "abrir no modo foco", que leva para a tela 5.8.
- **publicar**: botão primário "prosear". otimista: a prosa entra no feed na hora com um estado quieto de "mandando pro seu cantinho..." que some sozinho. erro vira mensagem amiga com botão de tentar de novo, sem modal.
- **rascunho**: se a pessoa sair com texto no composer, guarda local e oferece de volta na próxima visita ("deixou uma prosa pela metade aqui").

**o feed em detalhe**:

- cronológico, só de quem a pessoa segue. cards de prosa como descritos em 4.2.
- carregamento: primeiras 20 prosas, auto-load gentil ao chegar perto do fim.
- **fim de feed**: quando acaba, uma linha de despedida: "você viu tudo do seu quintal por hoje. vai tomar um café." sem sugestão infinita embaixo.
- feed vazio (começo da vida no quintal): axô sentado + "por aqui ainda tá quieto. que tal escrever a primeira prosa? ou passear para achar vizinhos."
- separador de novidade: uma hairline "a partir daqui você já viu" entre o que é novo e o que já foi lido, quieta, sem contador.

```
minimal cozy social reading app home screen, warm cream paper
background (#faf6f1), top: a quiet collapsed composer text field with
rounded corners and soft border, below: a chronological feed of text
post cards separated by generous whitespace and hairline dividers,
each card with a small blog name, quiet timestamp, readable serif text,
one single reply action, no like buttons, no repost, no counters,
thin top navigation bar with four plain text links, muted lilac and
soft pink accents, literary serif type for content, desktop web
layout, flat clean design, generous negative space
```

```
same cozy reading app home screen as a mobile layout, collapsed
composer at top, chronological feed of text posts below, bottom tab
bar with four quiet icons with tiny labels, thumb-reachable, warm
cream paper background, muted lilac accents, flat clean design, no
metrics anywhere
```

### 5.3 canto

**objetivo**: a casa da pessoa. visitável, decorável, viva.

**composição (visitação)**: cabeçalho pequeno com o nome do canto em fraunces, bio de uma linha, links em sussurro. abaixo, os blocos na ordem que o dono escolheu: bio, prosas, recados, quem eu leio, links. botão secundário "seguir esse canto" no cabeçalho, quieto. selo humano ao lado do nome quando presente. se o canto tem morada externa, um link com badge "também mora em..." no cabeçalho.

**modo arrumar** (só no próprio canto, logado): um botão "arrumar o canto" acende o modo de edição in place. alças de arrastar aparecem à esquerda de cada bloco, um olho em cada bloco para ocultar, e uma barra fina no topo com os três presets (papel, madrugada, gloss) como swatches visuais mais a cor de acento. salvar é automático a cada mudança, com um "guardado" quieto que aparece e some. sem página de settings separada.

**decisões de ux**: editar no lugar, nunca num painel distante. a pessoa vê o canto como os outros veem enquanto arruma. drag no desktop, setas no mobile.

```
minimal cozy personal blog homepage, warm cream paper background
(#faf6f1), small quiet header with a blog name in literary serif and
a one-line bio, stacked content blocks in a custom order: recent
posts list, a guestbook section with short visitor messages and an
input field at the end, a "blogs I read" list with short notes, a
simple links list, one quiet secondary follow button, no metrics, no
counters, generous whitespace, muted lilac and soft pink accents,
flat clean design, desktop web layout
```

(para os presets: reutilizar os prompts de papel, lamparina, madrugada e gloss da v1, que seguem valendo, e adicionar a linha "same screen as a mobile layout with bottom tab bar" para as variantes mobile.)

### 5.4 página da prosa (leitura + thread)

**objetivo**: a página mais importante do produto. aqui se lê.

**composição**: a prosa em medida de 65 a 75 caracteres, fraunces, line-height generoso. meta quieto no topo: nome do canto, data, tipo. imagens inline se houver. sem barra lateral, sem relacionados, sem "leia também". abaixo da prosa, uma hairline e a thread de respostas em ordem cronológica, cada uma com o mesmo formato de card, e no fim um composer de resposta com placeholder "responder com uma prosa". link quieto para o canto do autor no cabeçalho.

**decisões de ux**: a navegação inferior esconde ao rolar. zero elementos competindo com o texto. respostas não são comentários: clicar numa resposta abre a página dela, porque ela também é uma prosa.

```
minimal long-form reading page, warm cream paper background (#faf6f1),
a single centered column of literary serif text with a 65-character
measure and generous line height, quiet metadata line at top with
author name and date, a thin divider, then a short chronological
thread of reply cards below, a small reply composer at the end with
placeholder text, nothing else on screen, no sidebar, no related
posts, no metrics, muted lilac accents, flat clean design, desktop
web layout
```

### 5.5 visitas

**objetivo**: responder "alguém passou por aqui?" sem ansiedade.

**composição**: cabeçalho "visitas" e uma linha de resumo desde a última passada ("3 recados, 1 resposta, 2 vizinhos novos te lendo"). lista de itens de visita agrupados por dia. depoimentos pendentes com aceitar e deixar quieto inline. o resumo zera a cada visita e não existe contador permanente.

**decisões de ux**: sem badge vermelho em lugar nenhum; o ponto lilás no ícone de visitas é a única sinalização. a página é um registro de carinho, não uma caixa de entrada com dívidas.

```
minimal cozy notifications page titled visits, warm cream paper
background (#faf6f1), a single quiet summary line at top, a list of
single-line events grouped by day with whisper-gray date headers, one
pending item with two small inline actions (accept, dismiss), a tiny
lilac dot as the only notification signal, no red badges, no numbers
in badges, flat clean design, muted lilac accents, desktop web layout
```

### 5.6 passear

**objetivo**: a descoberta serendipita, protagonizada pelo axô.

**composição**: quase vazia de propósito. axô com a lupa no centro, uma frase ("o axô acha um canto pra você conhecer") e um botão primário grande: "passear". ao clicar, uma carta de descoberta aparece: um trecho de prosa, o nome do canto, e dois caminhos quietos: "visitar esse canto" e "de novo". uma descoberta por vez, sempre.

**decisões de ux**: o passeio é um ritual, não um firehose de sugestões. um de cada vez mantém o encanto e evita a lógica de catálogo. no mobile, a carta ocupa a tela quase inteira.

```
minimal discovery screen for a cozy blogging app, warm cream paper
background (#faf6f1), centered: a cute small pink axolotl holding a
magnifying glass, one short friendly line of text, one large rounded
primary button in muted lilac, huge negative space, flat clean vector
style, calm and charming, desktop web layout, no other elements
```

### 5.7 convite e onboarding

**objetivo**: do código ao primeiro canto em três passos, sem formulário cansativo.

**passo 1, o convite**: axô acenando, o texto "o quintal é pequeno de propósito. você foi convidada.", campo único para o código. erro de código inválido é gentil ("esse código já foi usado ou não existe. pede pra quem te convidou?").

**passo 2, seu canto**: nome do canto, bio de uma linha (opcional), e só.

**passo 3, o tema**: três swatches visuais lado a lado (papel, madrugada, gloss), escolha com um toque, e o botão "entrar no quintal". cai direto na home com o composer esperando e a sugestão da primeira prosa.

**decisões de ux**: nada de tour, tooltip sequencial ou checklist de onboarding. o produto é pequeno o suficiente para se explicar sozinho.

```
minimal invite screen for a cozy blogging app, warm cream paper
background (#faf6f1), centered: a cute small pink axolotl waving, one
friendly sentence about being invited, a single rounded text input
for an invite code, one primary button, huge negative space, flat
clean vector style, desktop web layout
```

### 5.8 modo foco (escrever ensaio)

**objetivo**: uma folha em branco para texto longo, sem o quintal em volta.

**composição**: coluna única de texto em fraunces, medida confortável, sem cabeçalho de navegação. sem campo de título: a prosa é o texto. rodapé fino e quieto com o estado de salvamento ("rascunho guardado há 12s"), o contador que só aparece perto do limite, e o botão "prosear". esc sai para a home com o rascunho salvo.

**decisões de ux**: autosave local a cada pausa de digitação. nada de toolbar de formatação: facets de link e menção nascem da escrita natural (colar url vira link, @ vira menção).

```
minimal distraction-free long-form writing screen, warm cream paper
background (#faf6f1), a single centered column of literary serif
text, no toolbar, no navigation, a thin quiet footer with a whispered
autosave status and one rounded publish button, generous negative
space, calm typewriter mood, flat clean design, desktop web layout
```

## 6. axô, o mascote

### 6.1 character brief

um axolote pequeno e redondo. guelras franzidas em rosa, sorriso gentil permanente, corpo gordinho e simples. estilo: ilustração flat e macia, traços arredondados, formas grandes, clima de livro infantil sem ser infantilizado. paleta: rosa pastel e lilás sobre fundo creme quente.

personalidade: curioso, quieto, caseiro. ele acha coisas para você e fica feliz com isso.

### 6.2 usos na interface

- botão de descoberta ("passear"): axô com uma lupa
- loading de primeira pintura: axô nadando
- estados vazios: axô sentado, tranquilo, talvez dormindo
- 404: axô procurando, sem achar
- tela de convite: axô acenando
- regra de ouro: no máximo uma aparição por tela, nunca dentro do fluxo de leitura

### 6.3 prompt: character sheet

```
cute axolotl mascot character sheet, soft flat illustration style with
rounded shapes and big simple forms, small chubby body, pink frilly
external gills, gentle permanent smile, tiny dot eyes, pastel pink and
lilac palette on a warm cream background, multiple poses on one sheet:
waving hello, swimming happily, holding a magnifying glass, sitting
calmly, sleeping curled up, front view and side view, warm children's
book illustration feeling, cozy and quiet mood, clean negative space,
no text, no letters
```

### 6.4 prompt: versão única, pose de descoberta

```
cute axolotl mascot holding a small magnifying glass, curious happy
expression, soft flat illustration with rounded shapes, pastel pink and
lilac palette, warm cream background, gentle children's book style,
cozy quiet mood, centered composition with generous negative space,
no text, no letters
```

## 7. logo do quintal

### 7.1 conceito

a logo é o lugar, o mascote é o morador. uma cabana pequena e simples com um laguinho na frente, dentro de um quintal. o axô mora no laguinho: isso dá a ele um habitat canônico para ilustrações futuras (espiando de dentro d'água no 404, nadando no loading, acenando da janela da cabana na tela de convite).

elementos máximos da cena: cabana, laguinho, uma vitória-régia ou folha na água, uma cerca baixa sugerindo o quintal. menos que isso é melhor que mais.

### 7.2 restrições técnicas (pwa + favicon)

- canvas quadrado 1:1, composição centrada
- legível a 16px: teste da silhueta, se vira borrão, simplificar
- zona segura de ícone maskable: elementos-chave dentro dos 80% centrais (android corta em círculo e outras formas)
- versão completa: 2 a 4 cores, estilo flat, traços arredondados
- versão favicon: marca simplificada, 1 a 2 cores, formas grossas
- variantes de fundo: papel (`#faf6f1`) e lamparina (`#1d1923`), mais uma transparente
- monocromática de uma cor só como fallback
- sem texto, sem letras, em nenhuma versão

### 7.3 prompt: cena completa (pwa, splash, social card)

```
minimal flat illustration logo of a tiny cozy wooden cabin with a small
pond in front of it, one lily pad floating on the water, a low wooden
fence suggesting a backyard garden, warm cream background (#faf6f1),
soft lilac and muted pink palette, rounded simple shapes, gentle homey
mood, children's book warmth with modern restraint, centered
composition with generous negative space, flat clean vector style,
few colors, no text, no letters
```

### 7.4 prompt: marca simplificada (favicon)

```
extremely simple minimal logo mark of a tiny cabin with a small pond
in front, flat vector style, bold rounded shapes readable at very
small sizes, one or two colors only, no fine details, no texture,
no text, centered, solid deep aubergine background (#1d1923)
```

### 7.5 prompt: variante monocromática

```
single-color line icon of a tiny cabin with a small pond in front,
minimal rounded strokes, flat geometric icon style, designed to work
in one color at favicon size, no text, no shading
```

### 7.6 prompt: variante com o axô em casa (social card, tela de convite)

```
minimal flat illustration of a tiny cozy wooden cabin with a small
pond in front, a cute small pink axolotl peeking out of the pond water
with a gentle smile and frilly gills, low wooden fence suggesting a
backyard, warm cream background, soft lilac and muted pink palette,
rounded simple shapes, cozy quiet mood, children's book warmth,
centered composition, generous negative space, flat clean vector
style, no text, no letters
```

## 8. entregáveis

**brand**
- character sheet do axô (uma folha, 5 poses)
- axô avulso com lupa (versão do botão passear)
- logo: cena completa 512x512, ícone pwa maskable 512x512, favicon 32x32 e 16x16, monocromática em svg, variantes papel, lamparina e transparente, social card 1200x630 com axô no laguinho

**telas** (desktop e mobile de cada, no preset papel; variantes madrugada e gloss pelo menos do canto)
- home deslogada (login + convite)
- home logada (composer + feed)
- canto (visitação) e canto em modo arrumar
- página da prosa com thread
- visitas
- passear
- convite e onboarding (3 passos)
- modo foco

## 9. faça e não faça

**faça**: espaço em branco generoso; tipografia como protagonista; cantos arredondados com moderação; um só acento por tela; ações destrutivas com confirmação humana; fim de feed declarado; mobile pensado para o polegar.

**não faça**: contadores, badges vermelhos, likes, reposts, leaderboards, gradientes agressivos, hero banners, cards com sombra pesada, sidebars, menus hambúrguer, tooltips em sequência, scroll infinito, qualquer coisa que pareça dashboard de métricas.
