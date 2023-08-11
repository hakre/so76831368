#!/bin/bash
# Dockerfile build test script
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

test_total=5
test_name="${BUILD_CONTAINER:?}"

printf '%s: initializing and running %d test/s in "%s"...\n' "$0" "$test_total" "$test_name"

test_err() {
  : "${test_errors:=0}"
  ((++test_errors))
  local banner="[$test_number/$test_total]"
  printf '%s failure #%d: exit status: %d\n' "$banner" "$test_errors" "$2"
  awk 'NR>L-4 && NR<L+4 { printf "      %-5d%3s%s\n",NR,(NR==L?">>>":""),$0 }' L=$1 $0
}
trap 'test_err $LINENO $?' ERR

test_it() { : "${test_number:=0}"; ((++test_number)); printf '\n[%d/%d] %s\n' "$test_number" "$test_total" "${1:?test description}";
test_sed=(sed "s~^~  [$test_number] ~")
}

test_flt() { "${test_sed[@]}"; }

test_exit() {
  if [ "$test_number" -ne "$test_total" ]; then
    printf >&2 'test case error: total number different: %d\n' "$test_number"
    exit 42
  fi

  if [ "${test_errors:=0}" -gt 0 ]; then
    printf >&2 '%s: %d error/s.\n' "$0" "$test_errors"
    exit 1
  fi
}


test_it 'php -i (non-interactive)'; {
  (set -x; docker exec "$test_name" php -i;)
} | test_flt | grep 'DD_AGENT_HOST'

test_it 'php -i (non-interactive, within PHP itself)'; {
  (set -x; docker exec "$test_name" php -r 'passthru("php -i");';)
} | test_flt | grep 'DD_AGENT_HOST'

test_it '/bin/sh (non-interactive)'; {
  (set -x; docker exec "$test_name" /bin/sh -c 'php -i';)
} | test_flt | grep 'DD_AGENT_HOST'

test_it '/bin/sh (interactive; no tty)'; {
  (set -x; docker exec "$test_name" /bin/sh -ic 'php -i';)
} | test_flt | grep 'DD_AGENT_HOST'

test_it '/bin/sh (interactive)'; {
  (set -x; docker exec -t "$test_name" /bin/sh -ic 'php -i';)
} | test_flt | grep 'DD_AGENT_HOST'


skip_them() { # bash is informative only
  test_it '/bin/bash (interactive; no tty)'; {
    (set -x; docker exec "$test_name" /bin/bash -ic 'php -i';)
  } | test_flt | grep 'DD_AGENT_HOST'

  test_it '/bin/bash (interactive)'; {
    (set -x; docker exec -t "$test_name" /bin/bash -ic 'php -i';)
  } | test_flt | grep 'DD_AGENT_HOST'

  test_it '/bin/bash (non-interactive)'; {
    (set -x; docker exec -t "$test_name" /bin/bash -c 'php -i';)
  } | test_flt | grep 'DD_AGENT_HOST' || test_err "$LINENO" "$?"
}

test_exit
