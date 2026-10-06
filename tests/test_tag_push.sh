. "$(dirname "$0")/lib.sh"

new_repo
run_cv tag-push 2.5.0-rc.1
assert_eq "pushed=2.5.0-rc.1" "$OUT" "tag-push: salida"
assert_eq tag "$(git -C "$T/origin.git" cat-file -t 2.5.0-rc.1)" "tag-push: el remoto tiene un tag anotado"
assert_eq "2.5.0-rc.1" "$(git tag -l --format='%(contents)' 2.5.0-rc.1)" "tag-push: el mensaje es el nombre del tag"
assert_eq "Dev Test" "$(git for-each-ref refs/tags/2.5.0-rc.1 --format='%(taggername)')" "tag-push: el tagger es el dev"
assert_eq 0 "$(git cat-file -p 2.5.0-rc.1 | grep -ciE 'co-authored|claude|cephal')" "tag-push: sin menciones al agente ni a cephal"

# commit de release local: se empuja junto con el tag
echo 1 > release.txt
commit_all "Release app 1.0.0"
run_cv tag-push 1.0.0
assert_eq "pushed=1.0.0" "$OUT" "tag-push con commit adelantado: salida"
assert_eq "$(git rev-parse HEAD)" "$(git -C "$T/origin.git" rev-parse develop)" "tag-push: el commit adelantado llega al remoto"
assert_eq tag "$(git -C "$T/origin.git" cat-file -t 1.0.0)" "tag-push: el tag llega al remoto"

# tag duplicado
run_cv tag-push 1.0.0
assert_eq 1 "$RC" "tag duplicado falla"
assert_contains "$ERRO" "ya existe" "tag duplicado: mensaje"

# formato inválido
run_cv tag-push v1.0
assert_eq 1 "$RC" "formato inválido falla"
assert_contains "$ERRO" "formato de tag inválido" "formato inválido: mensaje"

# árbol sucio
echo x >> README.md
run_cv tag-push 1.0.1
assert_eq 1 "$RC" "árbol sucio falla"
assert_contains "$ERRO" "cambios sin commitear" "árbol sucio: mensaje"
git checkout -q -- README.md

# HEAD desacoplado
git checkout -q --detach
run_cv tag-push 1.0.1
assert_eq 1 "$RC" "HEAD desacoplado falla"
git checkout -q develop

# el remoto rechaza: no queda el tag local
printf '#!/bin/sh\nexit 1\n' > "$T/origin.git/hooks/pre-receive"
chmod +x "$T/origin.git/hooks/pre-receive"
run_cv tag-push 9.9.9
assert_eq 1 "$RC" "push rechazado falla"
assert_eq "" "$(git tag --list 9.9.9)" "push rechazado: no queda el tag local"
rm -f "$T/origin.git/hooks/pre-receive"

finish
