. "$(dirname "$0")/lib.sh"
CEPHAL_VERSION_SOURCED=1 . "$CV"
new_repo

reset_files() { rm -f pom.xml build.gradle build.gradle.kts package.json pnpm-lock.yaml .gitlab-ci.yml; LANG_OVERRIDE=""; }

# develop_branch / chart_dir
assert_eq develop "$(develop_branch)" "sin .gitlab-ci.yml: rama de desarrollo por defecto"
assert_eq chart "$(chart_dir)" "sin .gitlab-ci.yml: chart por defecto"

add_file .gitlab-ci.yml 'variables:
  DEVELOP_BRANCH: "main"
  HELM_BASEDIR: helm'
assert_eq main "$(develop_branch)" "DEVELOP_BRANCH entre comillas dobles"
assert_eq helm "$(chart_dir)" "HELM_BASEDIR sin comillas"

add_file .gitlab-ci.yml "variables:
  DEVELOP_BRANCH: 'trunk'   # rama principal
  HELM_BASEDIR: \"deploy/chart\""
assert_eq trunk "$(develop_branch)" "comillas simples y comentario"
assert_eq deploy/chart "$(chart_dir)" "ruta con barra"

add_file .gitlab-ci.yml 'build:
  variables:
    DEVELOP_BRANCH: "otra"
    HELM_BASEDIR: otro'
assert_eq develop "$(develop_branch)" "variables de un job no cuentan (rama)"
assert_eq chart "$(chart_dir)" "variables de un job no cuentan (chart)"

# detect_lang
reset_files
add_file pom.xml '<project/>'
assert_eq maven "$(detect_lang)" "pom.xml es maven"

reset_files
add_file build.gradle.kts 'version = "1.0.0"'
assert_eq gradle "$(detect_lang)" "build.gradle.kts es gradle"

reset_files
add_file build.gradle "version = '1.0.0'"
assert_eq gradle "$(detect_lang)" "build.gradle es gradle"

reset_files
add_file package.json '{}'
add_file pnpm-lock.yaml 'lockfileVersion: 9'
assert_eq pnpm "$(detect_lang)" "package.json con pnpm-lock es pnpm"

reset_files
add_file package.json '{}'
assert_eq npm "$(detect_lang)" "package.json solo es npm"

reset_files
add_file pom.xml '<project/>'
add_file package.json '{}'
OUT=$(detect_lang 2>&1); RC=$?
assert_eq 1 "$RC" "pom.xml y package.json: falla"
assert_contains "$OUT" "usá --lang" "pom.xml y package.json: indica --lang"

LANG_OVERRIDE=npm
assert_eq npm "$(detect_lang)" "--lang resuelve la ambigüedad"

reset_files
OUT=$(detect_lang 2>&1); RC=$?
assert_eq 1 "$RC" "sin archivos: falla"
assert_contains "$OUT" "no detectado" "sin archivos: mensaje"

finish
