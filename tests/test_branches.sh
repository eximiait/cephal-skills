. "$(dirname "$0")/lib.sh"

new_repo
run_cv next-tag prod patch
assert_eq 1 "$RC" "next-tag prod en develop falla"
assert_contains "$ERRO" "deploy a prod solo desde main; estás en develop" "next-tag prod en develop: mensaje"

run_cv tag-push 1.0.0
assert_eq 1 "$RC" "tag-push final en develop falla"
assert_contains "$ERRO" "deploy a prod solo desde main; estás en develop" "tag-push final en develop: mensaje"
assert_eq "" "$(git tag --list 1.0.0)" "tag-push final en develop: no crea el tag"

git checkout -q main
run_cv next-tag prod patch
assert_eq "tag=0.0.1" "$(printf '%s\n' "$OUT" | grep -v '^head=')" "next-tag prod en main"
run_cv next-tag test patch
assert_eq 1 "$RC" "next-tag test en main falla"
assert_contains "$ERRO" "un RC no sale de main" "next-tag test en main: mensaje"
run_cv tag-push 1.0.0-rc.1
assert_eq 1 "$RC" "tag-push RC en main falla"
assert_contains "$ERRO" "un RC no sale de main" "tag-push RC en main: mensaje"
add_file pom.xml '<project>
  <version>1.0.0</version>
</project>'
commit_all "pom"
git push -q
run_cv context
assert_contains "$OUT" "main_branch=main" "context informa main_branch"

# push-branch
run_cv push-branch
assert_eq 1 "$RC" "push-branch en main falla"
git checkout -q develop
add_file x.txt 1
commit_all "x"
run_cv push-branch
assert_eq "pushed_branch=develop" "$OUT" "push-branch: salida"
assert_eq "$(git rev-parse HEAD)" "$(git -C "$T/origin.git" rev-parse develop)" "push-branch: el remoto tiene el commit"
git checkout -q --detach
run_cv push-branch
assert_eq 1 "$RC" "push-branch con HEAD desacoplado falla"
git checkout -q develop

# release-prep --apply en main
git checkout -q main
add_file pom.xml '<project>
  <artifactId>demo</artifactId>
  <version>1.0.0-SNAPSHOT</version>
</project>'
commit_all "pom"
before=$(git rev-parse HEAD)
run_cv release-prep --apply
assert_eq 1 "$RC" "release-prep --apply en main falla"
assert_contains "$ERRO" "en main no se commitea: quitá -SNAPSHOT en otra rama y mergealo por MR" "release-prep --apply en main: mensaje"
assert_eq "$before" "$(git rev-parse HEAD)" "release-prep --apply en main: no crea commit"

# MAIN_BRANCH personalizado
new_repo
add_file .gitlab-ci.yml 'variables:
  MAIN_BRANCH: "master"'
commit_all "ci"
git push -q
git checkout -q main
git merge -q --ff-only develop
git push -q
git checkout -q -b master
git push -q -u origin master
run_cv tag-push 1.0.0
assert_eq "pushed=1.0.0" "$OUT" "MAIN_BRANCH=master: prod en master funciona"
git checkout -q main
run_cv tag-push 1.0.1
assert_eq 1 "$RC" "MAIN_BRANCH=master: prod en main falla"
assert_contains "$ERRO" "deploy a prod solo desde master; estás en main" "MAIN_BRANCH=master: mensaje"

# Un tag creado solo en el remoto no se pisa
new_repo
git checkout -q main
git clone -q "$T/origin.git" "$T/otro"
git -C "$T/otro" -c user.name=O -c user.email=o@t tag -a 3.0.0 -m 3.0.0 origin/main
git -C "$T/otro" push -q origin 3.0.0
sha=$(git ls-remote origin refs/tags/3.0.0)
run_cv tag-push 3.0.0
assert_eq 1 "$RC" "tag solo en el remoto: tag-push falla"
assert_contains "$ERRO" "ya existe" "tag solo en el remoto: mensaje"
assert_eq "$sha" "$(git ls-remote origin refs/tags/3.0.0)" "tag solo en el remoto: no se modifica"

finish
