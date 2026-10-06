FROM golang:1.27.1-alpine AS build
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
ARG VERSION=dev
RUN CGO_ENABLED=0 go build -ldflags "-X main.version=${VERSION}" -o /server .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /server /server
EXPOSE 80
USER nonroot:nonroot
ENTRYPOINT ["/server"]
