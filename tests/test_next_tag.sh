. "$(dirname "$0")/lib.sh"
nohead() { printf '%s\n' "$OUT" | grep -v '^head='; }

new_repo
run_cv next-tag test patch
assert_eq "tag=0.0.1-rc.1" "$(nohead)" "sin tags, test patch"

git tag 2.4.0
run_cv next-tag test minor
assert_eq "tag=2.5.0-rc.1" "$(nohead)" "final 2.4.0, test minor"
run_cv next-tag test major
assert_eq "tag=3.0.0-rc.1" "$(nohead)" "final 2.4.0, test major"

run_cv next-tag test
assert_eq 1 "$RC" "test sin RC ni tipo: falla"
assert_contains "$ERRO" "falta el tipo" "test sin RC ni tipo: mensaje"

run_cv next-tag prod patch
assert_eq "tag=2.4.1" "$(nohead)" "prod patch sin RC"
run_cv next-tag prod
assert_eq 1 "$RC" "prod sin RC ni tipo: falla"

git tag 2.5.0-rc.1
run_cv next-tag test
assert_eq "tag=2.5.0-rc.2" "$(nohead)" "RC abierto: continúa con rc.2 sin tipo"
run_cv next-tag test major
assert_eq "tag=2.5.0-rc.2" "$(nohead)" "RC abierto: el tipo se ignora"

add_file a.txt 1; commit_all "uno"
git tag 2.5.0-rc.2
add_file b.txt 2; commit_all "dos"
add_file c.txt 3; commit_all "tres"
run_cv next-tag prod
assert_eq "tag=2.5.0
rc_open=yes
commits_since_rc=2" "$(nohead)" "prod con RC abierto: cierra la base e informa commits desde el último RC"

assert_contains "$OUT" "head=$(git rev-parse --short HEAD)" "next-tag informa el commit que se va a taguear"

run_cv next-tag nope
assert_eq 1 "$RC" "entorno inválido: falla"

finish
