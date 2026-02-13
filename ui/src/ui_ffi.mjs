import embed from "vega-embed";

export function vega_embed(id, vega_lite_spec) {
  requestAnimationFrame(() => {
    embed(id, vega_lite_spec, { actions: false });
  });
}
