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

Live at https://treasure-hunt.examples.elementary.codes, deployed by [CI](../../.github/workflows/treasure-hunt.yml) on every push to `main`: one SAM stack with the Lambda behind an HTTP API, and the page in S3, both served through CloudFront with `/rpc/*` routed to the API.

To your own account:

```sh
npm run build:lambda
npm run build
sam deploy --resolve-s3
```

Then upload `dist` to the stack's `SiteBucket` and open its `Url`.
