import type { IncomingMessage, ServerResponse } from "node:http";
import type { Connect, Plugin } from "vite";

export type LambdaProxyTarget = {
  port?: number;
  uri?: string;
};

const mount = "/rpc";

/** Forward `/rpc` to `sam local start-api`. The gateway sees the full path. */
export function samProxy(target: LambdaProxyTarget = {}): Plugin {
  const base = resolveURI(target, 3000);
  return rpcPlugin("sam-lambda-proxy", (req, res, path) =>
    forwardHTTP(req, res, `${base}${req.url ?? path}`, {
      hint: "sam local start-api is not running. Start it with: npm run api",
    }),
  );
}

/**
 * Wrap `/rpc` as an API Gateway HTTP API v2 event and POST it to the runtime's
 * `/invoke` endpoint (`swift run Lambda`).
 */
export function directProxy(target: LambdaProxyTarget = {}): Plugin {
  const invoke = invocationURL(resolveURI(target, 7000));
  return rpcPlugin("direct-lambda-proxy", (req, res, path) =>
    forwardInvoke(req, res, path, invoke),
  );
}

function rpcPlugin(
  name: string,
  handle: (req: IncomingMessage, res: ServerResponse, path: string) => Promise<void>,
): Plugin {
  const middleware: Connect.NextHandleFunction = (req, res, next) => {
    const path = (req.url ?? "").split("?")[0];
    if (path !== mount && !path.startsWith(`${mount}/`)) {
      next();
      return;
    }
    void handle(req, res, path);
  };
  return {
    name,
    configureServer(server) {
      server.middlewares.use(middleware);
    },
    configurePreviewServer(server) {
      server.middlewares.use(middleware);
    },
  };
}

function resolveURI(target: LambdaProxyTarget, defaultPort: number): string {
  const uri = target.uri?.trim();
  if (uri) {
    return uri.endsWith("/") ? uri.slice(0, -1) : uri;
  }
  return `http://127.0.0.1:${target.port ?? defaultPort}`;
}

function invocationURL(base: string): string {
  return base.endsWith("/invoke") ? base : `${base}/invoke`;
}

async function forwardHTTP(
  req: IncomingMessage,
  res: ServerResponse,
  url: string,
  { hint }: { hint: string },
) {
  try {
    const body = req.method === "GET" || req.method === "HEAD" ? undefined : await readBody(req);
    const upstream = await fetch(url, {
      method: req.method,
      headers: outgoingHeaders(req),
      body,
    });
    res.statusCode = upstream.status;
    upstream.headers.forEach((value, name) => {
      if (name === "transfer-encoding") {
        return;
      }
      res.setHeader(name, value);
    });
    res.end(Buffer.from(await upstream.arrayBuffer()));
  } catch {
    fail(res, hint);
  }
}

async function forwardInvoke(
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
  invoke: string,
) {
  const body = await readBody(req);
  const event = gatewayEvent(req, path, body);
  try {
    const lambda = await fetch(invoke, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(event),
    });
    const payload = (await lambda.json()) as {
      statusCode?: number;
      headers?: Record<string, string>;
      body?: string;
    };
    res.statusCode = payload.statusCode ?? lambda.status;
    for (const [name, value] of Object.entries(payload.headers ?? {})) {
      res.setHeader(name, value);
    }
    if (!res.hasHeader("content-type") && payload.body) {
      res.setHeader("content-type", "application/json; charset=utf-8");
    }
    res.end(payload.body ?? "");
  } catch {
    fail(
      res,
      "The local Lambda server is not running. Start it with: swift run Lambda",
    );
  }
}

function gatewayEvent(req: IncomingMessage, path: string, body: Buffer) {
  const rawQueryString = (req.url ?? "").split("?")[1] ?? "";
  const method = req.method ?? "POST";
  const pathParameters = { proxy: path.slice(mount.length + 1) };
  const routeKey = "POST /rpc/{proxy+}";
  const now = Date.now();
  return {
    version: "2.0",
    routeKey,
    rawPath: path,
    rawQueryString,
    headers: incomingHeaders(req),
    pathParameters,
    requestContext: {
      accountId: "local",
      apiId: "local",
      domainName: "localhost",
      domainPrefix: "localhost",
      http: {
        method,
        path,
        protocol: "HTTP/1.1",
        sourceIp: req.socket.remoteAddress ?? "127.0.0.1",
        userAgent: headerValue(req.headers["user-agent"]) || "vite",
      },
      requestId: "local",
      routeKey,
      stage: "$default",
      time: new Date(now).toISOString(),
      timeEpoch: now,
    },
    body: body.length === 0 ? undefined : body.toString("utf8"),
    isBase64Encoded: false,
  };
}

async function readBody(req: IncomingMessage): Promise<Buffer> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return Buffer.concat(chunks);
}

function incomingHeaders(req: IncomingMessage): Record<string, string> {
  const headers: Record<string, string> = {};
  for (const [name, value] of Object.entries(req.headers)) {
    if (value === undefined) {
      continue;
    }
    headers[name] = Array.isArray(value) ? value.join(",") : value;
  }
  return headers;
}

function outgoingHeaders(req: IncomingMessage): Headers {
  const headers = new Headers();
  for (const [name, value] of Object.entries(req.headers)) {
    if (value === undefined || name === "host" || name === "content-length") {
      continue;
    }
    headers.set(name, Array.isArray(value) ? value.join(",") : value);
  }
  return headers;
}

function headerValue(value: string | string[] | undefined): string {
  if (value === undefined) {
    return "";
  }
  return Array.isArray(value) ? value.join(",") : value;
}

function fail(res: ServerResponse, message: string) {
  res.statusCode = 502;
  res.setHeader("content-type", "text/plain; charset=utf-8");
  res.end(message);
}
