import { defineConfig } from "vitest/config";
import { calmReloads } from "./vite-plugin.ts";

// `npm run build:attach`: one file the hub serves as /attach.js, for any three.js page.
export default defineConfig({
  plugins: [calmReloads()],
  build: {
    outDir: "dist",
    emptyOutDir: false,
    lib: { entry: "src/attach-auto.ts", formats: ["iife"], name: "Drawspeak3D", fileName: () => "attach.js" },
  },
  test: { include: ["test/**/*.test.ts"] },
});
