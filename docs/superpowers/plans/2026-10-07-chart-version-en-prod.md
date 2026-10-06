# Versión del chart en prod Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que la versión del chart se decida en develop, viaje en `Chart.yaml` por el MR y sea el tag de prod en `main`.

**Architecture:** Helpers nuevos en `scripts/cephal-version` para leer, validar y escribir `version` de `Chart.yaml`; un subcomando `chart-prep [--apply] [tipo]`; `next-tag prod` usa la versión de `Chart.yaml` cuando existe. La skill `deploy-prod` suma el paso en *Preparar*.

**Tech Stack:** sh POSIX, awk, git.

**Spec:** `docs/superpowers/specs/2026-10-07-chart-version-en-prod-design.md`

## Global Constraints

- Las de siempre: sh POSIX estricto (dash/mawk, macOS, Git for Windows; sin rangos de letras en `case`/`grep`), `shellcheck -s sh -S warning` limpio, `awk -v BINMODE=3` en los `awk` que leen/escriben archivos del usuario, ediciones con `rewrite` (conserva CRLF y la falta de salto final), salida `clave=valor`, `ERR:` + código 1, después de editar `scripts/` correr `sh scripts/sync.sh`.
- Commit de `chart-prep --apply`: mensaje exacto `Chart a <x.y.z>`, identidad del dev, sin trailers.
- `chart-prep --apply` en la rama principal: mismo mensaje que `release-prep --apply` (`en <main> no se commitea: …`).
- Versión liberable = `x.y.z` (sin sufijo), mayor que `last_final` y sin tag local ni remoto (`git ls-remote --exit-code --tags origin <v>`).
- RC y `deploy-test` no cambian. Sin `Chart.yaml`, `next-tag prod` se comporta como hoy.
- `SKILL.md` ≤ 60 líneas, español conciso.

## Review Focus

- `Chart.yaml` con `version: "1.2.0"` entre comillas: se lee sin comillas y al escribir se conservan (task 1).
- `Chart.yaml` en un `HELM_BASEDIR` distinto de `chart`: `chart-prep` y `next-tag prod` usan ese directorio (task 1 y 2).
- `Chart.yaml` con CRLF: `--apply` no lo convierte a LF (task 1).
- Tag que existe solo en el remoto: la versión no es liberable (`chart-prep` calcula otra; `next-tag prod` falla con `ya existe`) (task 1 y 2).
- `version` con prefijo o ceros raros (`v1.2.0`, `1.02.0`): no es liberable; `chart-prep` calcula una nueva y `next-tag prod` falla explicando que no es `x.y.z` (task 1 y 2).

---

### Task 1: chart-prep

**Files:**
- Modify: `scripts/cephal-version`
- Test: `tests/test_chart_prep.sh`

**Interfaces:**
- Consumes: `chart_dir`, `last_final`, `open_rc_base`, `semver_bump`, `semver_gt`, `main_branch`, `current_branch`, `rewrite`, `kv`, `die`.
- Produces:
  - `chart_version_get` → stdout: `version` de primer nivel de `<chart_dir>/Chart.yaml` sin comillas (vacío si no hay línea); retorna 1 si no existe el archivo.
  - `chart_version_problem <v>` → stdout: vacío si `<v>` es liberable; si no, una de: `<v> no es x.y.z`, `<v> no es mayor que el último final (<last_final>)`, `ya existe el tag <v>`. (`x.y.z` = `^[0-9]+\.[0-9]+\.[0-9]+$` sin ceros a la izquierda en ningún componente salvo `0`.)
  - `chart_version_set <v>` → reescribe la línea `version:` conservando el estilo de comillas y el fin de línea, o la agrega al final si falta.
  - `cmd_chart_prep [--apply] [tipo]` → `chart=skipped` | `version=<v>` + `changed=no|yes` (+ `committed=yes` con `--apply` y cambio).

- [ ] **Step 1: Escribir `tests/test_chart_prep.sh`**: sin `Chart.yaml` → `chart=skipped`; `version: 2.5.0` con último final `2.4.0` → `version=2.5.0` y `changed=no`; `version: 2.4.0` (igual al final) con tag `2.5.0-rc.1` abierto → `version=2.5.0`, `changed=yes`; `version: 2.4.0` sin RC y `minor` → `version=2.5.0`, `changed=yes`; sin RC ni tipo → falla con `falta el tipo`; `chart-prep` sin `--apply` no modifica archivos; `version: "2.4.0"` + `--apply minor` → la línea queda `version: "2.5.0"` y el commit tiene asunto `Chart a 2.5.0`, cuerpo vacío, autor `Dev Test`; Chart.yaml con CRLF conserva CRLF (comparar con `cmp`); sin línea `version:` → `--apply patch` la agrega; `--apply` en `main` falla con `no se commitea`; `--apply` con un archivo modificado falla con `cambios sin commitear`; con `changed=no`, `--apply` no crea commit; `HELM_BASEDIR: helm` en `.gitlab-ci.yml` → usa `helm/Chart.yaml`; `version: v2.5.0` → no liberable (calcula otra); `version: 2.5.0` con tag `2.5.0` solo en el remoto (creado desde otro clon) → no liberable.
- [ ] **Step 2: Ejecutar** `sh tests/test_chart_prep.sh`. Esperado: FAIL (subcomando inexistente).
- [ ] **Step 3: Implementar** los helpers y `cmd_chart_prep`. `--apply`: validar rama y árbol limpio antes de escribir; commitear con `git commit -q -a -m "Chart a <v>"`.
- [ ] **Step 4: Ejecutar** `sh scripts/sync.sh && sh tests/run.sh`. Esperado: `OK`.
- [ ] **Step 5: Commit** `chart-prep: versión del chart decidida en develop`.

### Task 2: next-tag prod desde Chart.yaml

**Files:**
- Modify: `scripts/cephal-version` (`cmd_next_tag`)
- Test: `tests/test_next_tag.sh`

**Interfaces:**
- Consumes: `chart_version_get`, `chart_version_problem` (task 1).
- Produces: `cmd_next_tag prod` → con `Chart.yaml`: `tag=<version de Chart.yaml>` (más `head`, y `rc_open`/`commits_since_rc` si hay RC abierto de esa base), sin pedir tipo; si `chart_version_problem` devuelve algo: `ERR: <problema>; la versión de prod se decide en develop con chart-prep`. Sin `Chart.yaml`: igual que hoy.

- [ ] **Step 1: Agregar casos a `tests/test_next_tag.sh`** (en `main`, con `chart/Chart.yaml` commiteado): `version: 2.5.0` y final `2.4.0` → `tag=2.5.0` sin pasar tipo; con `next-tag prod major` igual `tag=2.5.0` (el tipo se ignora); `version: 2.4.0` → falla con `no es mayor que el último final (2.4.0)`; `version: 2.5.0` con tag `2.5.0` → falla con `ya existe el tag 2.5.0`; `version: 0.0.0-SNAPSHOT` → falla con `no es x.y.z`; con RC `2.5.0-rc.1` y dos commits nuevos → `tag=2.5.0`, `rc_open=yes`, `commits_since_rc=2`. Los casos existentes (sin `Chart.yaml`) no cambian.
- [ ] **Step 2: Ejecutar** `sh tests/test_next_tag.sh`. Esperado: FAIL en los casos nuevos.
- [ ] **Step 3: Implementar** la rama de `Chart.yaml` en `cmd_next_tag prod` (después de la regla de rama).
- [ ] **Step 4: Ejecutar** `sh scripts/sync.sh && sh tests/run.sh`. Esperado: `OK`.
- [ ] **Step 5: Commit** `next-tag prod: el tag es la versión de Chart.yaml`.

### Task 3: Skill, documentación y versión 0.3.0

**Files:**
- Modify: `skills/deploy-prod/SKILL.md`, `tests/test_skills.sh`, `tests/test_release.sh`, `README.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

**Interfaces:**
- Consumes: `chart-prep` y `next-tag prod` (tasks 1 y 2).

- [ ] **Step 1: Tests primero**: en `test_skills.sh`, deploy-prod contiene `chart-prep` y `Versión a liberar`; versión esperada de `plugin.json` `0.3.0`; en `test_release.sh` el caso positivo usa `v0.3.0` y el negativo un tag distinto. Ejecutar `sh tests/run.sh`. Esperado: FAIL en esas aserciones.
- [ ] **Step 2: SKILL.md**: en *Preparar*, después de `release-prep`: `CV chart-prep` con las tres salidas de la spec (`chart=skipped`; `changed=no` → `Versión a liberar: <version> (ya en Chart.yaml)`; `changed=yes` → tipo si hace falta, `CV chart-prep --apply [tipo]` + `CV push-branch` con una sola confirmación junto con la del `-SNAPSHOT`; si no acepta, terminar). Paso 6: con `Chart.yaml`, `CV next-tag prod` sin preguntar tipo; si falla, mostrar el error y terminar. Mantener ≤ 60 líneas y las frases que ya chequea `test_skills.sh`.
- [ ] **Step 3: README** (flujo de prod: la versión se decide en develop y viaja en `Chart.yaml`), `CHANGELOG.md` sección `## 0.3.0 - <fecha>` y ambos manifiestos en `0.3.0`.
- [ ] **Step 4: Ejecutar** `sh tests/run.sh`, `sh scripts/sync.sh --check` y `sh scripts/check-version.sh v0.3.0`. Esperado: `OK`, 0 y 0.
- [ ] **Step 5: Commit** `deploy-prod: la versión del chart viaja por el MR (0.3.0)`; push de la rama, CI verde en ubuntu/macos/windows y fast-forward de `main`. El tag `v0.3.0` solo a pedido del dev.
