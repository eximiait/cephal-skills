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

# integrado: pasa a main y la actualiza
run_cv release-target
assert_eq 0 "$RC" "integrado: ok"
git fetch -q origin
HEADSHA=$(git rev-parse --short origin/main)
assert_eq "branch=main
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

# main solo existe en origin: se crea la rama local
git reset -q --hard origin/main
git checkout -q develop
git branch -q -D main
run_cv release-target
assert_eq 0 "$RC" "sin main local: ok"
assert_eq main "$(git symbolic-ref --short HEAD)" "sin main local: checkout en main"
assert_eq "origin/main" "$(git rev-parse --abbrev-ref 'main@{u}')" "sin main local: rastrea origin/main"

finish
