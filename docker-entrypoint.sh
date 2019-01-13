#!/bin/sh

#
# Based on:
#
# https://github.com/Kong/docker-kong/raw/691d3b57430ecca159532980f0c891aa1e46612f/alpine/docker-entrypoint.sh
#

set -e

export KONG_NGINX_DAEMON=off

# Wait for Postgres.
until nc -zv "$KONG_PG_HOST" "$KONG_PG_PORT" -w1; do
    sleep 1
done

if [ "$1" = "kong" ]; then
    PREFIX=${KONG_PREFIX:=/usr/local/kong}

    if [ "$2" = "docker-start" ]; then
        # Run bootstrap and migrations.
        kong migrations bootstrap
        kong migrations up

        kong prepare -p "$PREFIX"
        chown -R kong "$PREFIX"

        # workaround for https://github.com/moby/moby/issues/31243
        chmod o+w /proc/self/fd/1
        chmod o+w /proc/self/fd/2

        if [ -n "${SET_CAP_NET_RAW}" ] \
               || has_transparent "$KONG_STREAM_LISTEN" \
               || has_transparent "$KONG_PROXY_LISTEN" \
               || has_transparent "$KONG_ADMIN_LISTEN";
        then
            setcap cap_net_raw=+ep /usr/local/openresty/nginx/sbin/nginx
        fi

        exec su-exec kong /usr/local/openresty/nginx/sbin/nginx \
             -p "$PREFIX" \
             -c nginx.conf
    fi
fi

exec "$@"
