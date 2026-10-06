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

# Crea un repo temporal con remoto bare `origin`, ramas `develop` y `main` en el commit inicial (ambas pusheadas), checkout en `develop`; hace cd.
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
  git branch main
  git push -q -u origin main
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

# glab falso: crea $T/bin/glab y lo antepone al PATH. Cada invocación agrega "$*" a $T/glab.log.
# Respuestas desde $T/glab/: auth.rc (código de `auth status`, por defecto 0), list.json (`mr list`),
# view.<n>.json (`mr view`, en orden y repitiendo el último), create.out (`mr create`),
# merge.out + merge.rc (`mr merge`, rc por defecto 0).
fake_glab() {
  mkdir -p "$T/bin" "$T/glab"
  : > "$T/glab.log"
  cat > "$T/bin/glab" <<'STUB'
#!/bin/sh
B=$(cd "$(dirname "$0")/.." && pwd)
D="$B/glab"
printf '%s\n' "$*" >> "$B/glab.log"
rc_of() { if [ -f "$D/$1" ]; then cat "$D/$1"; else echo 0; fi; }
out_of() { if [ -f "$D/$1" ]; then cat "$D/$1"; fi; }
case "$1 ${2:-}" in
  "auth status") exit "$(rc_of auth.rc)" ;;
  "mr list") out_of list.json ;;
  "mr view")
    n=0
    [ -f "$D/view.count" ] && n=$(cat "$D/view.count")
    n=$((n + 1))
    f="$D/view.$n.json"
    if [ ! -f "$f" ]; then
      n=$((n - 1))
      f="$D/view.$n.json"
    fi
    echo "$n" > "$D/view.count"
    [ -f "$f" ] && cat "$f"
    ;;
  "mr create") out_of create.out ;;
  "mr merge")
    out_of merge.out
    exit "$(rc_of merge.rc)"
    ;;
esac
exit 0
STUB
  chmod +x "$T/bin/glab"
  PATH="$T/bin:$PATH"
  export PATH
}

# Deja un PATH sin glab (aunque haya uno real): quita las entradas que contienen un `glab` ejecutable.
no_glab() {
  ng_new=""
  ng_old=$PATH
  while [ -n "$ng_old" ]; do
    case "$ng_old" in
      *:*)
        ng_d=${ng_old%%:*}
        ng_old=${ng_old#*:}
        ;;
      *)
        ng_d=$ng_old
        ng_old=""
        ;;
    esac
    if [ -x "$ng_d/glab" ] || [ -x "$ng_d/glab.exe" ]; then continue; fi
    ng_new="${ng_new:+$ng_new:}$ng_d"
  done
  PATH=$ng_new
  export PATH
}
