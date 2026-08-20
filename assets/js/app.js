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
  el.querySelectorAll("[data-md-wrap],[data-md-prefix],[data-md-link]").forEach((botao) => {
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
  });
}

// MdToolbar: a régua nos forms soltos (bio do onboarding, depoimento),
// que não têm o Composer — aqui ela é o único hook do form.
const MdToolbar = {
  mounted() {
    ligaMd(this.el, this.el.querySelector("textarea"));
  },
};

// Composer: o gesto de escrita do quintal (prosear na home, responder
// na thread, recado no canto). auto-grow, contador opcional que só
// aparece nos últimos 500 grafemes, rascunho local opcional oferecido
// de volta, ctrl/cmd+enter publica e, no mobile, o fundo escurecido e
// o Esc fecham o sheet. `data-rascunho` liga o rascunho local com a
// chave dada; sem o atributo, nada fica guardado.
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
    this.chave = this.el.dataset.rascunho;
    this.limite = Number(this.campo.getAttribute("maxlength")) || 10000;

    ligaMd(this.el, this.campo);

    // ensaio: modo foco em tela cheia. so o composer da home tem o
    // overlay e as pills de tipo; responder e recado passam reto
    this.ensaio = this.el.querySelector(".ensaio");

    if (this.ensaio) {
      this.ensaioTitulo = this.ensaio.querySelector(".ensaio__titulo");
      this.ensaioCorpo = this.ensaio.querySelector(".ensaio__corpo");
      this.ensaioPalavras = this.ensaio.querySelector(".ensaio__palavras");
      this.ensaioBotao = this.ensaio.querySelector("button[type=submit]");
      this.tipoAnterior = "nota";

      // trocar de tipo troca o placeholder junto; ensaio abre o overlay
      this.el.querySelectorAll("input[name=tipo]").forEach((radio) => {
        radio.addEventListener("change", () => {
          if (radio.value === "ensaio") {
            this.abreEnsaio();
          } else {
            this.tipoAnterior = radio.value;
            this.campo.placeholder = radio.dataset.placeholder;
            this.fechaEnsaio();
          }
          this.conta();
        });
      });

      this.ensaio
        .querySelector("[data-voltar]")
        .addEventListener("click", () => this.voltaDoEnsaio());

      this.ensaioCorpo.addEventListener("input", () => {
        this.contaPalavras();
        this.ensaioBotao.disabled = this.ensaioCorpo.value.trim().length === 0;
        if (!this.chave) return;
        if (this.ensaioCorpo.value) {
          rascunhoStore.set(this.chave + ":ensaio", this.ensaioCorpo.value);
        } else {
          rascunhoStore.remove(this.chave + ":ensaio");
        }
      });

      this.ensaioTitulo.addEventListener("input", () => {
        if (!this.chave) return;
        if (this.ensaioTitulo.value) {
          rascunhoStore.set(this.chave + ":ensaio:titulo", this.ensaioTitulo.value);
        } else {
          rascunhoStore.remove(this.chave + ":ensaio:titulo");
        }
      });

      this.ensaio.addEventListener("keydown", (e) => {
        if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
          e.preventDefault();
          this.el.requestSubmit();
        }
        if (e.key === "Escape") this.voltaDoEnsaio();
      });

      this.ensaioBotao.disabled = true;
    }

    if (this.chave) {
      const rascunho = rascunhoStore.get(this.chave);
      if (rascunho && !this.campo.value) {
        this.campo.value = rascunho;
        if (this.aviso) this.aviso.hidden = false;
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

    // clicar fora recolhe o composer so quando o campo ta vazio;
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
      if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        this.el.requestSubmit();
      }

      if (e.key === "Escape") this.fecha();
    });

    // qualquer [data-fecha] fecha: o botao x do composer em tela
    // cheia (mobile) e o fundo escurecido, onde ele existir
    this.el.querySelectorAll("[data-fecha]").forEach((alvo) => {
      alvo.addEventListener("click", () => this.fecha());
    });

    // teclado virtual: o composer em tela cheia e o ensaio tomam a
    // altura visivel, nao a da janela — o teclado encolhe o
    // visualViewport nos dois modos (safari e pwa) e o rodape com o
    // prosear fica sempre acima dele. o textarea cresce com flex e
    // rola por dentro (o cresce() sai de cena nesse modo)
    this.movel = window.matchMedia("(max-width: 47.99rem)");
    this.ancoraTeclado = () => {
      const vv = window.visualViewport;
      if (!vv) return;
      if (this.movel.matches && this.el.classList.contains("prosear--expandido")) {
        this.el.style.height = `${vv.height}px`;
        this.el.style.top = `${vv.offsetTop}px`;
      }
      if (this.ensaio && !this.ensaio.hidden) {
        this.ensaio.style.height = `${vv.height}px`;
        this.ensaio.style.top = `${vv.offsetTop}px`;
      }
    };
    if (window.visualViewport) {
      window.visualViewport.addEventListener("resize", this.ancoraTeclado);
      window.visualViewport.addEventListener("scroll", this.ancoraTeclado);
    }

    this.handleEvent("composer-publicado", () => {
      this.campo.value = "";
      if (this.chave) rascunhoStore.remove(this.chave);
      if (this.aviso) this.aviso.hidden = true;

      if (this.ensaio && !this.ensaio.hidden) {
        this.ensaioCorpo.value = "";
        this.ensaioTitulo.value = "";
        if (this.chave) {
          rascunhoStore.remove(this.chave + ":ensaio");
          rascunhoStore.remove(this.chave + ":ensaio:titulo");
        }
        this.contaPalavras();
        this.fechaEnsaio();
        // depois de prosear um ensaio o composer volta pra nota
        const nota = this.el.querySelector("input[name=tipo][value=nota]");
        if (nota) {
          nota.checked = true;
          this.campo.placeholder = nota.dataset.placeholder;
        }
      }

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
    document.documentElement.classList.remove("ensaio-aberto");
    if (window.visualViewport) {
      window.visualViewport.removeEventListener("resize", this.ancoraTeclado);
      window.visualViewport.removeEventListener("scroll", this.ancoraTeclado);
    }
  },

  updated() {
    this.cresce();
    this.conta();
    // patch do liveview no meio de um gesto nao pode deixar restos
    if (!this.el.classList.contains("prosear--expandido")) {
      this.el.style.transform = "";
    }
  },

  // ensaio aberto: o name="texto" viaja no corpo do overlay, entao o
  // campo principal sai do form (disabled nao submete). o rascunho do
  // ensaio tem chave propria, nao mistura com a nota rapida
  abreEnsaio() {
    this.ensaio.hidden = false;
    this.campo.disabled = true;
    this.ensaioTitulo.disabled = false;
    this.ensaioCorpo.disabled = false;
    document.documentElement.classList.add("ensaio-aberto");

    if (this.chave) {
      const corpo = rascunhoStore.get(this.chave + ":ensaio");
      const titulo = rascunhoStore.get(this.chave + ":ensaio:titulo");
      if (corpo && !this.ensaioCorpo.value) this.ensaioCorpo.value = corpo;
      if (titulo && !this.ensaioTitulo.value) this.ensaioTitulo.value = titulo;
    }

    this.contaPalavras();
    this.ensaioBotao.disabled = this.ensaioCorpo.value.trim().length === 0;
    this.ensaioCorpo.focus();
  },

  fechaEnsaio() {
    if (!this.ensaio || this.ensaio.hidden) return;
    this.ensaio.hidden = true;
    this.ensaio.style.height = "";
    this.ensaio.style.top = "";
    this.campo.disabled = false;
    this.ensaioTitulo.disabled = true;
    this.ensaioCorpo.disabled = true;
    document.documentElement.classList.remove("ensaio-aberto");
  },

  // voltar devolve a pill anterior: ensaio aberto por engano nao
  // sequestra o tipo da prosa
  voltaDoEnsaio() {
    this.fechaEnsaio();
    const anterior = this.el.querySelector(
      `input[name=tipo][value=${this.tipoAnterior}]`,
    );
    if (anterior) {
      anterior.checked = true;
      this.campo.placeholder = anterior.dataset.placeholder;
    }
    this.campo.focus();
  },

  contaPalavras() {
    const n = this.ensaioCorpo.value.trim().split(/\s+/).filter(Boolean).length;
    this.ensaioPalavras.textContent = n > 0 ? `${n} palavras` : "";
  },

  // com texto no campo o rodape fica aberto mesmo sem foco: trocar o
  // tipo no mobile nao pode esconder o botao de prosear. vazio, o botao
  // dorme em ghost ate a primeira letra
  expande() {
    const expandido = this.aberto || this.campo.value.trim().length > 0;
    this.el.classList.toggle("prosear--expandido", expandido);
    // trava a rolagem da pagina atras do sheet (o CSS so aplica no
    // mobile; no desktop o card expandido nao mexe no fundo)
    document.documentElement.classList.toggle("rolagem-travada", expandido);
    this.botao.disabled = this.campo.value.trim().length === 0;
  },

  // fechar o composer em tela cheia: tira a expansao e o foco junto,
  // senao o :focus-within reabre na hora. limpa a ancora do teclado
  fecha() {
    this.aberto = false;
    this.campo.blur();
    this.el.style.height = "";
    this.el.style.top = "";
    this.el.style.transform = "";
    this.expande();
  },

  cresce() {
    // mobile expandido: o campo e flex e rola por dentro; altura
    // inline aqui quebraria o encolhimento com o teclado aberto
    if (this.movel?.matches && this.el.classList.contains("prosear--expandido")) {
      this.campo.style.height = "";
      return;
    }
    this.campo.style.height = "auto";
    this.campo.style.height = `${this.campo.scrollHeight}px`;
  },

  conta() {
    const len = [...this.campo.value].length;
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
      this.contador.hidden = faltam == null;
      if (faltam != null) {
        this.contador.textContent = `tá chegando no limite, faltam ${faltam}`;
      }
    }

    // anel de progresso: o arco acompanha o tanto escrito na escala do
    // tipo; cheio na referencia
    if (this.progresso) {
      const frac = Math.min(1, len / ref);
      this.progresso.style.strokeDashoffset = (56.55 * (1 - frac)).toFixed(2);
    }
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
window.addEventListener("quintal:copiar", (e) => {
  navigator.clipboard?.writeText(e.detail.texto);
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
  hooks: { Composer, MdToolbar, ArrumarBlocos, ...colocatedHooks },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#8b7bb8" }, shadowColor: "rgba(0, 0, 0, .15)" });
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
