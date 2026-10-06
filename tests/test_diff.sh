. "$(dirname "$0")/lib.sh"
ESC=$(printf '\033')
no_ansi() { case "$OUT" in *"$ESC"*) echo con-ansi ;; *) echo sin-ansi ;; esac; }

setup() {
  new_repo
  add_file pom.xml '<project>
  <artifactId>demo</artifactId>
  <version>1.3.1-SNAPSHOT</version>
</project>'
  add_file chart/Chart.yaml 'name: demo
version: 2.4.0
appVersion: "1.3.1-SNAPSHOT"'
  commit_all "base"
  git push -q
  git tag 2.4.0
  # configuración del dev que no debe afectar la salida
  git config color.ui always
  git config color.diff always
  git config diff.mnemonicPrefix true
}

# bump: diff de los archivos editados
setup
run_cv bump patch
assert_contains "$OUT" "diff --git a/pom.xml b/pom.xml" "bump: diff del pom"
assert_contains "$OUT" "-  <version>1.3.1-SNAPSHOT</version>" "bump: línea quitada"
assert_contains "$OUT" "+  <version>1.3.2-SNAPSHOT</version>" "bump: línea agregada"
assert_contains "$OUT" "diff --git a/chart/Chart.yaml b/chart/Chart.yaml" "bump: diff del Chart.yaml"
assert_eq sin-ansi "$(no_ansi)" "bump: sin códigos ANSI aunque el dev tenga color.ui=always"

# release-prep --apply: diff del commit
setup
run_cv release-prep --apply
assert_contains "$OUT" "-  <version>1.3.1-SNAPSHOT</version>" "release-prep --apply: línea quitada"
assert_contains "$OUT" "+  <version>1.3.1</version>" "release-prep --apply: línea agregada"
assert_eq sin-ansi "$(no_ansi)" "release-prep --apply: sin ANSI"

# chart-prep --apply: diff del commit
setup
run_cv chart-prep --apply minor
assert_contains "$OUT" "diff --git a/chart/Chart.yaml b/chart/Chart.yaml" "chart-prep --apply: diff del Chart.yaml"
assert_contains "$OUT" "-version: 2.4.0" "chart-prep --apply: línea quitada"
assert_contains "$OUT" "+version: 2.5.0" "chart-prep --apply: línea agregada"
assert_eq sin-ansi "$(no_ansi)" "chart-prep --apply: sin ANSI"

# sin cambios: sin diff
setup
run_cv release-prep
case "$OUT" in *"diff --git"*) d=con-diff ;; *) d=sin-diff ;; esac
assert_eq sin-diff "$d" "release-prep sin --apply: sin diff"

finish
