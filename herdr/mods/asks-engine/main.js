// dev-config: headless host for the Asks detection engine (engine.js/parse.js/state.js are
// herdr-agent-ask's, unmodified apart from the toast action name). Upstream runs the engine inside
// its own copy of Herdr's tab bar; estro uses better-tabs, so this 1px block hosts it instead.
import { View, div } from "gpui-kit";
import { run, layout, nextCommand } from "herdr";
import { Engine } from "./engine.js";
import { loadConfig } from "./state.js";

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

export default class AsksEngine extends View {
  init(_props, cx) {
    this.engine = new Engine();
    const config = (cx) => cx.spawn(async (cx) => { this.engine.config = await loadConfig(); this.engine._backend = undefined; this.engine._codex = undefined; cx.notify(); });
    config(cx);
    cx.timer.every(30000, config);
    cx.timer.every(1000, (cx) => this.engine.tick(cx));
    cx.spawn(async (cx) => {
      for (;;) {
        const c = await nextCommand();
        if (c === "toggle") this.togglePanel(false);
        else if (c === "open") this.togglePanel(true);
        else if (c === "recheck") this.engine.recheck();
        cx.notify();
      }
    });
  }

  togglePanel(forceOpen) {
    const root = layout(), panel = find(root, "panel"), body = find(root, "panel-body");
    const on = panel && !panel.hidden && body?.active === "asks";
    if (on && !forceOpen) run("layout.hide", { id: "panel" });
    else { run("layout.select", { stack: "panel-body", child: "asks" }); run("layout.show", { id: "panel" }); }
  }

  render(cx) {
    this.engine.tick(cx);
    return div().size_full();
  }
}
