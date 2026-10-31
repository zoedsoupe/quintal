# revisão de ui/ux do quintal — brief para o revisor

v1, outubro 2026. você vai revisar a interface inteira do quintal navegando o app rodando de verdade. este brief é o teu contrato: leia até o fim antes de começar.

modelo sugerido: `opencode/gpt-6.1-sol` (variante `xhigh`). se você for receber screenshots, `opencode-go/gemini-4-argon`.

---

## 0. antes de navegar

1. **seed da vizinhança**: `mix run priv/repo/seeds.exs`. cria uma vizinhança pequena e viva (linda, beto, clara, dora) com prosas, thread, recado, depoimento, follow e visitas não lidas. é a vizinhança que você vai passear.
2. **server**: `mix phx.server` (dev). o app sobe em `http://localhost:4000`.
3. **sessão**: as telas privadas (`/inicio`, `/visitas`, `/conta`, `/escrever`, `/recadar`, `/boas-vindas`) exigem sessão. em dev, suba com a identidade da linda, sem passar pelo oauth:
   ```
   QUINTAL_DEV_DID=did:plc:devlinda mix phx.server
   ```
   é o `Quintal.Auth.Dev`: a portaria deixa passar e o `SessaoHook` assume essa sessão. sem a variável, as privadas respondem 401.
4. **anônimo**: com `QUINTAL_DEV_DID` você está sempre logado — as públicas mostram a cara de morador. pra revisar a experiência **deslogada** (o que um visitante vê na landing, no passear e no canto), suba **sem** a variável e navegue as públicas. revise os dois lados.
5. **tidewave**: use as ferramentas do tidewave pra navegar, capturar a tela, ler o html/dom, inspecionar o estado e medir contraste/tamanho. prefira **medir** a **achar** (ex: pegar o hex real do css em vez de supor).
6. **read-only**: navegue, inspecione, capture. **não submeta formulários** (prosear, recadar, seguir, aceitar depoimento). escrever no pds falha com a sessão de dev e mexe em dado real com a sessão real. você está aqui pra julgar, não pra deixar recado.

---

## 1. aterramento (leia antes)

o quintal tem uma identidade forte e uma constituição explícita. você não julga contra o teu gosto: julga contra o que o produto promete.

- `docs/quintal-spec.md` — a spec v0.3. princípios (§2), tom geral (§7.1), temas (§7.2), tipografia (§7.3), o canto (§7.4), notificações (§7.5), o axô (§7.6), tom de voz (§7.7).
- `docs/quintal-mockup-briefing.md` — o briefing de design.
- `assets/css/tokens.css` — as cores e fontes reais (a fonte da verdade visual).
- `docs/quintal-auditoria.md` — o que foi reconciliado entre spec e código.

**vocabulário (§4)** — use as palavras do produto, que são a arquitetura da informação: **canto** (home), **prosa** (a escrita), **recado** (livro de visitas), **depoimento**, **cumadi** (quem eu leio), **vizinhaca** (seu grafo), **passear** (descoberta), **axô** (o mascote axolote), **visitas** (notificações quietas), **prosear** (publicar).

---

## 2. invariantes (nunca podem ser violados)

qualquer violação aqui é achado **bloqueia**.

1. **cronológico para sempre.** nenhum ranqueamento, nenhuma ordenação por "relevância". o que aparece, aparece por tempo.
2. **sem métricas de popularidade.** nenhum contador de seguidores, likes ou views. nenhum número público de nada. marque qualquer número que se pareça com vaidade.
3. **privacidade = dignidade.** nada de rastreamento, nada que prometa sigilo que o protocolo não entrega. leitura só conta com "li até aqui".
4. **tudo minúsculo no chrome.** botões, títulos, nomes de coisas. "quintal" e "axô" nunca com maiúscula. o texto do autor é intocado.
5. **pt-br, tom de amiga.** frases curtas, sem gerundismo corporativo, sem exclamação em excesso. sem jargão de growth.
6. **o axô aparece no máximo uma vez por tela**, nunca dentro do fluxo de leitura.
7. **simples e rápido.** a página de leitura é o produto. se algo atrapalha a leitura, é grave.

---

## 3. inventário de telas

| rota | acesso | o que é | estados a olhar |
| ---- | ------ | ------- | --------------- |
| `/` | público | landing / entrada | deslogado; campo de handle; convite; com sessão |
| `/cadastro` | público | tutorial byo-pds + pledge | texto, links |
| `/convite` | público | portaria do alpha | código válido/inválido, o axô |
| `/faq` | público | "que lugar é esse?" | leitura, âncoras |
| `/conduta` | público | regrinhas de convivência | leitura |
| `/passear` | público | descoberta com o axô | inicial (vazio), carta sorteada, "de novo", esgotou |
| `/canto/:handle` | público | a home de alguém | próprio vs visita, vazio, com prosas/recados/cumadis, anônimo |
| `/canto/:handle/prosa/:rkey` | público | a página de leitura + thread | prosa longa, thread, anônimo, 404 |
| `/inicio` | privado | o feed cronológico | vazio, cheio, cursor "mais", composer inline |
| `/escrever` (`/prosear`, `/recadar`) | privado | o composer | tipos, imagens, lero (áudio), preview, edição |
| `/visitas` | privado | notificações quietas | vazio ("aproveita o silêncio"), com resumo, fila de depoimentos pendentes |
| `/conta` | privado | conta e convites | cota, gerar convite, exportar, sair |
| `/boas-vindas` | privado | onboarding (2 passos) | nome/bio, tema |
| `/lexicons` (host `quintal.place`) | público | visão humana dos schemas | leitura |
| erro 404 | público | axô de dentro d'água | a frase |

---

## 4. método por tela

pra cada tela, faça a tarefa principal dela como a pessoa faria, e depois:

- **espaço em branco**: capture os **três** estados — **vazio** (sem dados), **cheio** (semeado), e **erro/limite** (ex: 404, cota esgotada, sessão expirada).
- **viewport**: desktop **e** mobile (a interface muda: nav de topo vira nav de baixo).
- **tema**: veja `papel` de dia e `lamparina` à noite (`prefers-color-scheme`), e um canto em `madrugada` e outro em `gloss`. o acento por canto muda.
- **foco e teclado**: dá pra navegar sem mouse? o foco é visível? a ordem faz sentido?
- **fluxo**: siga o caminho de ponta a ponta (entrar → arrumar o canto → prosear → ler → passear → recadar → visitas), não só a tela isolada.
- **mede, não supõe**: contraste (WCAG AA em texto corrido), medida de leitura (65–75ch), alvos de toque, tamanho de fonte.

---

## 5. o que julgar (dimensões)

1. **arquitetura de informação e fluxo.** a pessoa sabe onde está e qual é o próximo passo? as palavras do produto aparecem no lugar certo?
2. **hierarquia e foco.** o que importa salta aos olhos? há ruído competindo com a leitura?
3. **copy.** adere ao tom e ao vocabulário? soa humana? tem jargão, anglicismo, ou gerundismo corporativo?
4. **estados vazios.** ensinam o próximo passo ou deixam a pessoa travada?
5. **erros.** são recuperáveis? a mensagem ajuda ou culpa?
6. **coerência entre telas.** o card, o botão, a headline e o vazio são a *mesma* gramática em todo lugar?
7. **anônimo vs morador.** o que muda quando você não está logado? faz sentido o que se ganha ao entrar?
8. **acessibilidade** (veja a passada 2).
9. **a promessa.** simples, rápido, a leitura como produto. quanta coisa a interface *não* precisa e mostra mesmo assim?

---

## 6. duas passadas ortogonais

produza **duas** listas separadas:

- **passada a — experiência e gosto.** o julgamento de produto/design: fluxo, hierarquia, copy, estados, coerência. critique sem educação.
- **passada b — conformidade.** acessibilidade e boas práticas de interface: contraste AA, foco visual, rótulos, `alt`, semântica de headings, alvos de toque, movimento (respeita `prefers-reduced-motion`?), semântica de formulários.

não misture as duas: um problema de gosto não é um bug de a11y, e vice-versa.

---

## 7. formato de saída

para cada achado, uma linha:

```
tela · severidade · evidência · problema · proposta
```

- **severidade** ∈ `bloqueia` (fere um invariante ou trava a pessoa) · `atrapalha` (custa caro mas dá pra viver) · `polish` (refinamento).
- **evidência**: a rota + o que você viu (um trecho de html, um valor medido, o estado). sem evidência, não é achado.
- **proposta**: concreta e pequena. se for grande, diga que é grande.

no fim, uma **síntese**:

1. os **5 a 10** problemas de maior impacto, ordenados por gravidade (bloqueia primeiro).
2. o que está **bom e não deve mudar** (curto).
3. se quiser, uma seção **dúvidas** onde a spec é ambígua e você não pôde decidir.

seja critique-first. não elogie por educação. o valor está em achar o que não funciona e por quê.

---

## 8. cobertura mínima

você só terminou quando cobriu:

- [ ] as 6 telas públicas + as 6 privadas, cada uma nos estados vazio/cheio
- [ ] o fluxo entrar → arrumar o canto → prosear → ler
- [ ] o passear nos três momentos (inicial, carta, esgotou)
- [ ] uma thread (prosa com respostas) e a página de leitura longa
- [ ] visitas com resumo **e** visitas vazio
- [ ] desktop **e** mobile em pelo menos a landing, o feed, o canto e a leitura
- [ ] papel (dia/noite), madrugada e gloss
- [ ] anônimo (deslogado) na landing, no passear e no canto
- [ ] o 404

---

## 9. limites

- você **não edita código**. propõe.
- você **não submete escrita**.
- se um dado faltar (ex: uma imagem quebrada), diga se é dado ausente ou bug de interface.
- se você depender de algo que não conseguiu acessar (uma tela privada sem sessão), diga isso em vez de inventar.
