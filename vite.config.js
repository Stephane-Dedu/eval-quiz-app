import { resolve } from "path";

export default {
  base: "/",
  build: {
    rollupOptions: {
      input: {
        main: resolve(import.meta.dirname, "index.html"),
        "gestion-quiz": resolve(import.meta.dirname, "gestion-quiz.html"),
      },
    },
  },
  publicDir: "public",
};
