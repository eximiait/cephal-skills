. "$(dirname "$0")/lib.sh"

chart() { # $1 = contenido de chart/Chart.yaml (sin salto final agregado por printf)
  mkdir -p chart; printf '%s\n' "$1" > chart/Chart.yaml
}
vline() { grep '^version' chart/Chart.yaml; }

# sin Chart.yaml
new_repo
run_cv chart-prep
assert_eq "chart=skipped" "$OUT" "sin Chart.yaml: skipped"

# versión ya liberable
new_repo
chart 'name: demo
version: 2.5.0'
commit_all "chart"; git push -q; git tag 2.4.0
run_cv chart-prep
assert_eq "version=2.5.0
changed=no" "$OUT" "versión liberable: changed=no"

# igual al último final, con RC abierto: toma la base del RC
new_repo
chart 'name: demo
version: 2.4.0'
commit_all "chart"; git push -q; git tag 2.4.0; git tag 2.5.0-rc.1
run_cv chart-prep
assert_eq "version=2.5.0
changed=yes" "$OUT" "RC abierto: base del RC"
assert_eq "version: 2.4.0" "$(vline)" "sin --apply no modifica"

# por tipo, sin RC
new_repo
chart 'name: demo
version: 2.4.0'
commit_all "chart"; git push -q; git tag 2.4.0
run_cv chart-prep minor
assert_eq "version=2.5.0
changed=yes" "$OUT" "minor sobre 2.4.0"
run_cv chart-prep
assert_eq 1 "$RC" "sin RC ni tipo: falla"
assert_contains "$ERRO" "falta el tipo" "sin RC ni tipo: mensaje"

# --apply con comillas: escribe y commitea
new_repo
chart 'name: demo
version: "2.4.0"'
commit_all "chart"; git push -q; git tag 2.4.0
run_cv chart-prep --apply minor
assert_contains "$OUT" "committed=yes" "--apply: commitea"
assert_eq 'version: "2.5.0"' "$(vline)" "--apply: conserva comillas"
assert_eq "Chart a 2.5.0" "$(git log -1 --format=%B)" "--apply: mensaje exacto sin trailers"
assert_eq "Dev Test" "$(git log -1 --format=%an)" "--apply: autor es el dev"
BEFORE=$(git rev-list --count HEAD)
run_cv chart-prep --apply
assert_eq "version=2.5.0
changed=no" "$OUT" "--apply con versión ya liberable: changed=no"
assert_eq "$BEFORE" "$(git rev-list --count HEAD)" "--apply con changed=no: no commitea"

# CRLF
new_repo
printf 'name: demo\r\nversion: 1.0.0\r\n' > chart.tmp; mkdir -p chart; mv chart.tmp chart/Chart.yaml
commit_all "chart"; git push -q; git tag 1.0.0
run_cv chart-prep --apply patch
printf 'name: demo\r\nversion: 1.0.1\r\n' > "$T/exp"
assert_eq same "$(cmp -s chart/Chart.yaml "$T/exp" && echo same || echo differ)" "--apply: conserva CRLF"

# sin línea version: la agrega
new_repo
chart 'name: demo'
commit_all "chart"; git push -q
run_cv chart-prep --apply patch
assert_eq "version: 0.0.1" "$(vline)" "--apply: agrega version si falta"

# en main: falla
new_repo
chart 'name: demo
version: 1.0.0'
commit_all "chart"; git push -q; git tag 1.0.0
git checkout -q main; git merge -q --ff-only develop
run_cv chart-prep --apply patch
assert_eq 1 "$RC" "--apply en main: falla"
assert_contains "$ERRO" "no se commitea" "--apply en main: mensaje"
git checkout -q develop

# árbol sucio: falla
echo x >> README.md
run_cv chart-prep --apply patch
assert_eq 1 "$RC" "--apply con árbol sucio: falla"
assert_contains "$ERRO" "cambios sin commitear" "--apply con árbol sucio: mensaje"
git checkout -q -- README.md

# HELM_BASEDIR propio
new_repo
add_file .gitlab-ci.yml 'variables:
  HELM_BASEDIR: helm'
mkdir -p helm; printf 'name: demo\nversion: 3.0.0\n' > helm/Chart.yaml
commit_all "helm"; git push -q; git tag 2.9.0
run_cv chart-prep
assert_eq "version=3.0.0
changed=no" "$OUT" "HELM_BASEDIR=helm: usa helm/Chart.yaml"

# prefijo v: no liberable
new_repo
chart 'name: demo
version: v2.5.0'
commit_all "chart"; git push -q; git tag 2.4.0
run_cv chart-prep patch
assert_eq "version=2.4.1
changed=yes" "$OUT" "version v2.5.0: no liberable, calcula otra"

# tag que existe solo en el remoto: no liberable
new_repo
chart 'name: demo
version: 2.5.0'
commit_all "chart"; git push -q; git tag 2.4.0
git clone -q "$T/origin.git" "$T/other"
(cd "$T/other" && git tag 2.5.0 && git push -q origin 2.5.0)
run_cv chart-prep patch
assert_eq "version=2.4.1
changed=yes" "$OUT" "tag solo en el remoto: no liberable"

# comentario en la línea version: se conserva
new_repo
chart "name: demo
version: '1.0.0' # chart"
commit_all "chart"; git push -q; git tag 1.0.0
run_cv chart-prep --apply patch
assert_eq "version: '1.0.1' # chart" "$(vline)" "--apply: conserva comillas y comentario"

# CRLF sin salto final, version en la última línea: sin \r suelto al final
new_repo
mkdir -p chart; printf 'name: demo\r\nversion: 1.0.0' > chart/Chart.yaml
commit_all "chart"; git push -q; git tag 1.0.0
run_cv chart-prep --apply patch
printf 'name: demo\r\nversion: 1.0.1' > "$T/exp"
assert_eq same "$(cmp -s chart/Chart.yaml "$T/exp" && echo same || echo differ)" "--apply: CRLF sin salto final, sin \r suelto"

# origin inaccesible: no se asume que el tag no existe
new_repo
chart 'name: demo
version: 2.5.0'
commit_all "chart"; git push -q; git tag 2.4.0
git remote set-url origin "$T/no-existe.git"
run_cv chart-prep
assert_eq 1 "$RC" "origin inaccesible: falla"
assert_contains "$ERRO" "no se pudo consultar los tags de origin" "origin inaccesible: mensaje"


# --write: escribe sin commitear (lo usa bump-app-version tras un release)
new_repo
chart 'name: demo
version: "1.0.0"
appVersion: "0.1.0"'
commit_all "chart"; git push -q; git tag 1.0.0
BEFORE=$(git rev-list --count HEAD)
run_cv chart-prep --write
assert_eq 1 "$RC" "--write sin tipo ni RC: falla"
assert_contains "$ERRO" "falta el tipo" "--write sin tipo: mensaje"
assert_eq "" "$(git status --porcelain)" "--write que falla no modifica nada"
run_cv chart-prep --write minor
assert_eq "version=1.1.0
changed=yes" "$OUT" "--write: calcula sobre el último final"
assert_eq 'version: "1.1.0"' "$(vline)" "--write: conserva comillas"
assert_eq "$BEFORE" "$(git rev-list --count HEAD)" "--write: no commitea"
assert_eq " M chart/Chart.yaml" "$(git status --porcelain)" "--write: deja el cambio sin commitear"
assert_eq "" "$(printf '%s\n' "$OUT" | grep 'diff --git')" "--write: no muestra diff (la muestra el bump)"
run_cv chart-prep --write
assert_eq "version=1.1.0
changed=no" "$OUT" "--write con la versión ya liberable: changed=no"
git checkout -q -- chart/Chart.yaml

# --write con RC abierto: toma la base del RC sin preguntar
git tag 1.1.0-rc.1
run_cv chart-prep --write
assert_eq "version=1.1.0
changed=yes" "$OUT" "--write con RC abierto: base del RC"
git checkout -q -- chart/Chart.yaml

# --write no se hace en la rama principal
git branch -q -f main develop; git checkout -q main
run_cv chart-prep --write minor
assert_eq 1 "$RC" "--write en main falla"
assert_contains "$ERRO" "en main no se commitea" "--write en main: mensaje"
assert_eq "" "$(git status --porcelain)" "--write en main: no modifica"

# flujo completo del dev: chart-prep --write y después bump
new_repo
add_file pom.xml '<project>
  <artifactId>demo</artifactId>
  <version>0.1.0</version>
</project>'
chart 'name: demo
version: 1.0.0
appVersion: "0.1.0"'
commit_all "release"; git push -q; git tag 1.0.0
run_cv chart-prep --write minor
run_cv bump minor
assert_eq "from=0.1.0
to=0.2.0" "$(printf '%s\n' "$OUT" | grep -E '^[a-z_]+=')" "bump tras --write: salida"
assert_eq "version: 1.1.0
appVersion: \"0.2.0\"" "$(grep -E '^(version|appVersion)' chart/Chart.yaml)" "bump tras --write: chart 1.1.0 y appVersion 0.2.0"
assert_eq " M chart/Chart.yaml
 M pom.xml" "$(git status --porcelain)" "bump tras --write: cambios sin commitear"
assert_contains "$OUT" "+version: 1.1.0" "bump tras --write: la diff incluye la versión del chart"

finish
