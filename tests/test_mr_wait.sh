. "$(dirname "$0")/lib.sh"

new_repo
fake_glab
FX="$ROOT/tests/fixtures"
CEPHAL_POLL_SECONDS=0
export CEPHAL_POLL_SECONDS

views() {
  rm -f "$T/glab/view.count" "$T/glab/view".*.json
  vi=1
  for f in "$@"; do
    cp "$FX/$f" "$T/glab/view.$vi.json"
    vi=$((vi + 1))
  done
}

# mr-wait modo pipeline
views mr_view_running.json mr_view_success.json
run_cv mr-wait 12 pipeline
assert_eq 0 "$RC" "mr-wait pipeline: rc"
assert_contains "$OUT" "pipeline=success" "mr-wait pipeline termina en success"
assert_contains "$OUT" "timeout=no" "mr-wait pipeline timeout=no"
assert_contains "$OUT" "url=https://gitlab.example.com/g/p/-/merge_requests/12" "mr-wait imprime los kv de mr-status"

: > "$T/glab.log"
views mr_view_running.json
CEPHAL_WAIT_STEP_SECONDS=0 run_cv mr-wait 12 pipeline
assert_contains "$OUT" "pipeline=running" "mr-wait timeout: ultimo estado"
assert_contains "$OUT" "timeout=yes" "mr-wait timeout=yes"
assert_eq 1 "$(grep -c "mr view" "$T/glab.log")" "mr-wait: step 0 consulta una sola vez"

# estado ya alcanzado: vuelve sin esperar (poll alto no debe dormir)
views mr_view_success.json
S0=$(date +%s)
CEPHAL_POLL_SECONDS=30 run_cv mr-wait 12 pipeline
S1=$(date +%s)
assert_contains "$OUT" "timeout=no" "mr-wait ya alcanzado"
FAST=no; [ $((S1 - S0)) -lt 10 ] && FAST=yes
assert_eq yes "$FAST" "mr-wait ya alcanzado no duerme el poll de 30s"

# modo merged
views mr_view_running.json mr_view_merged.json
run_cv mr-wait 12 merged
assert_contains "$OUT" "state=merged" "mr-wait merged"
assert_contains "$OUT" "timeout=no" "mr-wait merged timeout=no"

views mr_view_closed.json
run_cv mr-wait 12 merged
assert_contains "$OUT" "state=closed" "mr-wait closed"
assert_contains "$OUT" "timeout=no" "mr-wait closed timeout=no"

# variables de espera invalidas
for v in CEPHAL_POLL_SECONDS CEPHAL_WAIT_STEP_SECONDS; do
  for bad in abc -1 1.5; do
    views mr_view_running.json
    env "$v=$bad" CEPHAL_VERSION_SOURCED="" sh "$CV" mr-wait 12 pipeline >/dev/null 2>"$T/err"
    assert_eq 1 "$?" "$v=[$bad] falla"
    assert_contains "$(cat "$T/err")" "$v debe ser un entero" "$v=[$bad] nombra la variable"
  done
done

# argumentos
run_cv mr-wait
assert_eq 1 "$RC" "mr-wait sin args falla"
run_cv mr-wait 12
assert_eq 1 "$RC" "mr-wait sin modo falla"
run_cv mr-wait 12 otro
assert_eq 1 "$RC" "mr-wait modo invalido falla"
assert_contains "$ERRO" "ERR:" "mr-wait modo invalido: ERR"

# mr-merge
SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
views mr_view_success.json
: > "$T/glab.log"
run_cv mr-merge 12 "$SHA"
assert_eq "merged=yes" "$OUT" "mr-merge ok"
assert_contains "$(cat "$T/glab.log")" "mr view 12 -F json" "mr-merge consulta el MR antes de mergear"
ML=$(grep 'mr merge' "$T/glab.log")
assert_eq "mr merge 12 --sha $SHA --remove-source-branch=false --auto-merge=false --yes" "$ML" "mr-merge comando exacto"
for bad in --squash " -d" --force --remove-source-branch=true; do
  case "$ML" in *"$bad"*) assert_eq "sin $bad" "con $bad" "mr-merge no usa $bad" ;; *) assert_eq 1 1 "mr-merge no usa $bad" ;; esac
done

# MR con 'Delete source branch' activado: no se mergea
views mr_view_remove_source.json
: > "$T/glab.log"
run_cv mr-merge 12 "$SHA"
assert_eq 1 "$RC" "mr-merge con force_remove_source_branch falla"
assert_contains "$ERRO" "el MR borraría develop al mergear: desactivá 'Delete source branch' en el MR" "mr-merge con force_remove_source_branch: mensaje"
assert_eq "" "$(grep 'mr merge' "$T/glab.log")" "mr-merge con force_remove_source_branch: no llama a glab mr merge"

# iid y sha inválidos: falla sin llamar a glab
views mr_view_success.json
: > "$T/glab.log"
for args in "x1 $SHA" "12 abc123" "12 AAAAAAAAAAAA" "12 ${SHA}a" "12 abc123z"; do
  # shellcheck disable=SC2086
  run_cv mr-merge $args
  assert_eq 1 "$RC" "mr-merge [$args] falla"
  assert_contains "$ERRO" "inválido" "mr-merge [$args]: mensaje"
done
assert_eq "" "$(cat "$T/glab.log")" "mr-merge con argumentos inválidos: no llama a glab"
run_cv mr-wait x1 pipeline
assert_eq 1 "$RC" "mr-wait iid inválido falla"
assert_contains "$ERRO" "iid inválido" "mr-wait iid inválido: mensaje"

printf 'approvals required\n' > "$T/glab/merge.out"
printf '1\n' > "$T/glab/merge.rc"
run_cv mr-merge 12 "$SHA"
assert_eq 1 "$RC" "mr-merge falla"
assert_contains "$ERRO" "ERR:" "mr-merge fallo: ERR"
assert_contains "$ERRO" "approvals required" "mr-merge fallo: salida de glab"
run_cv mr-merge 12
assert_eq 1 "$RC" "mr-merge sin sha falla"
run_cv mr-merge
assert_eq 1 "$RC" "mr-merge sin args falla"
finish
