# Visit counter

The image has two explicit commands:

- `migrate` applies the embedded, versioned PostgreSQL migrations.
- `serve` starts the HTTP server without changing the database schema.

## Run

Build the image:

```sh
docker build -t visit-counter .
```

Set `DATABASE_URL` to a PostgreSQL URL reachable from the container, then run
migrations before starting the application:

```sh
docker run --rm \
  -e DATABASE_URL="$DATABASE_URL" \
  visit-counter migrate

docker run --rm -p 8080:8080 \
  -e DATABASE_URL="$DATABASE_URL" \
  -e DEPLOYMENT_ENVIRONMENT=dev \
  visit-counter serve
```

`PORT` defaults to `8080`. Record a visit with:

```sh
curl -i -X POST \
  -H 'X-Correlation-ID: demo-request' \
  http://localhost:8080/visits
```

The response is `{"count":1}` for the first visit in that deployment
environment. The response echoes a supplied `X-Correlation-ID`, or provides a
generated value when the header is absent. Each successful request writes one
JSON completion log to standard output.
