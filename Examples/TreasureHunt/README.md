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

Through SAM (needs Docker and the SAM CLI):

```sh
npm run build:lambda
npm run api
npm run dev:sam
```

If SAM can't find Docker, set `DOCKER_HOST=unix://$HOME/.docker/run/docker.sock`.

## Deploy

```sh
npm run build:lambda
sam deploy --guided --template-file template.yaml
```

Set `__RPC_ORIGIN__` in `index.html` to the stack's `ApiOrigin`, then `npm run build`.
