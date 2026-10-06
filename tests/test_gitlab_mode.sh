. "$(dirname "$0")/lib.sh"

new_repo
fake_glab
git remote set-url origin https://gitlab.example.com/g/p.git

# sin glab en el PATH
OLDPATH=$PATH
no_glab
if command -v glab >/dev/null 2>&1; then assert_eq "sin glab" "glab presente" "no_glab quita glab"; fi
run_cv gitlab-mode
assert_eq "gitlab=manual" "$OUT" "sin glab: manual"
PATH=$OLDPATH

# glab autenticado
printf '0\n' > "$T/glab/auth.rc"
run_cv gitlab-mode
assert_eq "gitlab=glab" "$OUT" "auth ok: glab"
assert_contains "$(cat "$T/glab.log")" "auth status --hostname gitlab.example.com" "auth status con hostname"

# glab sin sesion
printf '1\n' > "$T/glab/auth.rc"
run_cv gitlab-mode
assert_eq "gitlab=manual" "$OUT" "auth fallida: manual"

# origin local (sin host): manual y sin llamar a glab
printf '0\n' > "$T/glab/auth.rc"
: > "$T/glab.log"
git remote set-url origin "$T/origin.git"
run_cv gitlab-mode
assert_eq "gitlab=manual" "$OUT" "origin local: manual"
assert_eq "" "$(cat "$T/glab.log")" "origin local: no llama a glab"

# mr-link con distintos origin
for u in https://gitlab.example.com/g/p.git git@gitlab.example.com:g/sub/p.git ssh://git@gitlab.example.com:2222/g/p.git https://gitlab.example.com/g/p; do
  git remote set-url origin "$u"
  case "$u" in
    *sub*) path=g/sub/p ;;
    *) path=g/p ;;
  esac
  run_cv mr-link
  assert_eq "mr_link=https://gitlab.example.com/$path/-/merge_requests/new?merge_request[source_branch]=develop&merge_request[target_branch]=main" "$OUT" "mr-link $u"
done

# ramas configuradas en .gitlab-ci.yml
git remote set-url origin https://gitlab.example.com/g/p.git
add_file .gitlab-ci.yml 'variables:
  DEVELOP_BRANCH: dev
  MAIN_BRANCH: master'
run_cv mr-link
assert_eq "mr_link=https://gitlab.example.com/g/p/-/merge_requests/new?merge_request[source_branch]=dev&merge_request[target_branch]=master" "$OUT" "mr-link con ramas configuradas"

# origin local: mr-link falla
git remote set-url origin "$T/origin.git"
run_cv mr-link
assert_eq 1 "$RC" "mr-link con origin local falla"
assert_contains "$ERRO" "ERR:" "mr-link con origin local: mensaje"

finish
