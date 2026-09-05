# Base dev image. devcontainer "features" (node/python/gh) layer on top of
# this at build time via the Dev Containers CLI — that build step has normal
# internet access; only the *running* container is egress-restricted.
FROM mcr.microsoft.com/devcontainers/base:debian

# jq: used by scripts/gh-app-token.sh to parse the GitHub App token response.
RUN apt-get update \
 && apt-get install -y --no-install-recommends jq \
 && rm -rf /var/lib/apt/lists/*
