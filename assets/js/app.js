// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "../css/app.css";

import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { hooks as colocatedHooks } from "phoenix-colocated/quintal";
import topbar from "../vendor/topbar";

// A régua de formatação markdown dos composers (componente
// `md_ferramentas`): os botões escrevem a sintaxe no cursor e deixam o
// cursor no lugar certo, estilo app do github — sem mágica de seleção.
// Depois de cada gesto dispara `input` pro Composer (rascunho,
// contador, auto-grow) ver a mudança, e devolve o foco pro campo.

function mdInsere(campo, snippet, cursorDentro) {
  const { selectionStart: s, selectionEnd: e, value } = campo;
  campo.value = value.slice(0, s) + snippet + value.slice(e);
  const cursor = s + (cursorDentro ?? snippet.length);
  campo.setSelectionRange(cursor, cursor);
  campo.dispatchEvent(new Event("input", { bubbles: true }));
  campo.focus();
}

function ligaMd(el, campo) {
  if (!campo) return;
  el.querySelectorAll("[data-md-wrap],[data-md-prefix],[data-md-link]").forEach(
    (botao) => {
      botao.addEventListener("click", (e) => {
        e.preventDefault();
        if (botao.dataset.mdWrap !== undefined) {
          const m = botao.dataset.mdWrap;
          mdInsere(campo, m + m, m.length);
        } else if (botao.dataset.mdPrefix !== undefined) {
          // prefixo de bloco só faz sentido no começo de linha
          const antes = campo.value.slice(0, campo.selectionStart);
          const quebra = antes === "" || antes.endsWith("\n") ? "" : "\n";
          mdInsere(campo, quebra + botao.dataset.mdPrefix);
        } else {
          mdInsere(campo, "[]()", 1);
        }
      });
    },
  );
}

// MdToolbar: a régua nos forms soltos (bio do onboarding, depoimento),
// que não têm o Composer — aqui ela é o único hook do form.
const MdToolbar = {
  mounted() {
    ligaMd(this.el, this.el.querySelector("textarea"));
  },
};

// Composer: o gesto de escrita do quintal, em duas superfícies — o
// card inline do desktop (home, thread, canto) e a página de escrita
// (/prosear, /recadar). auto-grow, contador de palavras quieto que
// acorda com texto (limite à vista em campo curto), rascunho local
// opcional oferecido de volta e ctrl/cmd+enter publica. Nada de sheet
// nem overlay: no mobile a escrita é sempre a página, em fluxo de
// documento, e o teclado rola a página sozinho.
// `data-rascunho` liga o rascunho local com a chave dada; sem o
// atributo, nada fica guardado.
// rascunho local: em alguns contextos de PWA o localStorage lanca
// SecurityError; sem o rascunho o composer ainda precisa abrir
const rascunhoStore = {
  get(k) {
    try {
      return localStorage.getItem(k);
    } catch {
      return null;
    }
  },
  set(k, v) {
    try {
      localStorage.setItem(k, v);
    } catch {}
  },
  remove(k) {
    try {
      localStorage.removeItem(k);
    } catch {}
  },
};

// tamanho de referencia por tipo, so cosmetico: o anel enche e o
// contador acorda perto do tamanho esperado daquele tipo de prosa.
// o maxlength real (10000) continua valendo pra todo mundo
const REF_TIPO = { nota: 280, pergunta: 280, cronica: 2000, ensaio: 10000 };

const Composer = {
  mounted() {
    this.campo = this.el.querySelector("textarea");
    this.botao = this.el.querySelector("button[type=submit]");
    this.contador = this.el.querySelector(".prosear__contador");
    this.progresso = this.el.querySelector(".prosear__progresso-arco");
    this.aviso = this.el.querySelector(".prosear__rascunho");
    this.titulo = this.el.querySelector("input[name=titulo]");
    this.chave = this.el.dataset.rascunho;
    this.limite = Number(this.campo.getAttribute("maxlength")) || 10000;

    ligaMd(this.el, this.campo);

    // trocar de tipo troca o placeholder junto; o inicial vem do radio
    // marcado (a pagina pode abrir direto num tipo, ex. ?tipo=ensaio)
    const marcado = this.el.querySelector("input[name=tipo]:checked");
    if (marcado) this.campo.placeholder = marcado.dataset.placeholder;

    this.el.querySelectorAll("input[name=tipo]").forEach((radio) => {
      radio.addEventListener("change", () => {
        this.campo.placeholder = radio.dataset.placeholder;
        this.conta();
      });
    });

    if (this.chave) {
      const rascunho = rascunhoStore.get(this.chave);
      if (rascunho && !this.campo.value) {
        this.campo.value = rascunho;
        if (this.aviso) this.aviso.hidden = false;
      }

      if (this.titulo) {
        const titulo = rascunhoStore.get(this.chave + ":titulo");
        if (titulo && !this.titulo.value) this.titulo.value = titulo;
      }
    }

    this.campo.addEventListener("input", () => {
      this.cresce();
      this.conta();
      this.expande();
      if (!this.chave) return;
      if (this.campo.value) {
        rascunhoStore.set(this.chave, this.campo.value);
      } else {
        rascunhoStore.remove(this.chave);
      }
    });

    if (this.titulo) {
      this.titulo.addEventListener("input", () => {
        if (!this.chave) return;
        if (this.titulo.value) {
          rascunhoStore.set(this.chave + ":titulo", this.titulo.value);
        } else {
          rascunhoStore.remove(this.chave + ":titulo");
        }
      });
    }

    // clicar fora recolhe o card inline so quando o campo ta vazio;
    // com texto ele fica aberto pra nao perder o fio da prosa.
    // pointerdown, nao click: no PWA standalone do iOS o foco rola a
    // pagina e o click sintetizado cai retargetado num elemento fora do
    // composer, o que desfocava o campo no mesmo gesto que abria
    this.cliqueFora = (e) => {
      if (!this.el.contains(e.target) && !this.campo.value.trim()) {
        this.fecha();
      }
    };
    document.addEventListener("pointerdown", this.cliqueFora);

    this.el.addEventListener("focusin", () => {
      this.aberto = true;
      this.expande();
    });

    this.campo.addEventListener("keydown", (e) => {
      if (this.teclaMencao(e)) return;

      if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        this.el.requestSubmit();
      }

      if (e.key === "Escape") this.fecha();
    });

    this.ligaMencoes();

    this.handleEvent("composer-publicado", () => {
      this.campo.value = "";
      if (this.titulo) this.titulo.value = "";
      if (this.chave) {
        rascunhoStore.remove(this.chave);
        rascunhoStore.remove(this.chave + ":titulo");
      }
      if (this.aviso) this.aviso.hidden = true;

      this.cresce();
      this.conta();
      this.fecha();
    });

    this.cresce();
    this.conta();
    this.expande();
  },

  destroyed() {
    document.removeEventListener("pointerdown", this.cliqueFora);
  },

  updated() {
    this.cresce();
    this.conta();
  },

  // com texto no campo o rodape fica aberto mesmo sem foco: trocar o
  // tipo no desktop nao pode esconder o botao de prosear. vazio, o botao
  // dorme em ghost ate a primeira letra
  expande() {
    const expandido = this.aberto || this.campo.value.trim().length > 0;
    this.el.classList.toggle("prosear--expandido", expandido);
    this.botao.disabled = this.campo.value.trim().length === 0;
  },

  // recolher o card inline: tira a expansao e o foco junto, senao o
  // :focus-within reabre na hora
  fecha() {
    this.aberto = false;
    this.campo.blur();
    this.expande();
  },

  cresce() {
    this.campo.style.height = "auto";
    this.campo.style.height = `${this.campo.scrollHeight}px`;
  },

  conta() {
    const len = [...this.campo.value].length;
    const palavras = this.campo.value
      .trim()
      .split(/\s+/)
      .filter(Boolean).length;
    const tipo = this.el.querySelector("input[name=tipo]:checked")?.value;
    const ref = REF_TIPO[tipo] || REF_TIPO.nota;

    if (this.contador) {
      // acorda nos ultimos 20% da referencia do tipo, ou na reta final
      // do limite real (500 grafemes, ou 10% em campos curtos tipo o
      // recado) — o que chegar primeiro
      const faltamRef = ref - len;
      const faltamReal = this.limite - len;
      const margemReal = Math.min(500, this.limite * 0.1);
      let faltam = null;
      if (faltamRef >= 0 && faltamRef <= ref * 0.2) faltam = faltamRef;
      if (faltamReal <= margemReal) faltam = faltamReal;

      if (faltam != null) {
        this.contador.hidden = false;
        this.contador.textContent = `tá chegando no limite, faltam ${faltam}`;
      } else if (this.limite <= 500) {
        // campo curto (recado): o limite fica a vista o tempo todo
        this.contador.hidden = false;
        this.contador.textContent = `${len}/${this.limite}`;
      } else if (palavras > 0) {
        this.contador.hidden = false;
        this.contador.textContent = `${palavras} ${palavras === 1 ? "palavra" : "palavras"}`;
      } else {
        this.contador.hidden = true;
      }
    }

    // anel de progresso: o arco acompanha o tanto escrito na escala do
    // tipo; cheio na referencia
    if (this.progresso) {
      const frac = Math.min(1, len / ref);
      this.progresso.style.strokeDashoffset = (56.55 * (1 - frac)).toFixed(2);
    }
  },

  // autofill de mencao: a vizinhanca vem embutida no form
  // (data-mencoes) e o filtro rola em casa, sem rede por tecla. a
  // lista entra no fluxo logo depois do campo, quieta
  // ponytail: nada de popover ancorado no caret; se incomodar, vira absolute
  ligaMencoes() {
    let vizinhos = [];
    try {
      vizinhos = JSON.parse(this.el.dataset.mencoes || "[]");
    } catch {}
    if (vizinhos.length === 0) return;

    this.menu = document.createElement("ul");
    this.menu.className = "mencoes";
    this.menu.hidden = true;
    this.campo.insertAdjacentElement("afterend", this.menu);

    this.campo.addEventListener("input", () => this.sugereMencao(vizinhos));
    this.campo.addEventListener("blur", () => this.fechaMencao());
  },

  // palavra sob o caret e mencao em aberto? "@", "@ze", "@zoey.s"
  sugereMencao(vizinhos) {
    const caret = this.campo.selectionStart;
    const casamento = this.campo.value.slice(0, caret).match(/(?:^|\s)@([\w.-]*)$/);
    if (!casamento) return this.fechaMencao();

    const q = casamento[1].toLowerCase();
    const itens = vizinhos
      .filter((v) => v.handle.toLowerCase().includes(q) || (v.nome && v.nome.toLowerCase().includes(q)))
      .slice(0, 5);
    if (itens.length === 0) return this.fechaMencao();

    this.mencao = { inicio: caret - casamento[1].length - 1, itens, ativa: 0 };
    this.desenhaMencao();
  },

  desenhaMencao() {
    this.menu.textContent = "";

    this.mencao.itens.forEach((item, i) => {
      const li = document.createElement("li");
      li.className = "mencoes__item";
      li.setAttribute("role", "option");
      li.classList.toggle("mencoes__item--ativa", i === this.mencao.ativa);
      li.textContent = item.nome ? `${item.nome} (@${item.handle})` : `@${item.handle}`;
      // pointerdown com preventDefault: o foco fica no campo e a
      // insercao acontece no mesmo gesto (sem blur no meio)
      li.addEventListener("pointerdown", (e) => {
        e.preventDefault();
        this.insereMencao(item);
      });
      this.menu.appendChild(li);
    });

    this.menu.hidden = false;
  },

  // setas navegam, enter/tab insere, escape so fecha o menu (o composer
  // segue aberto). true = tecla consumida aqui
  teclaMencao(e) {
    if (!this.menu || this.menu.hidden) return false;
    const { itens, ativa } = this.mencao;

    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault();
      this.mencao.ativa = (ativa + (e.key === "ArrowDown" ? 1 : itens.length - 1)) % itens.length;
      this.desenhaMencao();
      return true;
    }

    if ((e.key === "Enter" && !e.ctrlKey && !e.metaKey) || e.key === "Tab") {
      e.preventDefault();
      this.insereMencao(itens[ativa]);
      return true;
    }

    if (e.key === "Escape") {
      this.fechaMencao();
      return true;
    }

    return false;
  },

  insereMencao(item) {
    const antes = this.campo.value.slice(0, this.mencao.inicio);
    const depois = this.campo.value.slice(this.campo.selectionStart);
    this.campo.value = `${antes}@${item.handle} ${depois}`;
    const pos = antes.length + item.handle.length + 2;
    this.campo.setSelectionRange(pos, pos);
    this.fechaMencao();
    // input sintetico: rascunho, contador e auto-grow ja escutam ele
    this.campo.dispatchEvent(new Event("input", { bubbles: true }));
  },

  fechaMencao() {
    if (this.menu) this.menu.hidden = true;
    this.mencao = null;
  },
};

// ArrumarBlocos: drag and drop nativo dos blocos do canto no desktop
// (briefing 5.3). no mobile as setas de cada bloco fazem o trabalho.
const ArrumarBlocos = {
  mounted() {
    this.arrastado = null;

    this.el.addEventListener("dragstart", (e) => {
      const bloco = e.target.closest("[data-bloco]");
      if (!bloco) return;
      this.arrastado = bloco;
      bloco.classList.add("canto-bloco--arrastando");
      e.dataTransfer.effectAllowed = "move";
    });

    this.el.addEventListener("dragend", () => {
      if (this.arrastado) {
        this.arrastado.classList.remove("canto-bloco--arrastando");
      }
      this.arrastado = null;
    });

    this.el.addEventListener("dragover", (e) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = "move";
    });

    this.el.addEventListener("drop", (e) => {
      e.preventDefault();
      const alvo = e.target.closest("[data-bloco]");
      if (!alvo || !this.arrastado || alvo === this.arrastado) return;

      const blocos = [...this.el.querySelectorAll("[data-bloco]")];
      if (blocos.indexOf(this.arrastado) < blocos.indexOf(alvo)) {
        alvo.after(this.arrastado);
      } else {
        alvo.before(this.arrastado);
      }

      const ordem = [...this.el.querySelectorAll("[data-bloco]")].map(
        (b) => b.dataset.bloco,
      );
      this.pushEvent("reordenar", { ordem });
    });
  },
};

// FeedNovidade: a hairline "a partir daqui você já viu" entre o que é
// novo e o que já foi lido (briefing 5.2). a marca de quando a pessoa
// esteve no início mora no localStorage, escrita ao sair da página:
// voltar pra home já conta como "viu". sem contador, sem badge.
const FeedNovidade = {
  mounted() {
    this.chave = "quintal:feed:visto_em";
    try {
      this.visto = localStorage.getItem(this.chave);
    } catch {
      this.visto = null;
    }
    this.marca();
  },

  // o remendo do liveview some com o separador (ele não existe no dom
  // do servidor): depois de cada patch, recoloca se ainda fizer sentido
  updated() {
    this.marca();
  },

  destroyed() {
    try {
      localStorage.setItem(this.chave, new Date().toISOString());
    } catch {}
  },

  marca() {
    if (!this.visto || this.el.querySelector(".feed__ja-viu")) return;

    const itens = [...this.el.querySelectorAll(".feed__item[data-criado]")];
    const primeiroVisto = itens.find((el) => el.dataset.criado <= this.visto);

    if (primeiroVisto && itens.indexOf(primeiroVisto) > 0) {
      const sep = document.createElement("p");
      sep.className = "feed__ja-viu";
      sep.textContent = "a partir daqui você já viu";
      primeiroVisto.before(sep);
    }
  },
};

// nav móvel com cara de tab bar nativa (briefing 3): some ao rolar pra
// baixo, volta ao rolar pra cima. a classe mora no <html>, fora da
// árvore que o liveview remenda.
let ultimaPosicao = window.scrollY;
let rolagemPendente = false;

window.addEventListener(
  "scroll",
  () => {
    if (rolagemPendente) return;
    rolagemPendente = true;

    requestAnimationFrame(() => {
      const posicao = window.scrollY;
      const descendo = posicao > ultimaPosicao && posicao > 80;
      document.documentElement.classList.toggle("rolagem-descendo", descendo);
      ultimaPosicao = posicao;
      rolagemPendente = false;
    });
  },
  { passive: true },
);

// limpar-campo: o servidor pede para esvaziar um campo depois de uma
// escrita otimista (recado deixado, canto adicionado às cumadis)
window.addEventListener("phx:limpar-campo", (e) => {
  const campo = document.getElementById(e.detail.id);
  if (campo) campo.value = "";
});

// quintal:copiar: copia um código de convite para a área de transferência
// e confirma quieto no próprio botão
window.addEventListener("quintal:copiar", (e) => {
  navigator.clipboard?.writeText(e.detail.texto);

  const botao = e.target;
  if (botao instanceof HTMLButtonElement) {
    const antes = botao.textContent;
    botao.textContent = "copiado";
    setTimeout(() => {
      botao.textContent = antes;
    }, 1500);
  }
});

// menu da conta (details no chrome): fecha ao clicar fora ou ao seguir
// um link dele — o toggle nativo do summary cuida do resto
document.addEventListener("click", (e) => {
  document.querySelectorAll(".menu-conta[open]").forEach((menu) => {
    if (!menu.contains(e.target) || e.target.closest("a")) {
      menu.removeAttribute("open");
    }
  });
});

// data-confirm: phoenix_html ja cobre (confirma e cancela o phx-click
// no cancel). um listener proprio aqui mostrava o dialogo duas vezes.

// TemaCanto: visitar um canto veste a página inteira com o tema dele,
// não só o miolo (o chrome mora fora do wrapper .canto-tema). espelha
// o data-theme e o --acento do wrapper no <html> e devolve o tema
// anterior ao sair. na carga cheia o TemaPlug já estampa o tema certo;
// o hook cobre a navegação viva, que não passa pelo plug.
const TemaCanto = {
  mounted() {
    const raiz = document.documentElement;
    this.antes = {
      tema: raiz.getAttribute("data-theme"),
      acento: raiz.style.getPropertyValue("--acento"),
    };
    this.espelhar();
  },

  updated() {
    this.espelhar();
  },

  destroyed() {
    const raiz = document.documentElement;
    if (this.antes.tema) raiz.setAttribute("data-theme", this.antes.tema);
    else raiz.removeAttribute("data-theme");
    if (this.antes.acento) raiz.style.setProperty("--acento", this.antes.acento);
    else raiz.style.removeProperty("--acento");
  },

  espelhar() {
    const raiz = document.documentElement;
    const tema = this.el.getAttribute("data-theme");
    const acento = this.el.style.getPropertyValue("--acento");
    if (tema) raiz.setAttribute("data-theme", tema);
    else raiz.removeAttribute("data-theme");
    if (acento) raiz.style.setProperty("--acento", acento);
    else raiz.style.removeProperty("--acento");
  },
};

// aplicar-tema: o canto guardou tema/cor novos; espelha no <html> para o
// site inteiro sem esperar o próximo carregamento (o TemaPlug estampa no
// root layout a cada página cheia). papel volta ao default sem atributo,
// deixando a lamparina (prefers-color-scheme) decidir a noite.
window.addEventListener("phx:aplicar-tema", (e) => {
  const raiz = document.documentElement;
  const { tema, cor } = e.detail;

  if (tema && tema !== "papel") raiz.dataset.theme = tema;
  else delete raiz.dataset.theme;

  if (cor) raiz.style.setProperty("--acento", cor);
  else raiz.style.removeProperty("--acento");
});

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { Composer, MdToolbar, ArrumarBlocos, FeedNovidade, TemaCanto, ...colocatedHooks },
});

// Show progress bar on live navigation and form submits
topbar.config({
  barColors: { 0: "#8b7bb8" },
  shadowColor: "rgba(0, 0, 0, .15)",
});
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener(
    "phx:live_reload:attached",
    ({ detail: reloader }) => {
      // Enable server log streaming to client.
      // Disable with reloader.disableServerLogs()
      reloader.enableServerLogs();

      // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
      //
      //   * click with "c" key pressed to open at caller location
      //   * click with "d" key pressed to open at function component definition location
      let keyDown;
      window.addEventListener("keydown", (e) => (keyDown = e.key));
      window.addEventListener("keyup", (_e) => (keyDown = null));
      window.addEventListener(
        "click",
        (e) => {
          if (keyDown === "c") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtCaller(e.target);
          } else if (keyDown === "d") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtDef(e.target);
          }
        },
        true,
      );

      window.liveReloader = reloader;
    },
  );
}
