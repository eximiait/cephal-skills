. "$(dirname "$0")/lib.sh"

new_repo
add_file app.txt "feature"
commit_all "feature"
git push -q

# develop tiene un commit que main no tiene
run_cv release-target
assert_eq 1 "$RC" "sin integrar: falla"
assert_contains "$ERRO" "main no contiene develop: falta integrar el MR" "sin integrar: mensaje"
assert_eq develop "$(git symbolic-ref --short HEAD)" "sin integrar: no cambia de rama"

# el MR se mergea en GitLab (otro clon)
git clone -q "$T/origin.git" "$T/other"
(
  cd "$T/other" || exit 1
  git config user.name "Other"
  git config user.email "other@test"
  git config commit.gpgsign false
  git checkout -q main
  git merge -q --no-ff -m "Merge develop" origin/develop
  git push -q origin main
) || exit 1

# cambios sin commitear
printf 'cambio\n' >> README.md
run_cv release-target
assert_eq 1 "$RC" "archivo modificado: falla"
assert_contains "$ERRO" "hay cambios sin commitear" "archivo modificado: mensaje"
git checkout -q -- README.md

# integrado: pasa a main, la actualiza con origin/main y, como la rama local no tiene upstream, se lo configura
git branch -q --unset-upstream main
run_cv release-target
assert_eq 0 "$RC" "integrado: ok"
git fetch -q origin
HEADSHA=$(git rev-parse --short origin/main)
assert_eq "upstream=origin/main
branch=main
head=$HEADSHA" "$OUT" "integrado: salida"
assert_eq main "$(git symbolic-ref --short HEAD)" "integrado: checkout en main"
assert_eq "$(git rev-parse origin/main)" "$(git rev-parse HEAD)" "integrado: HEAD igual a origin/main"

# con tag final en HEAD
git tag 0.9.0
git tag 1.0.0
git tag 1.0.0-rc.1
run_cv release-target
assert_eq "branch=main
head=$HEADSHA
tagged=1.0.0" "$OUT" "tag final: se informa el mayor"

# commit local sin pushear en main
add_file local.txt "local"
commit_all "local"
run_cv release-target
assert_eq 1 "$RC" "commit local: falla"
assert_contains "$ERRO" "commits locales" "commit local: mensaje"
assert_contains "$ERRO" "el checkout quedó en main" "commit local: avisa dónde quedó el checkout"

# main local divergida de origin/main: falla sin descartar el commit local
LOCAL=$(git rev-parse HEAD)
(
  cd "$T/other" || exit 1
  git commit -q --allow-empty -m "otro merge en GitLab"
  git push -q origin main
) || exit 1
run_cv release-target
assert_eq 1 "$RC" "main divergida: falla"
assert_contains "$ERRO" "no se pudo actualizar main" "main divergida: mensaje"
assert_contains "$ERRO" "el checkout quedó en main" "main divergida: avisa dónde quedó el checkout"
assert_eq "$LOCAL" "$(git rev-parse HEAD)" "main divergida: conserva el commit local"
assert_eq main "$(git symbolic-ref --short HEAD)" "main divergida: sigue en main"

# main solo existe en origin: se crea la rama local
git reset -q --hard origin/main
git checkout -q develop
git branch -q -D main
run_cv release-target
assert_eq 0 "$RC" "sin main local: ok"
assert_eq main "$(git symbolic-ref --short HEAD)" "sin main local: checkout en main"
assert_eq "origin/main" "$(git rev-parse --abbrev-ref 'main@{u}')" "sin main local: rastrea origin/main"

# main local sin upstream (creada a mano): release-target le configura origin/main
git checkout -q develop
git branch -q --unset-upstream main
run_cv release-target
assert_eq 0 "$RC" "main sin upstream: ok"
assert_contains "$OUT" "upstream=origin/main" "main sin upstream: informa el upstream configurado"
assert_eq "origin/main" "$(git rev-parse --abbrev-ref 'main@{u}')" "main sin upstream: queda rastreando origin/main"

# ramas configuradas que no existen en origin: no se confunde con "falta integrar el MR"
git checkout -q develop
add_file .gitlab-ci.yml 'variables:
  DEVELOP_BRANCH: desarrollo'
run_cv release-target
assert_eq 1 "$RC" "origin/desarrollo inexistente: falla"
assert_contains "$ERRO" "no existe origin/desarrollo; revisá DEVELOP_BRANCH/MAIN_BRANCH" "origin/desarrollo inexistente: mensaje"
assert_eq develop "$(git symbolic-ref --short HEAD)" "origin/desarrollo inexistente: no cambia de rama"
add_file .gitlab-ci.yml 'variables:
  MAIN_BRANCH: produccion'
run_cv release-target
assert_eq 1 "$RC" "origin/produccion inexistente: falla"
assert_contains "$ERRO" "no existe origin/produccion; revisá DEVELOP_BRANCH/MAIN_BRANCH" "origin/produccion inexistente: mensaje"
rm -f .gitlab-ci.yml

finish
