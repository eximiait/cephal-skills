. "$(dirname "$0")/lib.sh"

setup() {
  new_repo
  add_file pom.xml '<project>
  <artifactId>demo</artifactId>
  <version>1.3.1-SNAPSHOT</version>
</project>'
  add_file chart/Chart.yaml 'name: demo
appVersion: "1.3.1-SNAPSHOT"'
  commit_all "base"
  git push -q
}
appv() { grep '^appVersion' chart/Chart.yaml; }
kvonly() { printf '%s\n' "$OUT" | grep -E '^[a-z_]+='; }

# bump patch
setup
BEFORE=$(git rev-list --count HEAD)
run_cv bump patch
assert_eq "from=1.3.1-SNAPSHOT
to=1.3.2-SNAPSHOT" "$(kvonly)" "bump patch: salida"
assert_eq 'appVersion: "1.3.2-SNAPSHOT"' "$(appv)" "bump: alinea appVersion"
assert_eq 1 "$(grep -c '<version>1.3.2-SNAPSHOT</version>' pom.xml)" "bump: edita el pom"
assert_eq " M chart/Chart.yaml
 M pom.xml" "$(git status --porcelain)" "bump: deja los cambios sin commitear"
assert_eq "$BEFORE" "$(git rev-list --count HEAD)" "bump: no crea commits"

# versión explícita
setup
run_cv bump 3.0.0
assert_eq "from=1.3.1-SNAPSHOT
to=3.0.0" "$(kvonly)" "bump explícito"
run_cv bump huge
assert_eq 1 "$RC" "bump con tipo inválido falla"

# fuera de la rama de desarrollo
setup
git checkout -q -b feature/x
run_cv bump patch
assert_eq 1 "$RC" "bump en feature/x falla"
assert_contains "$ERRO" "estás en feature/x; el bump se hace en develop" "bump fuera de develop: mensaje"
assert_eq "" "$(git status --porcelain)" "bump fuera de develop: no modifica archivos"

# DEVELOP_BRANCH configurado
setup
add_file .gitlab-ci.yml 'variables:
  DEVELOP_BRANCH: "main"'
commit_all "ci"
git push -q
run_cv bump patch
assert_eq 1 "$RC" "con DEVELOP_BRANCH=main, bump en develop falla"
git checkout -q -B main
run_cv bump patch
assert_eq 0 "$RC" "con DEVELOP_BRANCH=main, bump en main funciona"

# versión que ya fue tag: su imagen existe (modelo anterior: la imagen llevaba el tag del chart)
old_pom() {
  setup
  sed -i 's#1.3.1-SNAPSHOT#1.0.0#' pom.xml
  sed -i 's#1.3.1-SNAPSHOT#1.0.0#' chart/Chart.yaml
  commit_all "pom atrasado"; git push -q
}
old_pom
git tag 1.1.0; git tag 1.4.14; git push -q --tags
run_cv bump minor
assert_eq 1 "$RC" "bump a una versión ya tag: falla"
assert_contains "$ERRO" "la versión 1.1.0 ya fue tag (1.1.0)" "bump a una versión ya tag: mensaje"
assert_contains "$ERRO" "por ejemplo 1.4.15" "bump a una versión ya tag: sugiere la siguiente al mayor tag"
assert_eq "" "$(git status --porcelain)" "bump a una versión ya tag: no modifica archivos"
run_cv bump 1.4.15
assert_eq "from=1.0.0
to=1.4.15" "$(kvonly)" "bump explícito a una versión libre"

# solo existe un RC de esa base
old_pom
git tag 1.1.0-rc.2; git push -q --tags
run_cv bump minor
assert_eq 1 "$RC" "bump a una versión con RC: falla"
assert_contains "$ERRO" "ya fue tag (1.1.0-rc.2)" "bump a una versión con RC: mensaje"

# el tag solo está en origin (otro dev lo creó): el bump hace fetch antes de validar
old_pom
git clone -q "$T/origin.git" "$T/otro"
git -C "$T/otro" tag 1.1.0
git -C "$T/otro" push -q origin 1.1.0
assert_eq "" "$(git tag --list 1.1.0)" "tag remoto: la copia local no lo tiene"
run_cv bump minor
assert_eq 1 "$RC" "tag solo en origin: el bump lo detecta"
assert_contains "$ERRO" "la versión 1.1.0 ya fue tag" "tag solo en origin: mensaje"

# SNAPSHOT: se valida la base sin el sufijo
setup
sed -i 's#1.3.1-SNAPSHOT#1.0.0-SNAPSHOT#' pom.xml
commit_all "pom"; git push -q
git tag 1.1.0; git push -q --tags
run_cv bump minor
assert_eq 1 "$RC" "bump a x.y.z-SNAPSHOT con tag x.y.z: falla"

# otro tag que solo se parece (11.1.0, 1.1.00) no cuenta
old_pom
git tag 11.1.0; git push -q --tags
run_cv bump minor
assert_eq "from=1.0.0
to=1.1.0" "$(kvonly)" "tag 11.1.0 no bloquea la 1.1.0"

# sin poder consultar origin no se asume que la versión está libre
old_pom
git remote set-url origin "$T/no-existe.git"
run_cv bump minor
assert_eq 1 "$RC" "origin inaccesible: falla"
assert_contains "$ERRO" "no se pudo consultar origin" "origin inaccesible: mensaje"
assert_eq "" "$(git status --porcelain)" "origin inaccesible: no modifica archivos"

# release-prep
setup
run_cv release-prep
assert_eq "snapshot=yes
release=1.3.1" "$OUT" "release-prep sin --apply: solo informa"
assert_eq "" "$(git status --porcelain)" "release-prep sin --apply: no modifica nada"

run_cv release-prep --apply
assert_contains "$OUT" "committed=yes" "release-prep --apply: informa el commit"
assert_eq "Release app 1.3.1" "$(git log -1 --format=%B)" "release-prep: mensaje exacto sin cuerpo ni trailers"
assert_eq "Dev Test" "$(git log -1 --format=%an)" "release-prep: autor es el dev"
assert_eq 1 "$(grep -c '<version>1.3.1</version>' pom.xml)" "release-prep: quita -SNAPSHOT del pom"
assert_eq 'appVersion: "1.3.1"' "$(appv)" "release-prep: alinea appVersion"

run_cv release-prep --apply
assert_eq "snapshot=no" "$OUT" "release-prep sin SNAPSHOT: nada que hacer"

# --apply con cambios ajenos sin commitear: no los arrastra al commit de release
setup
echo x >> README.md
run_cv release-prep --apply
assert_eq 1 "$RC" "release-prep --apply con árbol sucio falla"
assert_contains "$ERRO" "cambios sin commitear" "release-prep --apply con árbol sucio: mensaje"
assert_eq "base" "$(git log -1 --format=%s)" "release-prep --apply con árbol sucio: no commitea"
assert_eq 1 "$(grep -c '<version>1.3.1-SNAPSHOT</version>' pom.xml)" "release-prep --apply con árbol sucio: no edita el pom"

finish
