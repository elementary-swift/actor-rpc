# TreasureHunt

ElementaryUI web app calling a distributed actor on AWS Lambda.

## Run

```sh
swiftly install
npm install
swift run Lambda
npm run dev
```

On macOS, port 7000 is taken by AirPlay Receiver: `LOCAL_LAMBDA_PORT=7001 swift run Lambda` and `LAMBDA_PROXY_URI=http://127.0.0.1:7001 npm run dev`.

Through SAM:

```sh
swift package lambda-build --allow-network-connections docker --base-docker-image swift:amazonlinux2023
npm run api
LAMBDA_PROXY_MODE=sam npm run dev
```

## Deploy

```sh
swift package lambda-build --allow-network-connections docker --base-docker-image swift:amazonlinux2023
sam deploy --guided --template-file template.yaml
```

Set `__RPC_ENDPOINT__` in `index.html` to the stack's `HttpApiUrl`, then `npm run build`.
