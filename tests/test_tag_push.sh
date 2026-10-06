. "$(dirname "$0")/lib.sh"

new_repo
run_cv tag-push 2.5.0-rc.1
assert_eq "pushed=2.5.0-rc.1" "$OUT" "tag-push: salida"
assert_eq tag "$(git -C "$T/origin.git" cat-file -t 2.5.0-rc.1)" "tag-push: el remoto tiene un tag anotado"
assert_eq "2.5.0-rc.1" "$(git tag -l --format='%(contents)' 2.5.0-rc.1)" "tag-push: el mensaje es el nombre del tag"
assert_eq "Dev Test" "$(git for-each-ref refs/tags/2.5.0-rc.1 --format='%(taggername)')" "tag-push: el tagger es el dev"
assert_eq 0 "$(git cat-file -p 2.5.0-rc.1 | grep -ciE 'co-authored|claude|cephal')" "tag-push: sin menciones al agente ni a cephal"

# RC con commit de release local: se empuja junto con el tag
git checkout -q -b feature/rc
git push -q -u origin feature/rc
echo 1 > release.txt
commit_all "Release app 2.6.0"
run_cv tag-push 2.6.0-rc.1
assert_eq "pushed=2.6.0-rc.1" "$OUT" "tag-push RC con commit adelantado: salida"
assert_eq "$(git rev-parse HEAD)" "$(git -C "$T/origin.git" rev-parse feature/rc)" "tag-push RC: el commit adelantado llega al remoto"

# tag final: main local con un commit que no pasó por MR no se empuja
git checkout -q main
ORIG_MAIN=$(git -C "$T/origin.git" rev-parse main)
echo 1 > local.txt
commit_all "commit local en main"
run_cv tag-push 1.0.0
assert_eq 1 "$RC" "tag final con main adelantada falla"
assert_contains "$ERRO" "main tiene commits sin integrar por MR" "tag final con main adelantada: mensaje"
assert_eq "$ORIG_MAIN" "$(git -C "$T/origin.git" rev-parse main)" "tag final con main adelantada: origin/main no cambia"
assert_eq "" "$(git tag --list 1.0.0)" "tag final con main adelantada: no crea el tag"
git reset -q --hard origin/main

# tag final: main local atrasada respecto de origin
git clone -q "$T/origin.git" "$T/other"
git -C "$T/other" checkout -q main
git -C "$T/other" -c user.name=O -c user.email=o@t commit -q --allow-empty -m "merge en GitLab"
git -C "$T/other" push -q origin main
run_cv tag-push 1.0.0
assert_eq 1 "$RC" "tag final con main atrasada falla"
assert_contains "$ERRO" "main no coincide con origin/main" "tag final con main atrasada: mensaje"
assert_eq "" "$(git tag --list 1.0.0)" "tag final con main atrasada: no crea el tag"
git merge -q --ff-only origin/main

# tag final con main igual a origin/main
run_cv tag-push 1.0.0
assert_eq "pushed=1.0.0" "$OUT" "tag final: salida"
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
git checkout -q main

# el remoto rechaza: no queda el tag local
printf '#!/bin/sh\nexit 1\n' > "$T/origin.git/hooks/pre-receive"
chmod +x "$T/origin.git/hooks/pre-receive"
run_cv tag-push 9.9.9
assert_eq 1 "$RC" "push rechazado falla"
assert_eq "" "$(git tag --list 9.9.9)" "push rechazado: no queda el tag local"
rm -f "$T/origin.git/hooks/pre-receive"

# upstream distinto de origin/<misma rama>: no se crea una rama remota nueva
git checkout -q develop
git checkout -q -b feature/y --track origin/develop
run_cv tag-push 7.7.7-rc.1
assert_eq 1 "$RC" "upstream distinto de origin/<rama> falla"
assert_contains "$ERRO" "rastrea origin/develop" "upstream distinto: mensaje"
assert_eq "" "$(git -C "$T/origin.git" branch --list feature/y)" "upstream distinto: no crea la rama remota"
assert_eq "" "$(git tag --list 7.7.7-rc.1)" "upstream distinto: no deja tag local"
git checkout -q main

finish
