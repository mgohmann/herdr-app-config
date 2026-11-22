// Minimize / maximize / close for layouts that draw their own title bar (root "titlebar":"none")
// on Windows and Linux. Put it as a block at the far right of the tab row; size it with the block's
// own size (px = buttons * width). Props (all optional):
//   width   button width in px (default 44)         icon   icon size in px (default 16)
//   order   ["minimize","maximize","close"] in any order, or a subset
import { View, div, svg } from "gpui-kit";
import { theme, run, window, props } from "herdr";

export default class WindowControls extends View {
  button(id, t, w, width, icon) {
    const close = id === "close";
    const name = id === "maximize" && w.maximized ? "restore" : id;
    const label = { minimize: "Minimize", maximize: w.maximized ? "Restore" : "Maximize", close: "Close window" }[id];
    const action = { minimize: "window.minimize", maximize: "window.maximize", close: "window.close" }[id];
    return div()
      .id(`wc-${id}`)
      .w(width)
      .h_full()
      .flex_none()
      .flex()
      .items_center()
      .justify_center()
      .text_color(t.dim)
      .tooltip(label)
      .accessibility_label(label)
      .hover((s) => (close ? s.bg("#e5484d").text_color("#ffffff") : s.bg(t.hover).text_color(t.foreground)))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click((_e, cx) => {
        cx.stop_propagation();
        run(action);
      })
      .child(svg(`mods/window-controls/icons/${name}.svg`).size(icon).flex_none());
  }

  render() {
    const w = window();
    if (!w?.buttons) return div().size_full();
    const p = props() ?? {};
    const width = Number.isFinite(p.width) ? p.width : 44;
    const icon = Number.isFinite(p.icon) ? p.icon : 16;
    const order = (Array.isArray(p.order) ? p.order : ["minimize", "maximize", "close"]).filter((id) =>
      ["minimize", "maximize", "close"].includes(id),
    );
    const t = theme();
    return div().size_full().flex().items_center().bg(t.chrome).border_b(1).border_color(t.border).children(order.map((id) => this.button(id, t, w, width, icon)));
  }
}
