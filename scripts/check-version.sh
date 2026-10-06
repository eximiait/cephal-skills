#!/bin/sh
# Verifica que el tag vX.Y.Z coincida con todas las versiones de plugin.json y marketplace.json.
ROOT=${CEPHAL_SKILLS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
[ $# -eq 1 ] || { echo "uso: check-version.sh vX.Y.Z" >&2; exit 2; }
want=${1#v}
bad=0
for f in plugin.json marketplace.json; do
  for v in $(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$ROOT/.claude-plugin/$f"); do
    if [ "$v" != "$want" ]; then
      echo "$f: $v no coincide con $1"
      bad=1
    fi
  done
done
exit "$bad"
