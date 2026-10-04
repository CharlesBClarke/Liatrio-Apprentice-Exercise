FROM golang:1.27.1-alpine AS build
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -o /server .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /server /server
EXPOSE 80
USER nonroot:nonroot
ENTRYPOINT ["/server"]
