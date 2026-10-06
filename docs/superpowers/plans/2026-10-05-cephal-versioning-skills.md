# Skills de versionado cephal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publicar el plugin `cephal` con las skills `bump-app-version`, `deploy-test` y `deploy-prod`, respaldadas por un script POSIX testeado en ubuntu, macos y windows.

**Architecture:** Un único script `cephal-version` (sh POSIX) concentra la lógica y expone subcomandos que calculan, validan y escriben. Las skills solo guían al agente (preguntar, mostrar el plan, pedir confirmación, ejecutar). El script se copia dentro de cada skill porque los instaladores copian la carpeta de cada skill.

**Tech Stack:** sh POSIX, awk/sed/grep/git, PowerShell (wrapper), GitHub Actions, shellcheck.

**Spec:** `docs/superpowers/specs/2026-10-05-cephal-versioning-skills-design.md`

## Global Constraints

- POSIX sh estricto: sin `sort -V`, sin `sed -i`, sin arrays ni `[[ ]]`, sin opciones exclusivas de GNU. Editar archivos con archivo temporal + `mv`. `shellcheck -s sh` sin hallazgos.
- Fin de línea LF forzado por `.gitattributes`; las ediciones de `pom.xml`, `package.json`, `build.gradle*` y `Chart.yaml` preservan CRLF si el archivo lo usa.
- Salida en stdout: líneas `clave=valor`. Errores: `ERR: <causa>` en stderr y código de salida 1. Opción global `--lang <maven|gradle|npm|pnpm>` antes del subcomando.
- Rama de desarrollo: `DEVELOP_BRANCH` de `variables:` del `.gitlab-ci.yml` raíz; por defecto `develop`. Directorio del chart: `HELM_BASEDIR` del mismo archivo; por defecto `chart`.
- Tags finales `^[0-9]+\.[0-9]+\.[0-9]+$`; RC `^[0-9]+\.[0-9]+\.[0-9]+-rc\.[0-9]+$`. Cualquier otro tag se ignora. Sin tags finales se parte de `0.0.0`.
- Tags anotados con mensaje = nombre del tag. Push: `git push --atomic origin HEAD:refs/heads/<rama> refs/tags/<tag>`. Commit de release: `Release app x.y.z`.
- Commits y tags usan la identidad git del dev; sin trailers ni menciones al agente ni a cephal; el script nunca setea `user.name`/`user.email`.
- Nunca se pushea sin confirmación explícita del dev. Textos de skills en español, concisos (cada `SKILL.md` ≤ 60 líneas).
- Nombres: plugin `cephal`; skills `bump-app-version`, `deploy-test`, `deploy-prod`; repo `eximiait/cephal-skills`.

## Review Focus

- Versión `2.10.0` contra `2.9.0`: la comparación debe ser numérica (task 4).
- Tags ajenos al esquema (`v1.0.0`, `release-1`) conviven con los tags reales sin romper el cálculo (task 4).
- `pom.xml` multi-módulo o con `<parent>` con su propia `<version>`: solo se edita la del proyecto raíz (task 3).
- Archivos con CRLF: el bump no los convierte a LF (task 3).
- `HEAD` desacoplado (checkout de un tag o de CI): `check` falla en lugar de taguear sin rama (task 6).

---

### Task 1: Esqueleto y arnés de pruebas

**Files:**
- Create: `.gitattributes`, `scripts/cephal-version`, `tests/lib.sh`, `tests/run.sh`, `tests/test_dispatch.sh`

**Interfaces:**
- Produces (`scripts/cephal-version`): `die <msg>` (imprime `ERR: msg` a stderr, `exit 1`); `kv <clave> <valor>` (imprime `clave=valor`); `main "$@"` (parsea `--lang`, despacha a `cmd_<subcomando con - → _>`). Guardia: si `CEPHAL_VERSION_SOURCED=1` el archivo solo define funciones, para poder hacer `.` en las pruebas.
- Produces (`tests/lib.sh`): `new_repo` (crea un repo temporal con rama `develop`, remoto bare `origin`, identidad local `Dev Test <dev@test>`, un commit inicial ya pusheado, hace `cd` y setea `REPO`); `add_file <ruta> <contenido>`; `commit_all <mensaje>`; `assert_eq <esperado> <real> <etiqueta>`; `assert_contains <texto> <fragmento> <etiqueta>`; `run_cv <args…>` (ejecuta `sh "$ROOT/scripts/cephal-version" "$@"`, deja `OUT`, `ERRO` y `RC`). `tests/run.sh` ejecuta cada `tests/test_*.sh` con `sh` y falla si alguno falla.

- [ ] **Step 1: Escribir `tests/test_dispatch.sh`** con dos casos: subcomando desconocido (`run_cv nope`) → `RC=1` y `ERRO` contiene `ERR:`; sin argumentos → `RC=1`.
- [ ] **Step 2: Ejecutar** `sh tests/run.sh`. Esperado: FAIL (no existe el script).
- [ ] **Step 3: Implementar** `lib.sh`, `run.sh`, `.gitattributes` (`* text=auto`, y `eol=lf` para `*.sh`, `scripts/*`, `skills/**/scripts/*`, `*.md`, `*.yml`) y el despachador del script.
- [ ] **Step 4: Ejecutar** `sh tests/run.sh`. Esperado: `OK`, 0 fallas.
- [ ] **Step 5: Commit** `Esqueleto del script y arnés de pruebas`.

### Task 2: Detección de configuración

**Files:**
- Modify: `scripts/cephal-version`
- Test: `tests/test_config.sh`

**Interfaces:**
- Consumes: `die`, `kv`.
- Produces: `develop_branch` (stdout: valor de `DEVELOP_BRANCH` en `variables:` raíz del `.gitlab-ci.yml`, con o sin comillas; `develop` si no está); `chart_dir` (ídem con `HELM_BASEDIR`, por defecto `chart`); `detect_lang` (stdout: `maven|gradle|npm|pnpm`; usa `$LANG_OVERRIDE` si está; falla con `ERR: lenguaje no detectado` o `ERR: más de un lenguaje, usá --lang`).

- [ ] **Step 1: Escribir tests**: sin `.gitlab-ci.yml` → `develop` y `chart`; con `DEVELOP_BRANCH: "main"` → `main`; con `HELM_BASEDIR: helm` → `helm`; `pom.xml` → `maven`; `build.gradle.kts` → `gradle`; `package.json` + `pnpm-lock.yaml` → `pnpm`; solo `package.json` → `npm`; `pom.xml` + `package.json` → falla; con `LANG_OVERRIDE=npm` → `npm`; sin archivos → falla.
- [ ] **Step 2: Ejecutar** `sh tests/run.sh`. Esperado: FAIL.
- [ ] **Step 3: Implementar** las tres funciones; el valor se extrae con `awk` solo dentro del bloque `variables:` de primer nivel.
- [ ] **Step 4: Ejecutar** `sh tests/run.sh`. Esperado: `OK`.
- [ ] **Step 5: Commit** `Detección de rama de desarrollo, chart y lenguaje`.

### Task 3: Lectura y escritura de versiones

**Files:**
- Modify: `scripts/cephal-version`
- Test: `tests/test_versions.sh`

**Interfaces:**
- Consumes: `detect_lang`, `chart_dir`, `die`, `kv`.
- Produces: `get_version` (stdout: versión del proyecto; `ERR: versión no resoluble, definila a mano` si es dinámica); `set_version <nueva>`; `set_chart_app_version <nueva>` (si no existe `<chart_dir>/Chart.yaml`: `kv chart skipped` y retorna 0; si existe, deja `appVersion: "<nueva>"`, reemplazando la línea o agregándola al final).
- Maven: `<version>` del proyecto fuera de `<parent>` y de cualquier `<module>`; si existe `<revision>` en `<properties>`, esa es la versión. Gradle: `version` en `gradle.properties` o `build.gradle(.kts)` (comillas simples o dobles). npm/pnpm: campo `version` de `package.json`, primer nivel.

- [ ] **Step 1: Escribir tests**: leer y escribir en cada lenguaje; Maven con `<parent>` con otra versión (no se toca); Maven con `<revision>`; pom multi-módulo (solo el raíz); Gradle en `gradle.properties` y en `.kts`; `package.json` con `version` anidada en otra clave (no se toca); archivo con CRLF conserva CRLF (comparar bytes con `cmp`); `Chart.yaml` con `appVersion` entre comillas, sin comillas, ausente, y `Chart.yaml` inexistente → `chart=skipped`; versión dinámica → falla.
- [ ] **Step 2: Ejecutar** `sh tests/run.sh`. Esperado: FAIL.
- [ ] **Step 3: Implementar** con `awk` que escribe a un temporal y luego `mv`; el fin de línea se detecta con `grep -c "$(printf '\r')"` y se reaplica.
- [ ] **Step 4: Ejecutar** `sh tests/run.sh`. Esperado: `OK`.
- [ ] **Step 5: Commit** `Lectura y escritura de versión por lenguaje y appVersion`.

### Task 4: Semver y tags

**Files:**
- Modify: `scripts/cephal-version`
- Test: `tests/test_tags.sh`

**Interfaces:**
- Consumes: `die`.
- Produces: `semver_bump <x.y.z[-SNAPSHOT]> <patch|minor|major>` (stdout; conserva `-SNAPSHOT`; cualquier otro sufijo → `ERR: sufijo no soportado: <sufijo>`); `semver_gt <a> <b>` (retorna 0 si `a > b`, comparación numérica en `awk`); `last_final` (stdout: mayor tag final, o `0.0.0`); `open_rc_base` (stdout: mayor base con tag RC, sin tag final de esa base y mayor que `last_final`; vacío si no hay); `max_rc_n <base>` (stdout: mayor `n`, o `0`).

- [ ] **Step 1: Escribir tests**: `semver_bump 1.3.1-SNAPSHOT patch` → `1.3.2-SNAPSHOT`; `minor` → `1.4.0-SNAPSHOT`; `major 1.3.1` → `2.0.0`; `semver_bump 1.2.3-rc1 patch` falla; `semver_gt 2.10.0 2.9.0` verdadero; con tags `v1.0.0`, `release-1`, `2.4.0`, `2.9.0`, `2.10.0` → `last_final` = `2.10.0`; con `2.4.0`, `2.5.0-rc.1`, `2.5.0-rc.2` → `open_rc_base` = `2.5.0` y `max_rc_n 2.5.0` = `2`; al agregar `2.5.0` → `open_rc_base` vacío; RC `2.3.0-rc.1` con final `2.4.0` → ignorado; sin tags → `last_final` = `0.0.0`.
- [ ] **Step 2: Ejecutar** `sh tests/run.sh`. Esperado: FAIL.
- [ ] **Step 3: Implementar** filtrando `git tag --list` con `grep -E` y comparando con `awk` campo a campo.
- [ ] **Step 4: Ejecutar** `sh tests/run.sh`. Esperado: `OK`.
- [ ] **Step 5: Commit** `Cálculo de semver y detección de RC abierto`.

### Task 5: Subcomando next-tag

**Files:**
- Modify: `scripts/cephal-version`
- Test: `tests/test_next_tag.sh`

**Interfaces:**
- Consumes: `semver_bump`, `last_final`, `open_rc_base`, `max_rc_n`, `kv`, `die`.
- Produces: `cmd_next_tag <test|prod> [patch|minor|major]` → `kv tag <tag>`. `test`: con RC abierto, `<base>-rc.<n+1>` (el tipo se ignora); sin RC abierto, `<semver_bump last_final tipo>-rc.1`. `prod`: con RC abierto, `<base>` y además `kv rc_open yes` y `kv commits_since_rc <N>` (commits desde el último RC hasta `HEAD`); sin RC abierto, `<semver_bump last_final tipo>`. Falta de tipo cuando hace falta: `ERR: falta el tipo (patch|minor|major)`.

- [ ] **Step 1: Escribir tests**: sin tags, `test patch` → `0.0.1-rc.1`; con final `2.4.0`, `test minor` → `2.5.0-rc.1`; con `2.5.0-rc.1` → `test` → `2.5.0-rc.2` sin tipo; `prod` con `2.5.0-rc.2` y dos commits nuevos → `2.5.0`, `commits_since_rc=2`; `prod patch` sin RC y final `2.4.0` → `2.4.1`; `test` sin RC ni tipo → falla.
- [ ] **Step 2: Ejecutar** `sh tests/run.sh`. Esperado: FAIL.
- [ ] **Step 3: Implementar** `cmd_next_tag`.
- [ ] **Step 4: Ejecutar** `sh tests/run.sh`. Esperado: `OK`.
- [ ] **Step 5: Commit** `Subcomando next-tag`.

### Task 6: Subcomandos context y check

**Files:**
- Modify: `scripts/cephal-version`
- Test: `tests/test_check.sh`

**Interfaces:**
- Consumes: `develop_branch`, `chart_dir`, `detect_lang`, `get_version`, `last_final`, `open_rc_base`, `kv`, `die`.
- Produces: `cmd_context` → `kv` de `branch`, `develop_branch`, `lang`, `version`, `chart_dir`, `last_final` (`none` si no hay tags) y `open_rc` (base o `none`). `cmd_check` → falla con un `ERR:` específico si: HEAD desacoplado (`ERR: HEAD desacoplado, pasate a una rama`), rama sin upstream, árbol sucio, `HEAD` distinto de `origin/<rama>` tras `git fetch --tags origin`, identidad git ausente; si todo está bien imprime `kv check ok`.

- [ ] **Step 1: Escribir tests**: `context` en repo con pom y tag `2.4.0` imprime los ocho valores; `check` ok en repo limpio y sincronizado; falla con archivo sin commitear; falla con commit local sin pushear; falla en HEAD desacoplado (`git checkout --detach`); falla sin upstream; falla con `user.email` vacío.
- [ ] **Step 2: Ejecutar** `sh tests/run.sh`. Esperado: FAIL.
- [ ] **Step 3: Implementar** ambos subcomandos.
- [ ] **Step 4: Ejecutar** `sh tests/run.sh`. Esperado: `OK`.
- [ ] **Step 5: Commit** `Subcomandos context y check`.

### Task 7: Subcomandos bump y release-prep

**Files:**
- Modify: `scripts/cephal-version`
- Test: `tests/test_bump.sh`

**Interfaces:**
- Consumes: `develop_branch`, `get_version`, `set_version`, `set_chart_app_version`, `semver_bump`, `kv`, `die`.
- Produces: `cmd_bump <patch|minor|major|x.y.z>` → `kv from`, `kv to`; falla fuera de la rama de desarrollo con `ERR: estás en <rama>; el bump se hace en <develop>`; edita archivos y no commitea. `cmd_release_prep [--apply]` → `kv snapshot yes|no`; con `-SNAPSHOT` y sin `--apply` solo informa; con `--apply` quita el sufijo con `set_version` y `set_chart_app_version` y commitea con mensaje exacto `Release app <x.y.z>`.

- [ ] **Step 1: Escribir tests**: bump `patch` de `1.3.1-SNAPSHOT` → `1.3.2-SNAPSHOT` en pom y `appVersion` del chart, y `git status` muestra solo archivos modificados (sin commit nuevo); bump a versión explícita `3.0.0`; en rama `feature/x` falla; con `DEVELOP_BRANCH: main` en `.gitlab-ci.yml` bump corre en `main`; `release-prep` sin `--apply` no modifica nada; con `--apply` el commit tiene asunto `Release app 1.3.2`, cuerpo vacío y autor `Dev Test`; sin `-SNAPSHOT` → `snapshot=no`.
- [ ] **Step 2: Ejecutar** `sh tests/run.sh`. Esperado: FAIL.
- [ ] **Step 3: Implementar** ambos subcomandos.
- [ ] **Step 4: Ejecutar** `sh tests/run.sh`. Esperado: `OK`.
- [ ] **Step 5: Commit** `Subcomandos bump y release-prep`.

### Task 8: Subcomando tag-push

**Files:**
- Modify: `scripts/cephal-version`
- Test: `tests/test_tag_push.sh`

**Interfaces:**
- Consumes: `die`, `kv`.
- Produces: `cmd_tag_push <tag>` → valida formato (final o RC), que el tag no exista y que no haya cambios sin commitear; crea el tag anotado con mensaje igual al nombre y ejecuta `git push --atomic origin HEAD:refs/heads/<rama> refs/tags/<tag>`; `kv pushed <tag>`. Si el push falla, elimina el tag local y reporta el error.

- [ ] **Step 1: Escribir tests**: crea y pushea `2.5.0-rc.1` (el remoto lo tiene; `git cat-file -t` → `tag`); el mensaje del tag es `2.5.0-rc.1` y no contiene `Co-Authored`, `Claude` ni `cephal`; con un commit de release local adelantado, el push lleva commit y tag juntos; tag duplicado falla; formato inválido (`v1.0`) falla; si el remoto rechaza (hook `pre-receive` que sale 1), el tag local no queda.
- [ ] **Step 2: Ejecutar** `sh tests/run.sh`. Esperado: FAIL.
- [ ] **Step 3: Implementar** `cmd_tag_push`.
- [ ] **Step 4: Ejecutar** `sh tests/run.sh`. Esperado: `OK`.
- [ ] **Step 5: Commit** `Subcomando tag-push`.

### Task 9: Wrapper de PowerShell

**Files:**
- Create: `scripts/cephal-version.ps1`
- Test: `tests/test_wrapper.ps1`

**Interfaces:**
- Consumes: `scripts/cephal-version` (mismo directorio).
- Produces: `cephal-version.ps1 [args…]` → localiza el `bash.exe` de Git for Windows a partir de `git --exec-path` (`<raíz de Git>/bin/bash.exe`), ejecuta `bash <directorio>/cephal-version @args` y propaga stdout, stderr y el código de salida. Si no encuentra bash: `ERR: no se encontró bash de Git for Windows` con salida 1.

- [ ] **Step 1: Escribir `tests/test_wrapper.ps1`**: ejecuta el wrapper con `context` en un repo temporal y verifica `branch=`; ejecuta con un subcomando inexistente y verifica código 1.
- [ ] **Step 2: Ejecutar** `pwsh tests/test_wrapper.ps1`. Esperado: FAIL.
- [ ] **Step 3: Implementar** el wrapper.
- [ ] **Step 4: Ejecutar** `pwsh tests/test_wrapper.ps1`. Esperado: PASS (en Windows; en Linux y macos el test se omite con `exit 0`).
- [ ] **Step 5: Commit** `Wrapper de PowerShell`.

### Task 10: Skills, sincronía y manifiestos

**Files:**
- Create: `skills/bump-app-version/SKILL.md`, `skills/deploy-test/SKILL.md`, `skills/deploy-prod/SKILL.md`, `scripts/sync.sh`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
- Test: `tests/test_skills.sh`

**Interfaces:**
- Consumes: los subcomandos de las tasks 5 a 8.
- Produces: `scripts/sync.sh [--check]` (copia `scripts/cephal-version` y `scripts/cephal-version.ps1` a `skills/*/scripts/`; con `--check` no copia y sale 1 si alguna copia difiere). Cada `SKILL.md` lleva frontmatter `name` (igual al nombre del directorio) y `description` (una oración con cuándo usarla), y cuerpo con el flujo de la spec: pasos numerados, una pregunta al dev solo cuando hace falta, textos en español, ruta del script relativa a la skill (`scripts/cephal-version`, o `scripts/cephal-version.ps1` en PowerShell). `bump-app-version` termina sin commitear. `deploy-*` piden confirmación antes de `tag-push`, destacan el aviso de `-SNAPSHOT` y ofrecen `release-prep --apply`. `plugin.json`: `name: cephal`, `version: 0.1.0`, `license: MIT`. `marketplace.json`: `name: cephal-skills`, un plugin `cephal` con `source: ./`. Verificar el esquema vigente contra la documentación de Claude Code antes de fijarlo.

- [ ] **Step 1: Escribir `tests/test_skills.sh`**: por cada skill, `name` coincide con el directorio; el cuerpo tiene ≤ 60 líneas; `deploy-*` contienen `confirm`; `sh scripts/sync.sh --check` sale 0 tras `sync`, y sale 1 si se altera una copia; `plugin.json` y `marketplace.json` son JSON válido (`node -e` o `python -c` si hay, si no `grep` de las claves requeridas) y la versión de `plugin.json` es `0.1.0`.
- [ ] **Step 2: Ejecutar** `sh tests/run.sh`. Esperado: FAIL.
- [ ] **Step 3: Escribir** las tres skills, `sync.sh` y los manifiestos; ejecutar `sh scripts/sync.sh`.
- [ ] **Step 4: Ejecutar** `sh tests/run.sh`. Esperado: `OK`.
- [ ] **Step 5: Commit** `Skills, sincronía de scripts y manifiestos del plugin`.

### Task 11: CI, release y documentación

**Files:**
- Create: `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `README.md`, `CHANGELOG.md`

**Interfaces:**
- Consumes: `tests/run.sh`, `scripts/sync.sh --check`, `tests/test_wrapper.ps1`.
- Produces: `ci.yml` (en push y pull request; matriz `ubuntu-latest`, `macos-latest`, `windows-latest`; pasos: `sh tests/run.sh`, `sh scripts/sync.sh --check`, `pwsh tests/test_wrapper.ps1`; `shellcheck -s sh scripts/cephal-version scripts/sync.sh tests/*.sh` solo en ubuntu). `release.yml` (en tags `v*`: falla si el tag no coincide con `version` de `plugin.json`; crea el GitHub Release con las notas de la sección del `CHANGELOG.md`). `README.md`: requisitos (git; Git for Windows en Windows), instalación (comandos de la spec), uso de las tres skills en una línea cada una, y cómo versionar el propio repo. `CHANGELOG.md`: sección `0.1.0`.

- [ ] **Step 1: Escribir** los workflows, `README.md` y `CHANGELOG.md`.
- [ ] **Step 2: Verificar localmente** `sh tests/run.sh` y `sh scripts/sync.sh --check`. Esperado: `OK` y salida 0.
- [ ] **Step 3: Pushear la rama** (previa confirmación del dev) y verificar que `ci.yml` pasa en los tres sistemas operativos con `gh run watch`.
- [ ] **Step 4: Probar la instalación real** de Claude Code (`/plugin marketplace add` con el repo) y de `npx skills add` sobre una carpeta temporal; corregir el README con los comandos que funcionen y con la manera de fijar una versión.
- [ ] **Step 5: Commit** `CI, release y documentación`; tras confirmación del dev, tag `v0.1.0`.
