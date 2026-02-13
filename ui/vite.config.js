import tailwindcss from "@tailwindcss/vite";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  resolve: {
    alias: {
      "@gleam": path.resolve(__dirname, "build/dev/javascript/ui"),
    },
  },
  plugins: [tailwindcss()],
});
