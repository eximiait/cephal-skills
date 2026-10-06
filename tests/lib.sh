# Helpers de prueba; se cargan con `. "$(dirname "$0")/lib.sh"` desde cada tests/test_*.sh.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CV="$ROOT/scripts/cephal-version"
TESTS=0
FAILS=0

# Aísla git de la configuración del equipo donde corren las pruebas.
GIT_CONFIG_GLOBAL=/dev/null
GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL EMAIL

# Crea un repo temporal en `develop` con remoto bare `origin`, un commit inicial pusheado, y hace cd.
new_repo() {
  T=$(mktemp -d)
  git init -q --bare -b develop "$T/origin.git"
  REPO="$T/repo"
  git init -q -b develop "$REPO"
  cd "$REPO" || exit 1
  git config user.name "Dev Test"
  git config user.email "dev@test"
  git config commit.gpgsign false
  git config tag.gpgsign false
  git config core.autocrlf false
  git remote add origin "$T/origin.git"
  printf 'demo\n' > README.md
  git add -A
  git commit -q -m "Initial"
  git push -q -u origin develop
}

add_file() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" > "$1"
}

commit_all() {
  git add -A
  git commit -q -m "$1"
}

assert_eq() {
  TESTS=$((TESTS + 1))
  if [ "$1" != "$2" ]; then
    FAILS=$((FAILS + 1))
    printf 'FAIL: %s\n  esperado: [%s]\n  obtenido: [%s]\n' "$3" "$1" "$2"
  fi
}

assert_contains() {
  TESTS=$((TESTS + 1))
  case "$1" in
    *"$2"*) ;;
    *)
      FAILS=$((FAILS + 1))
      printf 'FAIL: %s\n  no contiene: [%s]\n  texto: [%s]\n' "$3" "$2" "$1"
      ;;
  esac
}

# Ejecuta el script; deja OUT, ERRO y RC. Vacía CEPHAL_VERSION_SOURCED porque
# `VAR=1 . script` la deja exportada en sh y el script quedaría sin ejecutar `main`.
run_cv() {
  ERRF=${ERRF:-$(mktemp)}
  OUT=$(CEPHAL_VERSION_SOURCED='' sh "$CV" "$@" 2>"$ERRF")
  RC=$?
  ERRO=$(cat "$ERRF")
}

finish() {
  printf '%s: %s pruebas, %s fallas\n' "$(basename "$0")" "$TESTS" "$FAILS"
  [ "$FAILS" -eq 0 ]
}
