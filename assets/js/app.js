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

// Prosear: o composer da home (briefing 5.2). auto-grow, contador que só
// aparece nos últimos 500 grafemes e rascunho local oferecido de volta.
const Prosear = {
  mounted() {
    this.campo = this.el.querySelector("textarea");
    this.contador = this.el.querySelector(".prosear__contador");
    this.aviso = this.el.querySelector(".prosear__rascunho");
    this.chave = "quintal:rascunho";
    this.limite = 10000;

    const rascunho = localStorage.getItem(this.chave);
    if (rascunho && !this.campo.value) {
      this.campo.value = rascunho;
      this.aviso.hidden = false;
    }

    this.campo.addEventListener("input", () => {
      this.cresce();
      this.conta();
      if (this.campo.value) {
        localStorage.setItem(this.chave, this.campo.value);
      } else {
        localStorage.removeItem(this.chave);
      }
    });

    this.handleEvent("prosear-publicado", () => {
      this.campo.value = "";
      localStorage.removeItem(this.chave);
      this.aviso.hidden = true;
      this.cresce();
      this.conta();
    });

    this.cresce();
    this.conta();
  },

  updated() {
    this.cresce();
    this.conta();
  },

  cresce() {
    this.campo.style.height = "auto";
    this.campo.style.height = `${this.campo.scrollHeight}px`;
  },

  conta() {
    const faltam = this.limite - [...this.campo.value].length;
    this.contador.hidden = faltam > 500;
    if (!this.contador.hidden) {
      this.contador.textContent = `tá chegando no limite, faltam ${faltam}`;
    }
  },
};

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { Prosear, ...colocatedHooks },
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
