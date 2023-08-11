#!/bin/bash
# Dockerfile build script
#
# This file is part of so76831368, Copyright (C) 2023 hakre
# <https://hakre.wordpress.com>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public Licence as
# published by the Free Software Foundation, either version 3 of the
# Licence, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public Licence for more details.
#
# You should have received a copy of the GNU Affero General Public
# Licence along with this program.  If not, see
# <https://www.gnu.org/licenses/>.
#
set -euo pipefail

printf '%s: now building "%s"...\n' "$0" "${BUILD_CONTAINER:?}"

docker rm -fv "${BUILD_CONTAINER:?}" | sed 's/^/  /'

# https://stackoverflow.com/q/76831368/367456
docker build --progress=plain --rm -t "${BUILD_CONTAINER:?}" - <<'DOCKER'
FROM php:8.1-fpm-buster as platform

###
# Infos
RUN set -x; uname -a; cat /etc/lsb-release; php --version; php-fpm --version

###
# Entrypoint

COPY --chmod=775 <<'EOF' "/usr/local/bin/app-docker-php-entrypoint"
#!/bin/sh
set -e

# export TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
# export DD_AGENT_HOST=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
## HK: NOTE: faking the environment variable is for testing only
export DD_AGENT_HOST=FAKE-IT

## HK: blend in datadog agent host in the logs, the container should sink in style
printf '[%s] NOTICE: datadog agent host DD_AGENT_HOST: "%s"\n' "$(date "+%d-%b-%Y %R:%S")" "${DD_AGENT_HOST:?}"

## HK: setup /usr/local/bin/php for PHP docker exec default environment
mv -n /usr/local/bin/php /usr/local/bin/php-cli.bin # <1>
<<STUB cat > /usr/local/bin/php
#!/bin/bash
export DD_AGENT_HOST="${DD_AGENT_HOST:?}" # <2>
exec -a "\$0" /usr/local/bin/php-cli.bin "\$@" # <3>
STUB
chmod --reference=/usr/local/bin/php-cli.bin /usr/local/bin/php

## HK: *exec* php-fpm; cf. /usr/local/bin/docker-php-entrypoint (previous)
exec php-fpm -F
EOF
# <1> this is replaced
# <2> error on empty or unset
# <3> exec -a is bash, not sh

ENTRYPOINT ["app-docker-php-entrypoint"]
DOCKER

container_id=$(docker run -d --rm --name="${BUILD_CONTAINER:?}" "${BUILD_CONTAINER:?}")
printf '%s: container-id: %.12s %s\n' "$0" "$container_id" "$container_id"

{ # expecting three lines, otherwise exit after 2 seconds
  expected_lines=3
  timeout_seconds=2
  coproc log { docker logs -f "${BUILD_CONTAINER:?}" 2>&1 & sleep "$timeout_seconds"; kill $!; }
  line=0; while test "$((line++))" -lt "$expected_lines" && read -r -u "${log[0]}" v; do
    printf '%s: %s\n' "$0" "$v"
  done
  kill "${log_PID:?monitoring timed out after ${timeout_seconds}s for ${expected_lines}l.}"
}

if ! entrypoint="$(docker exec "$BUILD_CONTAINER" /bin/sh -c 'command -v "'"$(docker inspect -f '{{.Config.Entrypoint}}' "$BUILD_CONTAINER" | tr -d '[]' )"'"')"; then
  printf '%s: ERROR: obtaining the entrypoint failed: %d\n' "$0" "$?"
fi

printf '%s: done build "%s" (id: %.12s); entrypoint: %s\n' "$0" "$BUILD_CONTAINER" "$container_id" "$entrypoint"
