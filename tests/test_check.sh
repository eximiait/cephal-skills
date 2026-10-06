. "$(dirname "$0")/lib.sh"

new_repo
add_file pom.xml '<project>
  <artifactId>demo</artifactId>
  <version>1.3.1-SNAPSHOT</version>
</project>'
commit_all "pom"
git push -q
git tag 2.4.0

# context
run_cv context
assert_eq "branch=develop
develop_branch=develop
main_branch=main
lang=maven
version=1.3.1-SNAPSHOT
chart_dir=chart
last_final=2.4.0
open_rc=none" "$OUT" "context: valores"

git tag 2.5.0-rc.1
run_cv context
assert_contains "$OUT" "open_rc=2.5.0" "context: RC abierto"

mkdir sub
(cd sub && ERRF=$(mktemp) && OUT=$(sh "$CV" context 2>"$ERRF"); case "$OUT" in *"lang=maven"*) echo ok > "$T/sub.ok" ;; esac)
assert_eq ok "$(cat "$T/sub.ok" 2>/dev/null)" "context: funciona desde un subdirectorio"
rmdir sub

# check ok
run_cv check
assert_eq "check=ok" "$OUT" "check: repo limpio y sincronizado"
assert_eq 0 "$RC" "check ok: código de salida"

# archivo modificado sin commitear
echo x >> README.md
run_cv check
assert_eq 1 "$RC" "check: árbol sucio falla"
assert_contains "$ERRO" "cambios sin commitear" "check: árbol sucio, mensaje"
git checkout -q -- README.md

# commit local sin pushear
add_file extra.txt 1; commit_all "local"
run_cv check
assert_eq 1 "$RC" "check: commit sin pushear falla"
assert_contains "$ERRO" "adelante 1" "check: commit sin pushear, mensaje"
git reset -q --hard origin/develop

# rama detrás de origin: otro clon pushea un commit
git clone -q "$T/origin.git" "$T/other"
(cd "$T/other" && git config user.name "Otro" && git config user.email "otro@test" && echo 1 > otro.txt && git add -A && git commit -q -m "otro" && git push -q)
run_cv check
assert_eq 1 "$RC" "check: rama detrás de origin falla"
assert_contains "$ERRO" "atrás 1" "check: rama detrás de origin, mensaje"
git pull -q --ff-only

# HEAD desacoplado
git checkout -q --detach
run_cv check
assert_eq 1 "$RC" "check: HEAD desacoplado falla"
assert_contains "$ERRO" "HEAD desacoplado" "check: HEAD desacoplado, mensaje"
git checkout -q develop

# sin upstream
git checkout -q -b local-only
run_cv check
assert_eq 1 "$RC" "check: rama sin upstream falla"
assert_contains "$ERRO" "no tiene upstream" "check: sin upstream, mensaje"
git checkout -q develop

# upstream distinto de origin/<misma rama>: tag-push empujaría a otra rama
git checkout -q -b feature/x --track origin/develop
run_cv check
assert_eq 1 "$RC" "check: upstream distinto de origin/<rama> falla"
assert_contains "$ERRO" "rastrea origin/develop" "check: upstream distinto, mensaje"
git checkout -q develop

# identidad ausente
git config user.email ""
run_cv check
assert_eq 1 "$RC" "check: sin identidad git falla"
assert_contains "$ERRO" "identidad git" "check: sin identidad, mensaje"
git config user.email "dev@test"

# fuera de un repo
cd "$(mktemp -d)" || exit 1
run_cv context
assert_eq 1 "$RC" "fuera de un repo: falla"
assert_contains "$ERRO" "no es un repositorio git" "fuera de un repo: mensaje"

finish
