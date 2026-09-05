# Base dev image. devcontainer "features" (node/python/gh) layer on top of
# this at build time via the Dev Containers CLI — that build step has normal
# internet access; only the *running* container is egress-restricted.
FROM mcr.microsoft.com/devcontainers/base:debian

# jq: used by scripts/gh-app-token.sh to parse the GitHub App token response.
RUN apt-get update \
 && apt-get install -y --no-install-recommends jq \
 && rm -rf /var/lib/apt/lists/*

# .NET SDK — version set via DOTNET_VERSION in .env (build-time arg, so it
# comes from the same file as everything else). Installed with Microsoft's
# official script rather than a devcontainer feature so it's configurable
# from .env instead of a hardcoded value in this file.
ARG DOTNET_VERSION=8.0
RUN curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
 && bash /tmp/dotnet-install.sh --channel "${DOTNET_VERSION}" --install-dir /usr/share/dotnet \
 && rm /tmp/dotnet-install.sh \
 && ln -s /usr/share/dotnet/dotnet /usr/local/bin/dotnet
ENV DOTNET_ROOT=/usr/share/dotnet \
    PATH="${PATH}:/usr/share/dotnet" \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1
