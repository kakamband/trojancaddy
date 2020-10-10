FROM golang:1.15.2-alpine3.12 as builder

ENV XCADDY_VERSION v0.1.5
ENV CADDY_VERSION v2.2.0

RUN apk add --no-cache  --virtual .build-deps \
        build-base \
        cmake \
        boost-dev \
        openssl-dev \
        mariadb-connector-c-dev \
        git \
        ca-certificates; \
        set -eux; \
        wget -O /tmp/xcaddy.tar.gz "https://github.com/caddyserver/xcaddy/releases/download/v0.1.5/xcaddy_0.1.5_linux_amd64.tar.gz"; \
        tar x -z -f /tmp/xcaddy.tar.gz -C /usr/bin xcaddy; \
        rm -f /tmp/xcaddy.tar.gz; \
        chmod +x /usr/bin/xcaddy; \
        git clone -b naive https://github.com/klzgrad/forwardproxy /tmp/forwardproxy; \
        xcaddy build \
            --with github.com/caddyserver/forwardproxy=/tmp/forwardproxy \
            --with github.com/caddy-dns/cloudflare; \
        mv caddy /usr/bin/caddy; \
        chmod +x /usr/bin/caddy; \
        rm -rf /tmp/forwardproxy; \
        git clone https://github.com/trojan-gfw/trojan /tmp/trojan; \
        cd /tmp/trojan; \
        cmake .; \
        make -j $(nproc); \
        strip -s trojan; \
        mv trojan /usr/bin; \
        chmod +x /usr/bin/trojan; \
        cd ~; \
        rm -rf /tmp/trojan; \
        apk del --purge .build-deps

WORKDIR /usr/bin

FROM alpine:3.12

ARG S6_OVERLAY_RELEASE=https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-amd64.tar.gz
ENV S6_OVERLAY_RELEASE=${S6_OVERLAY_RELEASE}

ADD rootfs /
ADD ${S6_OVERLAY_RELEASE} /tmp/s6overlay.tar.gz

RUN apk upgrade --update --no-cache \
    && apk add --no-cache \
        ca-certificates \
        mailcap \
        libstdc++ \
        boost-system \
        boost-program_options \
        mariadb-connector-c \
        openssl \
    && rm -rf /var/cache/apk/* \
    && tar xzf /tmp/s6overlay.tar.gz -C / \
    && rm /tmp/s6overlay.tar.gz

#RUN apk add --no-cache \
#        ca-certificates \
#        mailcap \
#        libstdc++ \
#        boost-system \
#        boost-program_options \
#        mariadb-connector-c \
#        openssl; \
#        openssl req -x509 -nodes -days 365 -subj "/C=CA/ST=QC/O=Company, Inc./CN=mydomain.com" -addext "subjectAltName=DNS:mydomain.com" -newkey rsa:2048 -keyout /etc/ssl/private/0-selfsigned.key -out /etc/ssl/certs/0-selfsigned.crt;

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY --from=builder /usr/bin/trojan /usr/local/bin/trojan
#COPY caddy.json /etc/caddy/config.json
#COPY site.html /usr/share/caddy/index.html
#COPY trojan.json /etc/trojan/config.json

ENV XDG_CONFIG_HOME /config
ENV XDG_DATA_HOME /data

VOLUME /config
VOLUME /data

EXPOSE 80
EXPOSE 443
EXPOSE 2019

# CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
# CMD ["trojan", "/etc/trojan/config.json"]
# CMD ["/bin/sh"]
# CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
ENTRYPOINT [ "/init" ]
