#!/bin/sh
# Ejecuta todas las pruebas tests/test_*.sh con sh; sale 1 si alguna falla.
DIR=$(cd "$(dirname "$0")" && pwd)
bad=0
for t in "$DIR"/test_*.sh; do
  sh "$t" || bad=$((bad + 1))
done
if [ "$bad" -eq 0 ]; then echo "OK"; else echo "FALLAN $bad archivos"; exit 1; fi
