FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends squid \
 && rm -rf /var/lib/apt/lists/*
EXPOSE 3128
CMD ["squid", "-N", "-d", "1"]
