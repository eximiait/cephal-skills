. "$(dirname "$0")/lib.sh"
new_repo

run_cv nope
assert_eq 1 "$RC" "subcomando desconocido: código de salida"
assert_contains "$ERRO" "ERR:" "subcomando desconocido: mensaje"

run_cv
assert_eq 1 "$RC" "sin argumentos: código de salida"
assert_contains "$ERRO" "ERR:" "sin argumentos: mensaje"

finish
