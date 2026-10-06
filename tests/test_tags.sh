. "$(dirname "$0")/lib.sh"
CEPHAL_VERSION_SOURCED=1 . "$CV"

# semver_bump
assert_eq 1.3.2-SNAPSHOT "$(semver_bump 1.3.1-SNAPSHOT patch)" "bump patch conserva -SNAPSHOT"
assert_eq 1.4.0-SNAPSHOT "$(semver_bump 1.3.1-SNAPSHOT minor)" "bump minor reinicia patch"
assert_eq 2.0.0 "$(semver_bump 1.3.1 major)" "bump major reinicia minor y patch"
OUT=$(semver_bump 1.2.3-rc1 patch 2>&1); RC=$?
assert_eq 1 "$RC" "sufijo distinto de SNAPSHOT: falla"
assert_contains "$OUT" "sufijo no soportado: -rc1" "sufijo distinto de SNAPSHOT: mensaje"
OUT=$(semver_bump 1.2.3 huge 2>&1); RC=$?
assert_eq 1 "$RC" "tipo inválido: falla"
assert_contains "$OUT" "tipo inválido" "tipo inválido: mensaje"
OUT=$(semver_bump 1.2 patch 2>&1); RC=$?
assert_eq 1 "$RC" "versión no semver: falla"

# semver_gt
semver_gt 2.10.0 2.9.0; assert_eq 0 "$?" "2.10.0 > 2.9.0 (comparación numérica)"
semver_gt 2.9.0 2.10.0; assert_eq 1 "$?" "2.9.0 no es mayor que 2.10.0"
semver_gt 1.0.0 1.0.0; assert_eq 1 "$?" "iguales no son mayores"

# last_final y tags ajenos
new_repo
assert_eq 0.0.0 "$(last_final)" "sin tags: 0.0.0"
git tag v1.0.0; git tag release-1; git tag 2.4.0; git tag 2.9.0; git tag 2.10.0
assert_eq 2.10.0 "$(last_final)" "last_final ignora tags ajenos y compara numéricamente"
assert_eq "" "$(open_rc_base)" "sin RC: no hay base abierta"

# RC abierto
new_repo
git tag 2.4.0; git tag 2.5.0-rc.1; git tag 2.5.0-rc.2
assert_eq 2.5.0 "$(open_rc_base)" "RC abierto: base 2.5.0"
assert_eq 2 "$(max_rc_n 2.5.0)" "max_rc_n: 2"
git tag 2.5.0
assert_eq "" "$(open_rc_base)" "con tag final la base deja de estar abierta"

# RC de una base anterior al último final
new_repo
git tag 2.4.0; git tag 2.3.0-rc.1
assert_eq "" "$(open_rc_base)" "RC anterior al último final: ignorado"

# rc.10 contra rc.9
new_repo
git tag 3.0.0-rc.9; git tag 3.0.0-rc.10
assert_eq 10 "$(max_rc_n 3.0.0)" "max_rc_n compara numéricamente"
assert_eq 0 "$(max_rc_n 9.9.9)" "max_rc_n sin RC: 0"

finish
