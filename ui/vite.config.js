import path from "node:path";
import { fileURLToPath } from "node:url";
const __dirname = path.dirname(fileURLToPath(import.meta.url));
import { defineConfig } from "vite";

export default defineConfig({
  resolve: {
    alias: {
      "@gleam": path.resolve(__dirname, "build/dev/javascript/ui"),
    },
  },
});
