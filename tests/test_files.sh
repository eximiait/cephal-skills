. "$(dirname "$0")/lib.sh"
CEPHAL_VERSION_SOURCED=1 . "$CV"
unset CEPHAL_VERSION_SOURCED
new_repo

same() { cmp -s "$1" "$2" && echo same || echo differ; }
reset_files() { rm -rf pom.xml build.gradle build.gradle.kts gradle.properties package.json chart; }

# Sin salto de línea final: la edición no lo agrega.
reset_files
printf '<project>\n  <version>1.0.0</version>\n</project>' > pom.xml
set_version 1.0.1
printf '<project>\n  <version>1.0.1</version>\n</project>' > "$T/exp"
assert_eq same "$(same pom.xml "$T/exp")" "pom sin salto final: no lo agrega"

reset_files
printf '<project>\r\n  <version>1.0.0</version>\r\n</project>' > pom.xml
set_version 1.0.1
printf '<project>\r\n  <version>1.0.1</version>\r\n</project>' > "$T/exp"
assert_eq same "$(same pom.xml "$T/exp")" "pom CRLF sin salto final: no lo agrega"

reset_files
printf '{\n  "version": "1.0.0"\n}' > package.json
set_version 1.0.1
printf '{\n  "version": "1.0.1"\n}' > "$T/exp"
assert_eq same "$(same package.json "$T/exp")" "package.json sin salto final: no lo agrega"

reset_files
mkdir chart
printf 'name: demo\nappVersion: "1.0.0"' > chart/Chart.yaml
set_chart_app_version 1.0.1
printf 'name: demo\nappVersion: "1.0.1"' > "$T/exp"
assert_eq same "$(same chart/Chart.yaml "$T/exp")" "Chart.yaml sin salto final: no lo agrega"

# Con salto de línea final: se conserva.
reset_files
printf '<project>\n  <version>1.0.0</version>\n</project>\n' > pom.xml
set_version 1.0.1
printf '<project>\n  <version>1.0.1</version>\n</project>\n' > "$T/exp"
assert_eq same "$(same pom.xml "$T/exp")" "pom con salto final: lo conserva"

# Gradle con CRLF.
reset_files
printf "plugins { id 'java' }\r\n" > build.gradle
printf 'org.gradle.jvmargs=-Xmx1g\r\nversion=1.4.0\r\n' > gradle.properties
set_version 1.5.0
printf 'org.gradle.jvmargs=-Xmx1g\r\nversion=1.5.0\r\n' > "$T/exp"
assert_eq same "$(same gradle.properties "$T/exp")" "gradle.properties con CRLF: lo conserva"

reset_files
printf "plugins { java }\r\nversion = \"2.0.0\"\r\n" > build.gradle.kts
set_version 2.0.1
printf "plugins { java }\r\nversion = \"2.0.1\"\r\n" > "$T/exp"
assert_eq same "$(same build.gradle.kts "$T/exp")" "build.gradle.kts con CRLF: lo conserva"

finish
