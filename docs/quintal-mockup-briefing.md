# quintal: briefing de mockups

briefing para concept art do mascote axô e mockups do canto nos três presets de tema. uso previsto: gerar referências visuais para guiar a implementação real em css. os prompts de imagem estão em inglês porque geradores respondem melhor assim.

atenção: geradores de imagem costumam estragar texto renderizado. trate qualquer texto nos mockups como placeholder; o que importa é layout, cor, tipografia aproximada e clima.

---

## 1. contexto do produto

o quintal é uma plataforma brasileira de blogs pessoais sobre atproto. vizinhança, não rede social. escrita humana, feed cronológico, sem métricas de popularidade. a estética: uma casa arrumada com carinho, gentil, íntima, tudo em letras minúsculas. nada chamativo, nada corporativo.

referências de clima: bear blog (simplicidade), blogosfera brasileira de 2005 (livro de visitas, carinho), hyperpop contido (só no preset gloss).

## 2. axô, o mascote

### 2.1 character brief

um axolote pequeno e redondo. guelras franzidas em rosa, sorriso gentil permanente, corpo gordinho e simples. estilo: ilustração flat e macia, traços arredondados, formas grandes, clima de livro infantil sem ser infantilizado. paleta: rosa pastel e lilás sobre fundo creme quente.

personalidade: curioso, quieto, caseiro. ele **acha coisas** para você e fica feliz com isso.

### 2.2 usos na interface

- botão de descoberta ("passear com o axô"): axô com uma lupa
- loading: axô nadando
- estados vazios: axô sentado, tranquilo, talvez dormindo
- 404: axô procurando, sem achar
- tela de convite: axô acenando
- regra de ouro: no máximo uma aparição por tela, nunca dentro do fluxo de leitura

### 2.3 prompt: character sheet

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

### 2.4 prompt: versão única, pose de descoberta

```
cute axolotl mascot holding a small magnifying glass, curious happy
expression, soft flat illustration with rounded shapes, pastel pink and
lilac palette, warm cream background, gentle children's book style,
cozy quiet mood, centered composition with generous negative space,
no text, no letters
```

## 3. mockups do canto

### 3.1 o que é o canto

a home pessoal de cada pessoa. estrutura de blocos reordenáveis: bio, prosas (lista de posts), recados (livro de visitas), quem eu leio (blogroll com depoimentos), links. cabeçalho pequeno com nome do canto e uma linha de bio. sem contadores de nada, sem avatar gigante, sem banner hero. medida de texto de 65 a 75 caracteres. tipografia: serifada literária macia (fraunces) para leitura, sans super legível (atkinson hyperlegible) para a interface.

telas a mockar, em desktop e mobile:

1. canto (a home)
2. página de leitura de uma prosa
3. feed cronológico
4. página visitas (notificações quietas)

### 3.2 preset papel (default)

duas luminosidades do mesmo preset: papel de dia, lamparina de noite.

- papel (dia): fundo `#faf6f1`, tinta `#2e2833`, acento lilás `#8b7bb8`, acento rosa `#d98bab`, meta `#b5a9be`
- lamparina (noite): fundo `#1d1923`, tinta `#e8e2ee`, acento lilás `#a493cc`, acento rosa `#e2a3bf`, meta `#4a4156`

```
minimal cozy personal blog homepage UI mockup, warm cream paper
background (#faf6f1), soft literary serif headings, small quiet header
with a blog name and one-line bio, stacked content blocks: recent
posts list, a guestbook section, a "blogs I read" list, simple links.
no like buttons, no follower counts, no metrics anywhere. generous
whitespace, 65-character text measure, muted lilac and soft pink
accents on a paper-toned page, calm 2005-era personal blog warmth
with modern restraint, desktop web layout, flat clean design
```

```
same minimal cozy personal blog homepage, dark night variant: deep
aubergine background (#1d1923), soft off-white text (#e8e2ee), muted
lilac and pink accents, warm lamplight feeling, calm and readable,
no metrics, generous whitespace, desktop web layout, flat clean design
```

### 3.3 preset madrugada (dark-first)

mais fundo e mais saturado que a lamparina. é o estado principal, não a versão noturna de outra coisa.

- fundo `#14101c`, tinta `#ece6f2`, acento lilás `#b9a7e0`, acento rosa `#f0a8cc`, meta `#5a4f6b`

```
minimal personal blog homepage UI mockup, dark-first theme, very deep
purple-black background (#14101c), bright but soft off-white text,
saturated lilac and pink accents glowing gently like city lights at
3am, quiet literary mood, small header, stacked content blocks
(posts, guestbook, blogroll, links), no metrics anywhere, generous
whitespace, flat clean design, desktop web layout
```

### 3.4 preset gloss (hyperpop, nome de trabalho)

fofo, bem rosa, colorido, adaptado para leitura. regra de ouro: a saturação mora no chrome (cabeçalho, bordas, links, detalhes) e a área de leitura fica calma, com contraste de sobra.

- fundo `#fff5fa`, fundo de leitura `#fffafd`, tinta `#3d2b3a`, acento rosa `#ff6fb5`, acento cyan `#57c9d8`, meta `#e5c4d8`

```
cute hyperpop-inspired personal blog homepage UI mockup, very light
pink background (#fff5fa), playful saturated pink (#ff6fb5) and soft
cyan (#57c9d8) accents in the header, borders and small details, but
the main reading area stays calm white with dark readable text,
kawaii-adjacent but tidy and restrained, rounded corners, small
header, stacked content blocks (posts, guestbook, blogroll, links),
no metrics, flat clean design, desktop web layout
```

## 4. entregáveis do mockup

- character sheet do axô (uma folha, 5 poses)
- axô avulso com lupa (versão do botão passear)
- canto em papel-dia, papel-lamparina, madrugada e gloss (desktop e mobile de cada)
- página de leitura de prosa em pelo menos papel e madrugada
- feed cronológico em papel
- página visitas em papel

## 5. faça e não faça

faça: espaço em branco generoso, tipografia como protagonista, cantos arredondados com moderação, um só acento por tela mandando na atenção.

não faça: contadores, badges vermelhos, gradientes agressivos, hero banners, cards com sombra pesada, qualquer coisa que pareça dashboard de métricas.
