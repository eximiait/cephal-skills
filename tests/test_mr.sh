. "$(dirname "$0")/lib.sh"

new_repo
fake_glab
FX="$ROOT/tests/fixtures"
git remote set-url origin https://gitlab.example.com/g/p.git

# mr-find
cp "$FX/mr_list_empty.json" "$T/glab/list.json"
run_cv mr-find
assert_eq "mr=none" "$OUT" "mr-find sin MR"
cp "$FX/mr_list_one.json" "$T/glab/list.json"
run_cv mr-find
assert_eq "mr_iid=12
mr_url=https://gitlab.example.com/g/p/-/merge_requests/12" "$OUT" "mr-find con MR"
assert_contains "$(grep 'mr list' "$T/glab.log")" "-s develop -t main -F json" "mr-find argumentos"

# mr-create
printf 'Creating merge request\nhttps://gitlab.example.com/g/p/-/merge_requests/11\nhttps://gitlab.example.com/g/p/-/merge_requests/12\n' > "$T/glab/create.out"
run_cv mr-create
assert_eq "mr_iid=12
mr_url=https://gitlab.example.com/g/p/-/merge_requests/12" "$OUT" "mr-create extrae la ultima URL"
CL=$(grep 'mr create' "$T/glab.log")
assert_contains "$CL" "-s develop -b main" "mr-create ramas"
assert_contains "$CL" "-t Release develop → main" "mr-create titulo"
assert_contains "$CL" "--remove-source-branch=false" "mr-create no borra la rama"
assert_contains "$CL" "--squash-before-merge=false" "mr-create sin squash"
assert_contains "$CL" "--yes" "mr-create --yes"
case "$CL" in *--force*) assert_eq "sin --force" "con --force" "mr-create no usa --force" ;; *) assert_eq 1 1 "mr-create no usa --force" ;; esac

printf 'algo salio mal\n' > "$T/glab/create.out"
run_cv mr-create
assert_eq 1 "$RC" "mr-create sin URL falla"
assert_contains "$ERRO" "ERR:" "mr-create sin URL: ERR"
assert_contains "$ERRO" "algo salio mal" "mr-create sin URL: salida de glab"

# mr-status
status_of() {
  rm -f "$T/glab/view.count" "$T/glab/view".*.json
  cp "$FX/$1" "$T/glab/view.1.json"
  run_cv mr-status 12
}
status_of mr_view_running.json
assert_eq "state=opened
pipeline=running
sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
url=https://gitlab.example.com/g/p/-/merge_requests/12
remove_source=false" "$OUT" "mr-status running"
assert_contains "$(grep 'mr view' "$T/glab.log")" "mr view 12 -F json" "mr-status argumentos"
# sha de primer nivel, no el de head_pipeline ni el de pipeline (el fixture trae los tres distintos)
assert_eq "sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "$(printf '%s\n' "$OUT" | grep '^sha=')" "sha de primer nivel"
assert_contains "$(cat "$FX/mr_view_running.json")" '"head_pipeline":{"id":201,"iid":39,"project_id":55,"status":"running","source":"push","ref":"develop","name":null,"sha":"3333333333333333333333333333333333333333"' "fixture: head_pipeline con otro sha"
status_of mr_view_remove_source.json
assert_contains "$OUT" "remove_source=true" "mr-status: MR que borra la rama de origen"
status_of mr_view_success.json
assert_contains "$OUT" "pipeline=success" "mr-status success"
status_of mr_view_failed.json
assert_contains "$OUT" "pipeline=failed" "mr-status failed"
status_of mr_view_nopipeline.json
assert_contains "$OUT" "pipeline=none" "mr-status sin pipeline"
status_of mr_view_merged.json
assert_contains "$OUT" "state=merged" "mr-status merged"
status_of mr_view_closed.json
assert_contains "$OUT" "state=closed" "mr-status closed"
assert_contains "$OUT" "pipeline=canceled" "mr-status canceled tal cual"
assert_contains "$OUT" "remove_source=false" "mr-status closed: remove_source=false"

# iid inválido: falla sin llamar a glab
: > "$T/glab.log"
for bad in abc 12x "-1" "12 13"; do
  run_cv mr-status "$bad"
  assert_eq 1 "$RC" "mr-status iid [$bad] falla"
  assert_contains "$ERRO" "iid inválido" "mr-status iid [$bad]: mensaje"
done
assert_eq "" "$(cat "$T/glab.log")" "mr-status iid inválido: no llama a glab"

# pipeline_state
CEPHAL_VERSION_SOURCED=1 . "$CV"
unset CEPHAL_VERSION_SOURCED
for s in created waiting_for_resource preparing pending running scheduled; do
  assert_eq running "$(pipeline_state $s)" "pipeline_state $s"
done
assert_eq manual "$(pipeline_state manual)" "pipeline_state manual"

# uso y errores
run_cv mr-status
assert_eq 1 "$RC" "mr-status sin iid falla"
# glab que falla: se propaga ERR con su salida
printf '#!/bin/sh
echo "glab: no autorizado"
exit 1
' > "$T/bin/glab"
for c in mr-find mr-create "mr-status 12"; do
  run_cv $c
  assert_eq 1 "$RC" "$c: glab falla"
  assert_contains "$ERRO" "ERR:" "$c: ERR"
  assert_contains "$ERRO" "no autorizado" "$c: salida de glab"
done
finish
