. "$(dirname "$0")/lib.sh"
CEPHAL_VERSION_SOURCED=1 . "$CV"
new_repo

has() { grep -qF -- "$2" "$1" && echo yes || echo no; }
count() { grep -cF -- "$2" "$1"; }
same() { cmp -s "$1" "$2" && echo same || echo differ; }
reset_files() { rm -rf pom.xml api build.gradle build.gradle.kts gradle.properties package.json pnpm-lock.yaml chart helm .gitlab-ci.yml; LANG_OVERRIDE=""; }

# ---------- Maven ----------
reset_files
add_file pom.xml '<project>
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.2.0</version>
  </parent>
  <groupId>com.acme</groupId>
  <artifactId>demo</artifactId>
  <version>1.3.1-SNAPSHOT</version>
  <dependencies>
    <dependency><groupId>g</groupId><artifactId>a</artifactId><version>9.9.9</version></dependency>
  </dependencies>
</project>'
assert_eq 1.3.1-SNAPSHOT "$(get_version)" "maven: lee la versión del proyecto, no la del parent"
set_version 1.3.2-SNAPSHOT
assert_eq 1.3.2-SNAPSHOT "$(get_version)" "maven: escribe la versión del proyecto"
assert_eq 1 "$(count pom.xml '<version>3.2.0</version>')" "maven: no toca la versión del parent"
assert_eq 1 "$(count pom.xml '<version>9.9.9</version>')" "maven: no toca versiones de dependencias"

reset_files
add_file pom.xml '<project>
  <groupId>com.acme</groupId>
  <artifactId>demo</artifactId>
  <version>${revision}</version>
  <properties>
    <revision>2.0.0</revision>
  </properties>
</project>'
assert_eq 2.0.0 "$(get_version)" "maven: resuelve \${revision}"
set_version 2.1.0
assert_eq 2.1.0 "$(get_version)" "maven: escribe la propiedad revision"
assert_eq 1 "$(count pom.xml '<version>${revision}</version>')" "maven: conserva \${revision} en el proyecto"

reset_files
add_file pom.xml '<project>
  <groupId>com.acme</groupId>
  <artifactId>demo</artifactId>
  <version>1.0.0</version>
  <modules><module>api</module></modules>
</project>'
add_file api/pom.xml '<project>
  <parent><groupId>com.acme</groupId><artifactId>demo</artifactId><version>1.0.0</version></parent>
  <artifactId>api</artifactId>
</project>'
commit_all "multi-modulo"
set_version 1.0.1
assert_eq "pom.xml" "$(git diff --name-only)" "maven multi-módulo: solo cambia el pom raíz"

reset_files
add_file pom.xml '<project>
  <groupId>com.acme</groupId>
  <artifactId>demo</artifactId>
  <version>${project.parent.version}</version>
</project>'
OUT=$(get_version 2>&1); RC=$?
assert_eq 1 "$RC" "maven: versión dinámica falla"
assert_contains "$OUT" "no resoluble" "maven: versión dinámica, mensaje"

reset_files
printf '<project>\r\n  <artifactId>demo</artifactId>\r\n  <version>1.0.0</version>\r\n</project>\r\n' > pom.xml
set_version 1.0.1
printf '<project>\r\n  <artifactId>demo</artifactId>\r\n  <version>1.0.1</version>\r\n</project>\r\n' > "$T/exp"
assert_eq same "$(same pom.xml "$T/exp")" "maven: conserva CRLF"

# ---------- Gradle ----------
reset_files
add_file build.gradle "plugins { id 'java' }"
printf 'org.gradle.jvmargs=-Xmx1g\nversion=1.4.0\ngroup=com.acme\n' > gradle.properties
assert_eq 1.4.0 "$(get_version)" "gradle: lee gradle.properties"
set_version 1.5.0
assert_eq 1.5.0 "$(get_version)" "gradle: escribe gradle.properties"
assert_eq 1 "$(count gradle.properties 'org.gradle.jvmargs=-Xmx1g')" "gradle: conserva otras propiedades"

reset_files
add_file build.gradle.kts 'plugins { java }
group = "com.acme"
version = "2.0.0"'
assert_eq 2.0.0 "$(get_version)" "gradle kts: lee"
set_version 2.0.1
assert_eq 'version = "2.0.1"' "$(grep '^version' build.gradle.kts)" "gradle kts: conserva comillas dobles"

reset_files
add_file build.gradle "sourceCompatibility = '17'
version = '3.0.0'"
assert_eq 3.0.0 "$(get_version)" "gradle groovy: lee"
set_version 3.0.1
assert_eq "version = '3.0.1'" "$(grep '^version' build.gradle)" "gradle groovy: conserva comillas simples"
assert_eq 1 "$(count build.gradle "sourceCompatibility = '17'")" "gradle groovy: no toca otras líneas"

reset_files
add_file build.gradle "group = 'com.acme'"
OUT=$(get_version 2>&1); RC=$?
assert_eq 1 "$RC" "gradle sin versión: falla"
assert_contains "$OUT" "no resoluble" "gradle sin versión: mensaje"

# ---------- npm / pnpm ----------
reset_files
add_file package.json '{
  "name": "demo",
  "engines": {
    "version": "9.9.9"
  },
  "version": "1.0.0",
  "scripts": { "build": "echo {}" }
}'
assert_eq 1.0.0 "$(get_version)" "npm: lee la versión de primer nivel"
set_version 1.1.0
assert_eq 1.1.0 "$(get_version)" "npm: escribe la versión de primer nivel"
assert_eq 1 "$(count package.json '"version": "9.9.9"')" "npm: no toca versiones anidadas"

add_file pnpm-lock.yaml 'lockfileVersion: 9'
assert_eq pnpm "$(detect_lang)" "pnpm: detectado"
assert_eq 1.1.0 "$(get_version)" "pnpm: lee package.json"

reset_files
printf '{\r\n  "name": "demo",\r\n  "version": "1.0.0"\r\n}\r\n' > package.json
set_version 1.0.1
printf '{\r\n  "name": "demo",\r\n  "version": "1.0.1"\r\n}\r\n' > "$T/exp"
assert_eq same "$(same package.json "$T/exp")" "npm: conserva CRLF"

# ---------- appVersion del chart ----------
reset_files
add_file chart/Chart.yaml 'apiVersion: v2
name: demo
appVersion: "1.0.0"
version: 0.0.0'
set_chart_app_version 1.2.0
assert_eq 'appVersion: "1.2.0"' "$(grep '^appVersion' chart/Chart.yaml)" "chart: reemplaza appVersion entre comillas"
assert_eq 1 "$(count chart/Chart.yaml 'version: 0.0.0')" "chart: no toca version"

add_file chart/Chart.yaml 'apiVersion: v2
appVersion: 1.0.0'
set_chart_app_version 1.3.0
assert_eq 'appVersion: "1.3.0"' "$(grep '^appVersion' chart/Chart.yaml)" "chart: reemplaza appVersion sin comillas"

add_file chart/Chart.yaml 'apiVersion: v2
name: demo'
set_chart_app_version 1.4.0
assert_eq 'appVersion: "1.4.0"' "$(grep '^appVersion' chart/Chart.yaml)" "chart: agrega appVersion si falta"

printf 'apiVersion: v2\r\nappVersion: "1.0.0"\r\n' > chart/Chart.yaml
set_chart_app_version 1.5.0
printf 'apiVersion: v2\r\nappVersion: "1.5.0"\r\n' > "$T/exp"
assert_eq same "$(same chart/Chart.yaml "$T/exp")" "chart: conserva CRLF"

reset_files
assert_eq "chart=skipped" "$(set_chart_app_version 1.0.0)" "chart: sin Chart.yaml informa skipped"

add_file .gitlab-ci.yml 'variables:
  HELM_BASEDIR: helm'
add_file helm/Chart.yaml 'name: demo'
set_chart_app_version 2.0.0
assert_eq 'appVersion: "2.0.0"' "$(grep '^appVersion' helm/Chart.yaml)" "chart: respeta HELM_BASEDIR"

finish
