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

git checkout -q main
run_cv next-tag prod patch
assert_eq "tag=2.4.1" "$(nohead)" "prod patch sin RC"
run_cv next-tag prod
assert_eq 1 "$RC" "prod sin RC ni tipo: falla"
git checkout -q develop

git tag 2.5.0-rc.1
run_cv next-tag test
assert_eq "tag=2.5.0-rc.2" "$(nohead)" "RC abierto: continúa con rc.2 sin tipo"
run_cv next-tag test major
assert_eq "tag=2.5.0-rc.2" "$(nohead)" "RC abierto: el tipo se ignora"

git checkout -q main
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

# ---------- prod con Chart.yaml: el tag es su version ----------
on_main_with_chart() { # $1 = version en chart/Chart.yaml
  new_repo
  git tag 2.4.0
  git checkout -q main
  mkdir -p chart; printf 'name: demo\nversion: %s\n' "$1" > chart/Chart.yaml
  commit_all "chart $1"
}
on_main_with_chart 2.5.0
run_cv next-tag prod
assert_eq "tag=2.5.0" "$(nohead)" "Chart.yaml 2.5.0: tag sin pedir tipo"
run_cv next-tag prod major
assert_eq "tag=2.5.0" "$(nohead)" "Chart.yaml 2.5.0: el tipo se ignora"
git tag 2.5.0
run_cv next-tag prod
assert_eq 1 "$RC" "Chart.yaml ya tagueado: falla"
assert_contains "$ERRO" "ya existe el tag 2.5.0" "Chart.yaml ya tagueado: mensaje"
assert_contains "$ERRO" "chart-prep" "Chart.yaml ya tagueado: indica chart-prep"

on_main_with_chart 2.4.0
run_cv next-tag prod
assert_eq 1 "$RC" "Chart.yaml igual al último final: falla"
assert_contains "$ERRO" "ya existe el tag 2.4.0" "Chart.yaml igual al último final: mensaje"

on_main_with_chart 2.3.5
run_cv next-tag prod
assert_eq 1 "$RC" "Chart.yaml menor que el último final: falla"
assert_contains "$ERRO" "no es mayor que el último final (2.4.0)" "Chart.yaml menor que el último final: mensaje"

on_main_with_chart 0.0.0-SNAPSHOT
run_cv next-tag prod
assert_eq 1 "$RC" "Chart.yaml no x.y.z: falla"
assert_contains "$ERRO" "no es x.y.z" "Chart.yaml no x.y.z: mensaje"

on_main_with_chart 2.5.0
git tag 2.5.0-rc.1
add_file a.txt 1; commit_all "uno"
add_file b.txt 2; commit_all "dos"
run_cv next-tag prod
assert_eq "tag=2.5.0
rc_open=yes
commits_since_rc=2" "$(nohead)" "Chart.yaml con RC abierto de esa base: informa commits desde el RC"

# casos borde de la versión en Chart.yaml
for bad in 1.02.0 v1.2.0 1.2; do
  on_main_with_chart "$bad"
  run_cv next-tag prod
  assert_eq 1 "$RC" "Chart.yaml $bad: falla"
  assert_contains "$ERRO" "no es x.y.z" "Chart.yaml $bad: no es x.y.z"
done

# HELM_BASEDIR propio
new_repo
git tag 2.4.0
git checkout -q main
add_file .gitlab-ci.yml 'variables:
  HELM_BASEDIR: deploy/helm'
mkdir -p deploy/helm chart; printf 'name: demo\nversion: 2.6.0\n' > deploy/helm/Chart.yaml; printf 'name: x\nversion: 9.9.9\n' > chart/Chart.yaml
commit_all "helm"
run_cv next-tag prod
assert_eq "tag=2.6.0" "$(nohead)" "HELM_BASEDIR=deploy/helm: usa ese Chart.yaml"

# tag que existe solo en el remoto
on_main_with_chart 2.5.0
git clone -q "$T/origin.git" "$T/other"
(cd "$T/other" && git tag 2.5.0 && git push -q origin 2.5.0)
run_cv next-tag prod
assert_eq 1 "$RC" "tag solo en el remoto: falla"
assert_contains "$ERRO" "ya existe el tag 2.5.0" "tag solo en el remoto: mensaje"

# un tag remoto con el mismo sufijo (release/2.5.0) no bloquea 2.5.0
on_main_with_chart 2.5.0
rm -rf "$T/other"; git clone -q "$T/origin.git" "$T/other"
(cd "$T/other" && git tag release/2.5.0 && git push -q origin release/2.5.0)
run_cv next-tag prod
assert_eq "tag=2.5.0" "$(nohead)" "release/2.5.0 en el remoto no bloquea 2.5.0"

finish
