import { resolve } from "node:path";
import { defineConfig } from "vite";
import swiftWasm from "@elementary-swift/vite-plugin-swift-wasm";
import { directProxy, samProxy } from "./vite/lambda-proxy.js";

const lambdaProxy =
  process.env.LAMBDA_PROXY_MODE === "sam"
    ? samProxy({
      port: 3000,
      uri: process.env.LAMBDA_PROXY_URI,
    })
    : directProxy({
      port: 7000,
      uri: process.env.LAMBDA_PROXY_URI,
    });

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
