# Wakapi for Railway: the official image, pinned by version and digest, plus a small start script.
# Upstream's image is distroless (no shell), so a static BusyBox is copied in to run start.sh.
FROM busybox:1.38.0-musl@sha256:80e38f9a1b39188b8bdb28879178edb322a4402b081a9aedda1924609decd6f6 AS busybox

FROM ghcr.io/muety/wakapi:2.18.2@sha256:7a14217db1b6a47816c8d8d0590cc40fa12fd409dfed6c194bbb4cd50f43d913

COPY --from=busybox /bin/busybox /busybox/busybox
# /bin/sh lets `railway ssh` open a shell in the otherwise shell-less image.
COPY --from=busybox /bin/busybox /bin/sh
COPY --chmod=0755 start.sh /app/start.sh

# Upstream bakes sqlite, open sign-up and insecure cookies into the image's ENV, so override them here.
# Railway's HTTPS edge makes secure cookies safe; the start script creates the admin, so sign-up stays closed.
ENV PORT=3000 \
    WAKAPI_DB_TYPE=postgres \
    WAKAPI_DB_NAME=railway \
    WAKAPI_INSECURE_COOKIES=false \
    WAKAPI_ALLOW_SIGNUP=false \
    WAKAPI_LISTEN_IPV4=0.0.0.0
EXPOSE 3000

# Runs as upstream's non-root user (65532). All state lives in PostgreSQL.
ENTRYPOINT ["/busybox/busybox", "sh", "/app/start.sh"]
