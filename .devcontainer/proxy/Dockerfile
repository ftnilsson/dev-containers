FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends squid curl openssl jq ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY gh-app-token-daemon.sh /usr/local/bin/gh-app-token-daemon.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/gh-app-token-daemon.sh /usr/local/bin/entrypoint.sh
EXPOSE 3128
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
