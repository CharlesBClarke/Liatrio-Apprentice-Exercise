# Build stage: compile the Go binary
FROM golang:1.27.1-alpine AS build
WORKDIR /src

# Download dependencies first so this layer is cached between code changes
COPY go.mod go.sum ./
RUN go mod download

COPY . .
# CGO_ENABLED=0 produces a static binary that runs without C libraries
RUN CGO_ENABLED=0 go build -o /server .

# Run stage: minimal image containing only the binary
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /server /server
EXPOSE 80
USER nonroot:nonroot
ENTRYPOINT ["/server"]
