#!/bin/sh
# Copia scripts/cephal-version y scripts/cephal-version.ps1 a skills/*/scripts/.
# Con --check no copia: sale 1 si alguna copia difiere de la canónica.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
check=no
[ "${1:-}" = "--check" ] && check=yes
bad=0
for dir in "$ROOT"/skills/*/; do
  for f in cephal-version cephal-version.ps1; do
    dest="${dir}scripts/$f"
    if [ "$check" = yes ]; then
      if ! cmp -s "$ROOT/scripts/$f" "$dest"; then
        echo "desincronizado: ${dest#"$ROOT"/}"
        bad=1
      fi
    else
      mkdir -p "${dir}scripts"
      cp "$ROOT/scripts/$f" "$dest"
    fi
  done
done
[ "$bad" -eq 0 ]
