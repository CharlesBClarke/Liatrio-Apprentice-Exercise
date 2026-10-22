# Liatrio Apprentice Exercise

A simple Go web application built with [Fiber](https://gofiber.io/) that exposes a single HTTP endpoint, packaged as a Docker image and delivered through a CI/CD pipeline.

**Live:** https://liatrio-exercise-16535386241.us-west1.run.app

## Endpoint

`GET /` returns a minified JSON object with a message, the current Unix timestamp in milliseconds, and the version of the running build:

```json
{"message":"My name is Charles Clarke","timestamp":1791083402000,"version":"9-abc1234"}
```

## Tech Stack

- **Go** with the **Fiber v3** web framework
- **Docker** multi-stage build on a distroless base image
- **GitHub Actions** for CI/CD
- **Docker Hub** image registry
- **Google Cloud Run** hosting

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

The `-p 8080:80` flag maps port 8080 on your machine to port 80 inside the container. Local builds report `"version":"dev"`; pass `--build-arg VERSION=<value>` to set it.

## Docker Image

The Dockerfile uses a multi-stage build:

1. **Build stage** (`golang:1.27.1-alpine`) downloads dependencies and compiles a static binary.
2. **Run stage** (`distroless/static-debian12:nonroot`) contains only the compiled binary and runs it as a non-root user.

The final image is about 28 MB, compared to about 381 MB for the Go build image, and has no shell or package manager, which reduces its attack surface.

## CI/CD Pipeline

Every pull request and push to `master` runs `.github/workflows/ci.yml`:

1. Build the Docker image and run it on port 80
2. Test it with Liatrio's apprentice-action, pinned to the v1.0.0 commit SHA
3. Verify the response is minified JSON and reports the build version, using `jq`

On a push to `master`, after the tests pass:

4. Push the image to Docker Hub tagged `<run number>-<short SHA>` and `latest`
5. Deploy that versioned image to Cloud Run as a candidate revision with no traffic, authenticating with Workload Identity Federation instead of a stored key
6. Verify the candidate through its tagged URL
7. Canary rollout: send 10% and then 50% of traffic to the candidate while `.github/scripts/canary-probe.sh` sends requests and checks every response (fails on any bad JSON, if more than 2% of requests fail, or if it never sees both versions)
8. Compare the candidate's 5xx rate and p95 latency against the stable revision using Cloud Monitoring metrics (`.github/scripts/canary-metrics.sh`)
9. Promote the candidate to 100% and verify the live endpoint reports the new version

The probe allows a few failed requests because it can't tell which revision served a failed request, so one blip on the stable revision would otherwise roll back a healthy candidate. Comparing error rates per revision is the metrics check's job. Revisions deploy with `--max-instances 3` so swapping an instance doesn't leave zero capacity.

If any deploy step fails, traffic is rolled back to the previous stable revision.

The metrics check fails if the candidate's 5xx rate is more than 1 percentage point above stable, or if its p95 latency is over 100 ms and more than twice stable's. Cloud Monitoring data can take a few minutes to appear, so the script waits until both revisions have at least 100 recorded requests, and fails after 6 minutes without them.

## Progress

- [x] Go + Fiber JSON endpoint
- [x] Dockerfile
- [x] GitHub Actions workflow: build, test with apprentice-action, push to Docker Hub
- [x] Unique image versioning
- [x] Cloud deployment
- [x] Automatic deployment on merge to master
