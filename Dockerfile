FROM public.ecr.aws/docker/library/golang:1.26-alpine@sha256:ce864e7223ac17b1775e6fd0b4c0db580c2eb50e7953a427916379e4b92a1628 AS build

WORKDIR /src
COPY go.mod go.sum ./
COPY vendor ./vendor
COPY cmd/visit-counter ./cmd/visit-counter
RUN CGO_ENABLED=0 go build -mod=vendor -trimpath -ldflags="-s -w" -o /visit-counter ./cmd/visit-counter

FROM scratch

COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /visit-counter /usr/local/bin/visit-counter
COPY cmd/visit-counter/migrations /migrations
USER 65532:65532
ENTRYPOINT ["visit-counter"]
CMD ["serve"]
