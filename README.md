# Liatrio Apprentice Exercise

A simple Go web application built with [Fiber](https://gofiber.io/) that exposes a single HTTP endpoint, packaged as a Docker image and delivered through a CI/CD pipeline.

## Endpoint

`GET /` returns a minified JSON object with a message and the current Unix timestamp in milliseconds:

```json
{"message":"My name is Charles Clarke","timestamp":1791083402000}
```

## Tech Stack

- **Go** with the **Fiber v3** web framework
- **Docker** multi-stage build on a distroless base image
- **GitHub Actions** for CI/CD (in progress)

## Running Locally

### With Go

Requires Go 1.27+.

```sh
go build -o server .
sudo ./server
curl -i localhost:80/
```

The app listens on port 80. Linux requires root to bind to ports below 1024, which is why the binary is run with `sudo`.

### With Docker

```sh
docker build -t liatrio-exercise:dev .
docker run --rm -p 8080:80 liatrio-exercise:dev
curl -i localhost:8080/
```

The `-p 8080:80` flag maps port 8080 on your machine to port 80 inside the container.

## Docker Image

The Dockerfile uses a multi-stage build:

1. **Build stage** (`golang:1.27.1-alpine`) downloads dependencies and compiles a static binary.
2. **Run stage** (`distroless/static-debian12:nonroot`) contains only the compiled binary and runs it as a non-root user.

The final image is about 28 MB, compared to about 381 MB for the Go build image, and has no shell or package manager, which reduces its attack surface.

## Progress

- [x] Go + Fiber JSON endpoint
- [x] Dockerfile
- [ ] GitHub Actions workflow: build, test with apprentice-action, push to Docker Hub
- [ ] Unique image versioning
- [ ] Cloud deployment
- [ ] Automatic deployment on merge to master
