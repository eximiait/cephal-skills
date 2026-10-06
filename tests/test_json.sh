. "$(dirname "$0")/lib.sh"
CEPHAL_VERSION_SOURCED=1 . "$CV"
unset CEPHAL_VERSION_SOURCED
FX="$ROOT/tests/fixtures"
URL='https://gitlab.example.com/g/p/-/merge_requests/12'
SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

jg() { json_get "$1" < "$FX/$2"; }

assert_eq 12 "$(jg iid mr_view_running.json)" "iid top-level, no el de milestone ni head_pipeline"
assert_eq opened "$(jg state mr_view_running.json)" "state top-level, no el de author"
assert_eq "$SHA" "$(jg sha mr_view_running.json)" "sha top-level"
assert_eq running "$(jg head_pipeline.status mr_view_running.json)" "head_pipeline.status, no pipeline.status"
assert_eq success "$(jg pipeline.status mr_view_running.json)" "pipeline.status"
assert_eq 39 "$(jg head_pipeline.iid mr_view_running.json)" "head_pipeline.iid"
assert_eq 7 "$(jg milestone.iid mr_view_running.json)" "milestone.iid"
assert_eq "$URL" "$(jg web_url mr_view_running.json)" "web_url"
assert_eq false "$(jg draft mr_view_running.json)" "booleano crudo"
assert_eq "" "$(jg no_existe mr_view_running.json)" "clave inexistente vacía"
assert_eq "" "$(jg head_pipeline.nada mr_view_running.json)" "subclave inexistente vacía"
assert_eq merged "$(jg state mr_view_merged.json)" "state merged"
assert_eq canceled "$(jg head_pipeline.status mr_view_closed.json)" "head_pipeline.status closed"
assert_eq failed "$(jg head_pipeline.status mr_view_failed.json)" "head_pipeline.status failed"
assert_eq success "$(jg head_pipeline.status mr_view_success.json)" "head_pipeline.status success"

assert_eq "" "$(jg head_pipeline.status mr_view_nopipeline.json)" "head_pipeline null: sin status"
assert_eq null "$(jg head_pipeline mr_view_nopipeline.json)" "head_pipeline null se imprime"
assert_eq null "$(jg merged_at mr_view_nopipeline.json)" "null top-level"

assert_eq 12 "$(jg 0.iid mr_list_one.json)" "lista: 0.iid, no el de author"
assert_eq "$URL" "$(jg 0.web_url mr_list_one.json)" "lista: 0.web_url"
assert_eq "" "$(jg 1.iid mr_list_one.json)" "lista: segundo elemento inexistente"
assert_eq "" "$(jg 0.iid mr_list_empty.json)" "lista vacía"

# Strings con \" y llaves escapadas no rompen la profundidad.
assert_eq 'Release de prueba con "comillas" y {llaves}' "$(jg description mr_view_running.json)" "description con comillas y llaves escapadas"
J='{"a":"x \"}\" {[ \\","b":{"c":"no"},"c":"si","d":[1,{"c":"no"}],"e":"ok"}'
assert_eq si "$(printf '%s\n' "$J" | json_get c)" "c top-level tras string con escapes"
assert_eq ok "$(printf '%s\r\n' "$J" | json_get e)" "tolera CRLF final"
assert_eq 'x "}" {[ \' "$(printf '%s\n' "$J" | json_get a)" "string desescapado"
assert_eq no "$(printf '%s\n' "$J" | json_get b.c)" "b.c"
assert_eq "" "$(printf '%s\n' "$J" | json_get d.c)" "d.c: arreglo sin clave"
assert_eq 1 "$(printf '%s\n' "$J" | json_get d.0)" "d.0 numero"

finish
