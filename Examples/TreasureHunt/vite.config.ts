import { resolve } from "node:path";
import { defineConfig } from "vite";
import swiftWasm from "@elementary-swift/vite-plugin-swift-wasm";
import { directProxy, samProxy } from "./vite/lambda-proxy.js";

const target = { uri: process.env.LAMBDA_PROXY_URI };
const lambdaProxy = process.env.LAMBDA_PROXY_MODE === "sam" ? samProxy(target) : directProxy(target);

export default defineConfig(({ command }) => ({
  resolve: {
    alias: {
      ElementaryFlow: resolve(
        import.meta.dirname,
        ".build/checkouts/elementary-flow/css/elementary-flow.css",
      ),
    },
  },
  plugins: [
    lambdaProxy,
    swiftWasm({
      useEmbeddedSDK: true,
      js: { wasiRuntime: "uwasi" },
      extraBuildArgs:
        command === "build"
          ? ["-debug-info-format", "none"]
          : [],
    }),
  ],
}));
