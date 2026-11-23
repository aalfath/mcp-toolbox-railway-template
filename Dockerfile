# MCP Toolbox for Databases (googleapis/mcp-toolbox) for Railway.
# One container: the official Toolbox binary on 127.0.0.1:5000, and a small
# Caddy gate on $PORT that lets an MCP request through only with
# "Authorization: Bearer $MCP_AUTH_TOKEN". /healthz stays open for Railway.
FROM caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0 AS caddy
FROM busybox:1.38.0-musl@sha256:80e38f9a1b39188b8bdb28879178edb322a4402b081a9aedda1924609decd6f6 AS busybox

FROM us-central1-docker.pkg.dev/database-toolbox/toolbox/toolbox:1.18.0@sha256:8bb78417eed50397c2cab0ca2a007a00d37a278a44719153aaeaf9b441e5da46
USER 0
COPY --from=busybox /bin/busybox /bin/busybox
RUN ["/bin/busybox", "--install", "-s", "/bin"]
COPY --from=caddy /usr/bin/caddy /usr/bin/caddy
COPY rootfs/ /
RUN chmod 0755 /start.sh
USER 65532
ENV XDG_DATA_HOME=/tmp/caddy-data XDG_CONFIG_HOME=/tmp/caddy-config
EXPOSE 8080
ENTRYPOINT ["/bin/sh", "/start.sh"]
