. "$(dirname "$0")/lib.sh"
CEPHAL_VERSION_SOURCED=1 . "$CV"

# Ceros a la izquierda: se normalizan en lugar de romper la aritmética.
assert_eq 1.0.9 "$(semver_bump 1.0.08 patch 2>&1)" "ceros a la izquierda en patch"
assert_eq 1.9.0 "$(semver_bump 1.08.0 minor 2>&1)" "ceros a la izquierda en minor"
assert_eq 1.0.1 "$(semver_bump 1.0.0 patch 2>&1)" "un cero solo sigue valiendo 0"

new_repo
add_file pom.xml '<project>
  <artifactId>demo</artifactId>
  <version>1.0.0-SNAPSHOT</version>
</project>'
commit_all "pom"
git push -q

# Versión explícita con salto de línea: se rechaza sin tocar el archivo.
run_cv bump "$(printf '1.2.3\nfoo')"
assert_eq 1 "$RC" "bump con salto de línea falla"
assert_eq 1 "$(grep -c '<version>1.0.0-SNAPSHOT</version>' pom.xml)" "bump con salto de línea: no edita el pom"

# Tag con salto de línea: formato inválido.
run_cv tag-push "$(printf '1.0.0\nfoo')"
assert_eq 1 "$RC" "tag con salto de línea falla"
assert_contains "$ERRO" "formato de tag inválido" "tag con salto de línea: mensaje"

# tag-push rechaza una versión de app con -SNAPSHOT.
run_cv tag-push 1.0.0
assert_eq 1 "$RC" "tag-push con versión -SNAPSHOT falla"
assert_contains "$ERRO" "-SNAPSHOT" "tag-push con -SNAPSHOT: mensaje"
assert_eq "" "$(git tag --list 1.0.0)" "tag-push con -SNAPSHOT: no crea el tag"

# Con la versión limpia, tag-push funciona.
run_cv release-prep --apply
run_cv tag-push 1.0.0
assert_eq "pushed=1.0.0" "$OUT" "tag-push con versión limpia"

# check muestra el error real de git fetch.
git tag 5.0.0
git push -q origin 5.0.0
git tag -d 5.0.0 >/dev/null
add_file otro.txt 1
commit_all "otro"
git push -q
git tag 5.0.0
run_cv check
assert_eq 1 "$RC" "check con tag local en conflicto falla"
assert_contains "$ERRO" "no se pudo consultar origin:" "check: conserva el prefijo"
assert_contains "$ERRO" "clobber" "check: muestra el error de git"

finish
