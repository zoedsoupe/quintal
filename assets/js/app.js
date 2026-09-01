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
// cursor no lugar certo, estilo app do github, sem mágica de seleção.
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
// que não têm o Composer. Aqui ela é o único hook do form.
const MdToolbar = {
  mounted() {
    ligaMd(this.el, this.el.querySelector("textarea"));
  },
};

// Composer: o gesto de escrita do quintal, em duas superfícies: o
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

// tamanho de cada tipo de prosa: referencia pro anel e pro contador,
// e limite duro do campo (o maxlength troca junto com o radio). sem
// radios (resposta, recado) vale o maxlength do atributo
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

    // trocar de tipo troca o placeholder e o limite junto; o inicial
    // vem do radio marcado (a pagina pode abrir direto num tipo, ex.
    // ?tipo=ensaio). lero nao tem texto: o campo escondido nao pode
    // segurar o submit com o required
    const marcado = this.el.querySelector("input[name=tipo]:checked");
    if (marcado) {
      this.campo.placeholder = marcado.dataset.placeholder;
      this.campo.required = marcado.value !== "lero";
      this.aplicaLimite(marcado.value);
    }

    this.el.querySelectorAll("input[name=tipo]").forEach((radio) => {
      radio.addEventListener("change", () => {
        this.campo.placeholder = radio.dataset.placeholder;
        this.campo.required = radio.value !== "lero";
        this.aplicaLimite(radio.value);
        this.conta();
        this.expande();
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
    // re-render do server (troca de tipo, anexo) remarca o form sem a
    // classe de expansao, que so existe no client: reexpande do estado
    // local pra o card nao colapsar no meio do gesto
    this.cresce();
    this.conta();
    this.expande();
  },

  // limite duro do tipo: o maxlength nativo barra tecla e cola alem
  // dele. texto ja escrito maior que o tipo novo fica, mas nao publica
  // (expande desabilita o botao e o contador avisa quanto cortar)
  aplicaLimite(tipo) {
    this.limite = REF_TIPO[tipo] || 10000;
    this.campo.maxLength = this.limite;
  },

  // com texto no campo o rodape fica aberto mesmo sem foco: trocar o
  // tipo no desktop nao pode esconder o botao de prosear. vazio, o botao
  // dorme em ghost ate a primeira letra. lero nao tem texto: o botao
  // acorda quando o chip do audio gravado aparece
  expande() {
    const vazio = this.campo.value.trim().length === 0;
    const estourou = [...this.campo.value].length > this.limite;
    const lero = this.el.querySelector("input[name=tipo]:checked")?.value === "lero";
    const semAudio = lero && !this.el.querySelector(".prosear__anexo--audio");
    const expandido = this.aberto || !vazio || lero;
    this.el.classList.toggle("prosear--expandido", expandido);
    this.botao.disabled = (vazio && !lero) || estourou || semAudio;
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
      // recado), o que chegar primeiro
      const faltamRef = ref - len;
      const faltamReal = this.limite - len;
      const margemReal = Math.min(500, this.limite * 0.1);
      let faltam = null;
      if (faltamRef > 0 && faltamRef <= ref * 0.2) faltam = faltamRef;
      if (faltamReal > 0 && faltamReal <= margemReal) faltam = faltamReal;

      if (len > this.limite) {
        // trocou pra um tipo menor com texto comprido: avisa quanto
        // cortar; o botao dorme ate caber (expande)
        this.contador.hidden = false;
        this.contador.textContent = `não cabe nesse tipo, corta ${len - this.limite}`;
      } else if (faltam != null) {
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
// um link dele; o toggle nativo do summary cuida do resto
document.addEventListener("click", (e) => {
  document.querySelectorAll(".menu-conta[open]").forEach((menu) => {
    if (!menu.contains(e.target) || e.target.closest("a")) {
      menu.removeAttribute("open");
    }
  });
});

// data-confirm: phoenix_html ja cobre (confirma e cancela o phx-click
// no cancel). um listener proprio aqui mostrava o dialogo duas vezes.

// o player de áudio mora dentro do card clicável (ver-fio): os gestos
// nele (play, seek) são dele, nunca navegação. o corte acontece no
// próprio hook, em bubble no botão — um stopPropagation em capture no
// document impediria o evento de chegar no botão

// LeroRecorder: o lero e a prosa falada. um botao, dois estados:
// parado ("fala ai...") -> gravando (cronometro, "pronto?" para). parar
// ja proseia: o blob entra no input de arquivo do form (DataTransfer)
// e o requestSubmit dispara o fluxo comum — o LiveView sobe o anexo e
// espera ele terminar antes de enviar o prosear
const LeroRecorder = {
  mounted() {
    this.botao = this.el.querySelector(".lero__botao");
    this.rotulo = this.el.querySelector(".lero__rotulo");
    this.tempo = this.el.querySelector(".lero__tempo");
    this.erro = this.el.querySelector(".lero__erro");
    this.input = this.el.querySelector("input[type=file]");
    this.estado = "parado";

    if (!navigator.mediaDevices?.getUserMedia || typeof MediaRecorder === "undefined") {
      this.botao.disabled = true;
      this.rotulo.textContent = "esse navegador não grava lero";
      return;
    }

    this.botao.addEventListener("click", () => {
      if (this.estado === "parado") this.grava();
      else if (this.estado === "gravando") this.para();
    });
  },

  destroyed() {
    clearInterval(this.cronometro);
  },

  updated() {
    // o preflight do upload é async: o chip do anexo na tela marca que
    // o server já conhece a entry. só aí o submit pode sair — antes
    // disso ele chegaria com o upload em progresso e perderia o áudio.
    // com a entry registrada o LiveView segura o submit até o upload
    // terminar
    if (!this.proseia) return;
    const anexo = this.el.closest("form").querySelector(".prosear__anexo--audio");
    if (anexo) {
      this.proseia = false;
      this.el.closest("form").requestSubmit();
    }
  },

  async grava() {
    this.erro.hidden = true;

    let stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch {
      this.erro.textContent = "sem microfone não rola lero. confere a permissão aí";
      this.erro.hidden = false;
      return;
    }

    const mime = ["audio/mp4", "audio/webm;codecs=opus", "audio/webm", "audio/ogg;codecs=opus"].find(
      (t) => MediaRecorder.isTypeSupported(t)
    );

    this.chunks = [];
    this.recorder = new MediaRecorder(stream, mime ? { mimeType: mime } : undefined);
    this.recorder.addEventListener("dataavailable", (e) => {
      if (e.data.size > 0) this.chunks.push(e.data);
    });
    this.recorder.addEventListener("stop", () => this.envia());
    this.recorder.start();

    this.segundos = 0;
    this.tempo.textContent = "0:00";
    this.tempo.hidden = false;
    this.cronometro = setInterval(() => {
      this.segundos += 1;
      const mm = Math.floor(this.segundos / 60);
      const ss = String(this.segundos % 60).padStart(2, "0");
      this.tempo.textContent = `${mm}:${ss}`;
    }, 1000);

    this.estado = "gravando";
    this.rotulo.textContent = "pronto?";
    this.el.classList.add("lero--gravando");
  },

  para() {
    clearInterval(this.cronometro);
    this.recorder.stop();
    this.recorder.stream.getTracks().forEach((t) => t.stop());
  },

  envia() {
    this.tempo.hidden = true;
    this.estado = "parado";
    this.rotulo.textContent = "fala aí...";
    this.el.classList.remove("lero--gravando");

    const tipo = (this.recorder.mimeType || "audio/webm").split(";")[0];
    const ext = { "audio/mp4": "m4a", "audio/ogg": "ogg", "audio/webm": "webm" }[tipo] || "webm";
    const blob = new Blob(this.chunks, { type: tipo });

    if (blob.size === 0) return;

    const arquivo = new DataTransfer();
    arquivo.items.add(new File([blob], `lero.${ext}`, { type: tipo }));
    this.input.files = arquivo.files;
    this.proseia = true;
    this.input.dispatchEvent(new Event("change", { bubbles: true }));
  },
};

// AudioPlayer: skin minima das prosas com áudio. o <audio> nativo
// escondido faz decodificação, buffering e streaming; o hook só liga o
// botão play/pause e a trilha clicável. um player por vez: tocar um
// pausa os outros da página
const AudioPlayer = {
  mounted() {
    this.audio = this.el.querySelector("audio");
    this.progresso = this.el.querySelector(".audio__progresso");

    this.el.querySelector(".audio__play").addEventListener("click", (e) => {
      e.stopPropagation();
      if (this.audio.paused) {
        document.querySelectorAll(".audio audio").forEach((a) => a.pause());
        this.audio.play();
      } else {
        this.audio.pause();
      }
    });

    this.audio.addEventListener("play", () => this.el.classList.add("audio--tocando"));
    this.audio.addEventListener("pause", () => this.el.classList.remove("audio--tocando"));

    this.audio.addEventListener("timeupdate", () => {
      const pct = (this.audio.currentTime / this.audio.duration) * 100 || 0;
      this.progresso.style.width = pct + "%";
    });

    this.el.querySelector(".audio__trilha").addEventListener("click", (e) => {
      e.stopPropagation();
      if (!this.audio.duration) return;
      const rect = e.currentTarget.getBoundingClientRect();
      this.audio.currentTime = ((e.clientX - rect.left) / rect.width) * this.audio.duration;
    });
  },
};

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

// envia o form assim que o arquivo e escolhido; com auto_upload o
// o input e comum (nao live_file_input) e quem sobe e o hook via this.upload,
// depois da pessoa arrastar a foto no recorte redondo. cortar no cliente vira
// ~100KB em vez de 5MB de foto de celular. a versao anterior trocava
// input.files no meio do change do LiveView: corrida, upload ficava pendente
// pra sempre e o servidor respondia noreply em silencio.
const AvatarUpload = {
  mounted() {
    // o live_file_input escondido vem antes no dom: mira no input do recorte
    const input = this.el.querySelector(".canto__avatar-input");
    input.addEventListener("change", () => {
      const file = input.files && input.files[0];
      input.value = "";
      if (file) this.abrirRecorte(file);
    });
  },

  abrirRecorte(file) {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => this.montarRecorte(img, url);
    img.onerror = () => URL.revokeObjectURL(url);
    img.src = url;
  },

  montarRecorte(img, url) {
    const TAM = 280; // casa com .canto__recorte-area no canto.css
    const minZoom = Math.max(TAM / img.width, TAM / img.height);
    let zoom = minZoom;
    let dx = (TAM - img.width * zoom) / 2;
    let dy = (TAM - img.height * zoom) / 2;

    const overlay = document.createElement("div");
    overlay.className = "canto__recorte";
    overlay.innerHTML = `
      <div class="canto__recorte-area"><img alt=""></div>
      <input type="range" class="canto__recorte-zoom" aria-label="zoom"
             min="${minZoom}" max="${minZoom * 4}" step="${minZoom / 100}" value="${zoom}">
      <div class="canto__recorte-acoes">
        <button type="button" class="botao" data-usar>usar essa foto</button>
        <button type="button" class="botao botao--fantasma" data-cancelar>cancelar</button>
      </div>`;

    const area = overlay.querySelector(".canto__recorte-area");
    const foto = overlay.querySelector("img");
    const slider = overlay.querySelector(".canto__recorte-zoom");
    foto.src = url;

    const desenhar = () => {
      // a foto nunca deixa buraco: cobre sempre o circulo inteiro
      dx = Math.min(0, Math.max(TAM - img.width * zoom, dx));
      dy = Math.min(0, Math.max(TAM - img.height * zoom, dy));
      foto.style.transform = `translate(${dx}px, ${dy}px)`;
      foto.style.width = `${img.width * zoom}px`;
    };

    area.addEventListener("pointerdown", (e) => {
      area.setPointerCapture(e.pointerId);
      const origem = { x: e.clientX - dx, y: e.clientY - dy };
      const mover = (ev) => {
        dx = ev.clientX - origem.x;
        dy = ev.clientY - origem.y;
        desenhar();
      };
      area.addEventListener("pointermove", mover);
      area.addEventListener("pointerup", () => area.removeEventListener("pointermove", mover), { once: true });
    });

    slider.addEventListener("input", () => {
      const centro = { x: (TAM / 2 - dx) / zoom, y: (TAM / 2 - dy) / zoom };
      zoom = parseFloat(slider.value);
      dx = TAM / 2 - centro.x * zoom;
      dy = TAM / 2 - centro.y * zoom;
      desenhar();
    });

    const fechar = () => {
      URL.revokeObjectURL(url);
      overlay.remove();
    };

    overlay.querySelector("[data-cancelar]").addEventListener("click", fechar);
    overlay.querySelector("[data-usar]").addEventListener("click", () => {
      const escala = 512 / TAM;
      const canvas = document.createElement("canvas");
      canvas.width = canvas.height = 512;
      canvas
        .getContext("2d")
        .drawImage(img, dx * escala, dy * escala, img.width * zoom * escala, img.height * zoom * escala);
      canvas.toBlob((blob) => {
        if (!blob) return fechar();
        const leitor = new FileReader();
        leitor.onload = () => {
          // manda so o base64, sem o prefixo data:image/jpeg;base64,
          this.pushEvent("avatar", { data: leitor.result.split(",")[1] });
          fechar();
        };
        leitor.readAsDataURL(blob);
      }, "image/jpeg", 0.85);
    });

    desenhar();
    this.el.appendChild(overlay);
  },
};

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { Composer, MdToolbar, ArrumarBlocos, FeedNovidade, TemaCanto, AvatarUpload, AudioPlayer, LeroRecorder, ...colocatedHooks },
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
