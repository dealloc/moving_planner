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
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/moving_planner"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

const KeyboardShortcuts = {
  mounted() {
    this._handler = (e) => this.handleKey(e)
    window.addEventListener("keydown", this._handler)
  },
  destroyed() {
    window.removeEventListener("keydown", this._handler)
  },
  handleKey(e) {
    // Never fire when typing in an input, textarea, select, or contenteditable
    const tag = document.activeElement?.tagName
    if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return
    if (document.activeElement?.isContentEditable) return

    const page = this.el.dataset.page

    // Ctrl+Enter / Cmd+Enter: submit the focused form
    if ((e.ctrlKey || e.metaKey) && e.key === "Enter") {
      const form = document.activeElement?.closest("form")
      if (form) { e.preventDefault(); form.requestSubmit() }
      return
    }

    // Skip bare letter shortcuts if modifier keys are held
    if (e.ctrlKey || e.metaKey || e.altKey) return

    if (e.key === "?") {
      e.preventDefault()
      document.getElementById("shortcuts-modal")?.showModal()
      return
    }

    if (e.key === "Escape") {
      // URL-driven modals: click the backdrop link
      const backdrop = document.querySelector(".modal-open .modal-backdrop")
      if (backdrop) { e.preventDefault(); backdrop.click(); return }
      // Assign-driven forms: push cancel event to server
      const formEl = document.querySelector("[data-form-open]")
      if (formEl) {
        e.preventDefault()
        this.pushEvent(formEl.dataset.cancelEvent, {})
      }
      return
    }

    if (e.key === "n") {
      // Only fire "n" if no modal or form is already open
      if (document.querySelector(".modal-open")) return
      if (document.querySelector("[data-form-open]")) return

      const isBoxShow = page === "boxes" && window.location.pathname.match(/^\/boxes\/\d+$/)

      if (isBoxShow) {
        e.preventDefault()
        this.pushEvent("new_item", {})
      } else if (page === "boxes" || page === "furniture") {
        const link = this.el.querySelector("[data-shortcut-new]")
        if (link) { e.preventDefault(); link.click() }
      } else if (page === "todos") {
        e.preventDefault()
        this.pushEvent("new_todo", {})
      }
    }
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, KeyboardShortcuts},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

