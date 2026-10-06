# deploy-prod desde main Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que el tag `x.y.z` salga solo de la rama principal tras integrar develop por MR con CI en verde (vía `glab`, con modo manual), y que ningún flujo pise tags.

**Architecture:** Se agregan reglas de rama y subcomandos de GitLab a `scripts/cephal-version` (sh POSIX). Un extractor JSON por profundidad (`awk`) lee la salida de `glab -F json` sin `jq`. Las pruebas usan un `glab` falso en el `PATH`. La skill `deploy-prod` se reescribe como un flujo que se puede retomar.

**Tech Stack:** sh POSIX, awk, git, glab 1.93+, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-06-deploy-prod-desde-main-design.md` (amplía `2026-10-05-cephal-versioning-skills-design.md`).

## Global Constraints

- Todas las de la spec original: sh POSIX estricto, `shellcheck -s sh -S warning` limpio, LF, salida `clave=valor`, `ERR: <causa>` + código 1, commits y tags con la identidad del dev sin trailers, nunca pushear sin confirmación, `SKILL.md` ≤ 60 líneas en español.
- Rama principal: `MAIN_BRANCH` de `.gitlab-ci.yml`, por defecto `main`. Rama de desarrollo: `DEVELOP_BRANCH`, por defecto `develop`.
- Ningún script ni skill usa `--force`, `push -f` ni `tag -f`, ni ofrece borrar o mover un tag.
- `mr-create`: `--remove-source-branch=false --squash-before-merge=false --yes`, título `Release <develop> → <main>`. `mr-merge`: `--sha <sha> --auto-merge=false --yes`.
- Espera: intervalo `CEPHAL_POLL_SECONDS` (30), tramo máximo por llamada `CEPHAL_WAIT_STEP_SECONDS` (100), límite total de la skill `CEPHAL_WAIT_MINUTES` (20).
- Estados de pipeline `created|waiting_for_resource|preparing|pending|running|scheduled` → `running`; `head_pipeline: null` → `none`; el resto se informa tal cual.
- Después de editar `scripts/`, correr `sh scripts/sync.sh` (la CI verifica las copias).

## Review Focus

- `glab` sin sesión para el host de `origin` pero con sesión en otro host: debe quedar en `manual` (task 3).
- MR cerrado (no mergeado) mientras se espera el merge: `mr-wait … merged` debe terminar informando `state=closed`, no esperar hasta el límite (task 5).
- Local `main` con commits sin pushear al correr `release-target`: `pull --ff-only` puede fallar o el tag quedaría sobre un commit que no está en origin; debe fallar con `ERR:` (task 6).
- `origin` ssh con puerto (`ssh://git@host:2222/grupo/proyecto.git`): el link de MR debe usar `https://host/grupo/proyecto` (task 3).
- Respuesta de `glab` con un `status` o `iid` anidado antes del campo pedido: la extracción debe tomar el del nivel correcto (task 2).

---

### Task 1: Reglas de rama, push-branch y tags inmutables

**Files:**
- Modify: `scripts/cephal-version`, `tests/test_tag_push.sh`, `tests/test_hardening.sh`, `tests/test_next_tag.sh`, `tests/lib.sh`
- Test: `tests/test_branches.sh`

**Interfaces:**
- Consumes: `ci_var`, `current_branch`, `cmd_next_tag`, `cmd_tag_push`, `cmd_release_prep`, `cmd_context`.
- Produces: `main_branch` (stdout: `MAIN_BRANCH` o `main`); `assert_tag_branch <tag>` (final → rama actual = principal; RC → distinta; si no, `die` con los mensajes de la spec); `cmd_push_branch` (`git push origin HEAD:refs/heads/<rama>`, `kv pushed_branch <rama>`; falla en la principal y con HEAD desacoplado); `context` agrega `kv main_branch`. En `tests/lib.sh`: `new_repo` crea además la rama `main` en el mismo commit inicial, pusheada con upstream, y deja el checkout en `develop`.

- [ ] **Step 1: Escribir `tests/test_branches.sh`**: `next-tag prod patch` en develop → falla con `solo desde main`; en main → `tag=0.0.1`; `next-tag test patch` en main → falla con `un RC no sale de main`; `tag-push 1.0.0` en develop → falla; `tag-push 1.0.0-rc.1` en main → falla; con `MAIN_BRANCH: "master"` en `.gitlab-ci.yml`, prod en `master` funciona y en `main` falla; `release-prep --apply` en main con `-SNAPSHOT` → falla con `no se commitea` y no crea commit; `push-branch` en develop con un commit local → el remoto lo tiene; `push-branch` en main → falla; `context` incluye `main_branch=main`; un tag `3.0.0` creado solo en el remoto (desde otro clon) → `tag-push 3.0.0` en main falla con `ya existe` y `git ls-remote origin refs/tags/3.0.0` devuelve el mismo SHA que antes.
- [ ] **Step 2: Agregar a `tests/test_skills.sh`**: `grep -rE -- '--force|push -f|tag -f' scripts skills` no encuentra nada.
- [ ] **Step 3: Ejecutar** `sh tests/run.sh`. Esperado: FAIL en los casos nuevos (y en los existentes que crean tags finales desde develop).
- [ ] **Step 4: Implementar** las funciones; llamar a `assert_tag_branch` en `cmd_tag_push` tras validar el formato, y la regla de rama al inicio de `cmd_next_tag` y de `release-prep --apply`. Actualizar `new_repo` y mover a main los casos existentes que crean tags `x.y.z` (`test_tag_push.sh`, `test_hardening.sh`, casos `prod` de `test_next_tag.sh`).
- [ ] **Step 5: Ejecutar** `sh scripts/sync.sh && sh tests/run.sh`. Esperado: `OK`.
- [ ] **Step 6: Commit** `Reglas de rama: prod solo desde main, RC fuera de main; push-branch`.

### Task 2: Extractor JSON por profundidad

**Files:**
- Modify: `scripts/cephal-version`
- Create: `tests/fixtures/mr_view_running.json`, `tests/fixtures/mr_view_success.json`, `tests/fixtures/mr_view_failed.json`, `tests/fixtures/mr_view_nopipeline.json`, `tests/fixtures/mr_view_merged.json`, `tests/fixtures/mr_view_closed.json`, `tests/fixtures/mr_list_one.json`, `tests/fixtures/mr_list_empty.json`
- Test: `tests/test_json.sh`

**Interfaces:**
- Produces: `json_get <ruta>` (lee un JSON de una línea por stdin; `<ruta>` es `clave`, `clave.sub` o `0.clave` para el primer elemento de un arreglo; imprime el valor crudo: string sin comillas, número, `true`/`false`, o `null`; vacío si no existe). Solo mira claves del nivel indicado.
- Fixtures: una línea cada uno, con el orden de claves real de `glab mr view -F json` (`id, iid, …, state, …, author{…state…}, …, milestone{iid,state}, …, merge_user{…state…}, …, sha, …, web_url, …, pipeline{…sha,status}, head_pipeline{id,iid,project_id,status,…,sha}`), datos ficticios, y distractores con valores distintos al campo real: `milestone.iid=7`, `author.state="active"`, `pipeline.status="success"` cuando `head_pipeline.status` es otro, `head_pipeline.iid=39`, `head_pipeline.sha` distinto de `sha`. `mr_list_one.json` es un arreglo con un MR (`iid` 12); `mr_list_empty.json` es `[]`. `nopipeline` tiene `"head_pipeline":null`.

- [ ] **Step 1: Escribir `tests/test_json.sh`**: con `mr_view_running.json`, `json_get iid` → `12`, `json_get state` → `opened`, `json_get sha` → el top-level, `json_get head_pipeline.status` → `running`, `json_get web_url` → la URL; con `mr_view_nopipeline.json`, `json_get head_pipeline.status` → vacío y `json_get head_pipeline` → `null`; con `mr_list_one.json`, `json_get 0.iid` → `12`; con `mr_list_empty.json`, `json_get 0.iid` → vacío; un string con `\"` y `{` escapados dentro no rompe la profundidad.
- [ ] **Step 2: Ejecutar** `sh tests/test_json.sh`. Esperado: FAIL.
- [ ] **Step 3: Implementar `json_get`** con `awk` que recorre carácter a carácter: pila de profundidad por `{`/`[`, ignora el contenido de strings (con escapes), y cuando la clave del nivel buscado coincide con el siguiente segmento de la ruta, desciende o imprime el valor. Agregar los fixtures.
- [ ] **Step 4: Ejecutar** `sh tests/test_json.sh`. Esperado: 0 fallas.
- [ ] **Step 5: Commit** `Extractor JSON por profundidad y respuestas de ejemplo de glab`.

### Task 3: glab falso, gitlab-mode y mr-link

**Files:**
- Modify: `scripts/cephal-version`, `tests/lib.sh`
- Test: `tests/test_gitlab_mode.sh`

**Interfaces:**
- Produces (`tests/lib.sh`): `fake_glab` (crea `$T/bin/glab` y antepone `$T/bin` al `PATH`; registra cada invocación `"$*"` en `$T/glab.log`; responde según archivos en `$T/glab/`: `auth.rc` (código de `auth status`), `list.json`, `view.<n>.json` consumidos en orden y repitiendo el último, `create.out`, `merge.out` y `merge.rc`); `no_glab` (deja un `PATH` sin `glab`).
- Produces (script): `origin_web` (stdout `https://<host>/<ruta>` desde `origin` https, `git@host:ruta` o `ssh://git@host[:puerto]/ruta`, sin `.git`); `origin_host`; `cmd_gitlab_mode` (`kv gitlab glab|manual`, usando `glab auth status --hostname <origin_host>`); `cmd_mr_link` (`kv mr_link <origin_web>/-/merge_requests/new?merge_request[source_branch]=<develop>&merge_request[target_branch]=<main>`).

- [ ] **Step 1: Escribir tests**: sin glab → `gitlab=manual`; con `auth.rc` 0 → `gitlab=glab` y el log contiene `auth status --hostname gitlab.example.com`; con `auth.rc` 1 → `manual`; `mr-link` con origin `https://gitlab.example.com/g/p.git`, `git@gitlab.example.com:g/sub/p.git` y `ssh://git@gitlab.example.com:2222/g/p.git` → todos `https://gitlab.example.com/<ruta>/-/merge_requests/new?...develop...main`; con `DEVELOP_BRANCH: dev` y `MAIN_BRANCH: master` el link los usa.
- [ ] **Step 2: Ejecutar** `sh tests/test_gitlab_mode.sh`. Esperado: FAIL.
- [ ] **Step 3: Implementar** los helpers y subcomandos.
- [ ] **Step 4: Ejecutar** `sh scripts/sync.sh && sh tests/run.sh`. Esperado: `OK`.
- [ ] **Step 5: Commit** `gitlab-mode y mr-link`.

### Task 4: mr-find, mr-create y mr-status

**Files:**
- Modify: `scripts/cephal-version`
- Test: `tests/test_mr.sh`

**Interfaces:**
- Consumes: `json_get`, `fake_glab`, `develop_branch`, `main_branch`.
- Produces: `cmd_mr_find` (`glab mr list -s <develop> -t <main> -F json` → `kv mr_iid`, `kv mr_url`, o `kv mr none`); `cmd_mr_create` (comando exacto de la spec; extrae la última URL `https://…/-/merge_requests/<n>` de la salida → `kv mr_iid <n>`, `kv mr_url`; falla con la salida de glab si no hay URL); `pipeline_state <status>` (mapeo de la spec); `cmd_mr_status <iid>` (`glab mr view <iid> -F json` → `kv state`, `kv pipeline`, `kv sha`, `kv url`).

- [ ] **Step 1: Escribir tests**: `mr-find` con `mr_list_empty` → `mr=none`, con `mr_list_one` → `mr_iid=12` y la URL, y el log contiene `-s develop -t main -F json`; `mr-create` con `create.out` que trae una URL `…/merge_requests/12` → `mr_iid=12`, y el log contiene `--remove-source-branch=false`, `--squash-before-merge=false`, `--yes` y el título `Release develop → main`, y no contiene `--force`; `mr-create` con salida sin URL → falla; `mr-status 12` con cada fixture → `pipeline` = `running`, `success`, `failed`, `none`, y `state` = `opened`, `merged`, `closed`; `sha` es el de primer nivel, no el de `head_pipeline`.
- [ ] **Step 2: Ejecutar** `sh tests/test_mr.sh`. Esperado: FAIL.
- [ ] **Step 3: Implementar** los subcomandos.
- [ ] **Step 4: Ejecutar** `sh scripts/sync.sh && sh tests/run.sh`. Esperado: `OK`.
- [ ] **Step 5: Commit** `mr-find, mr-create y mr-status`.

### Task 5: mr-wait y mr-merge

**Files:**
- Modify: `scripts/cephal-version`
- Test: `tests/test_mr_wait.sh`

**Interfaces:**
- Consumes: `cmd_mr_status` (lógica reutilizada, no por subproceso), `fake_glab`.
- Produces: `cmd_mr_wait <iid> <pipeline|merged>` (consulta cada `CEPHAL_POLL_SECONDS`; corta cuando `pipeline` deja de ser `running` (modo pipeline) o `state` es `merged` o `closed` (modo merged), o al pasar `CEPHAL_WAIT_STEP_SECONDS`; imprime los `kv` de `mr-status` y `kv timeout yes|no`); `cmd_mr_merge <iid> <sha>` (comando exacto de la spec → `kv merged yes`; si glab falla, `die "no se pudo mergear: <salida de glab>"`).

- [ ] **Step 1: Escribir tests** (con `CEPHAL_POLL_SECONDS=0`): `view.1` running y `view.2` success → `mr-wait 12 pipeline` devuelve `pipeline=success` y `timeout=no`; siempre running con `CEPHAL_WAIT_STEP_SECONDS=0` → `timeout=yes`; modo merged con `view.1` opened y `view.2` merged → `state=merged`; con `view.1` closed → termina enseguida con `state=closed`; `mr-merge 12 abc123` → `merged=yes` y el log contiene `mr merge 12 --sha abc123 --auto-merge=false --yes` y no contiene `--squash`, `-d` ni `--remove-source-branch`; con `merge.rc` 1 y `merge.out` `approvals required` → falla y el error contiene `approvals required`.
- [ ] **Step 2: Ejecutar** `sh tests/test_mr_wait.sh`. Esperado: FAIL.
- [ ] **Step 3: Implementar** con un bucle `while` y `sleep "$CEPHAL_POLL_SECONDS"`, midiendo el tramo con `date +%s`.
- [ ] **Step 4: Ejecutar** `sh scripts/sync.sh && sh tests/run.sh`. Esperado: `OK`.
- [ ] **Step 5: Commit** `mr-wait y mr-merge`.

### Task 6: release-target

**Files:**
- Modify: `scripts/cephal-version`
- Test: `tests/test_release_target.sh`

**Interfaces:**
- Consumes: `develop_branch`, `main_branch`, `kv`, `die`.
- Produces: `cmd_release_target` (`git fetch --tags origin`; falla con `ERR: <main> no contiene <develop>: falta integrar el MR` si `origin/<develop>` no es ancestro de `origin/<main>`; falla con `hay cambios sin commitear`; hace `checkout <main>` y `pull --ff-only`; falla si `HEAD` difiere de `origin/<main>` después del pull (commits locales sin pushear); `kv branch`, `kv head`, y `kv tagged <x.y.z>` si `HEAD` ya tiene un tag final).

- [ ] **Step 1: Escribir tests**: develop con un commit que main no tiene → falla con `falta integrar el MR`; tras mergear develop en main en el remoto (desde otro clon) → `branch=main`, `head` igual a `origin/main` y el checkout quedó en main; con un tag `1.0.0` en ese commit → `tagged=1.0.0`; con un commit local en main sin pushear → falla; con archivo modificado → falla.
- [ ] **Step 2: Ejecutar** `sh tests/test_release_target.sh`. Esperado: FAIL.
- [ ] **Step 3: Implementar** `cmd_release_target`.
- [ ] **Step 4: Ejecutar** `sh scripts/sync.sh && sh tests/run.sh`. Esperado: `OK`.
- [ ] **Step 5: Commit** `release-target`.

### Task 7: Skills

**Files:**
- Modify: `skills/deploy-prod/SKILL.md`, `skills/deploy-test/SKILL.md`, `skills/bump-app-version/SKILL.md`, `tests/test_skills.sh`

**Interfaces:**
- Consumes: los subcomandos de las tasks 1 a 6.
- Produces: `deploy-prod` con el flujo de la spec (pasos 1 y 2, modo manual, espera repetida hasta `CEPHAL_WAIT_MINUTES`, pregunta "¿mergeo yo o lo hacés vos?", bloqueo de `-SNAPSHOT` en main, `ya liberado`); `deploy-test` con "en `<main_branch>` no se crean RC"; las tres con "Nunca muevas, borres ni sobrescribas un tag, ni ofrezcas `--force`; si el tag existe, informalo y terminá."

- [ ] **Step 1: Agregar a `tests/test_skills.sh`**: `deploy-prod` menciona `mr-find`, `mr-create`, `mr-wait`, `mr-merge`, `mr-link`, `release-target`, `gitlab-mode`, `push-branch` y `CEPHAL_WAIT_MINUTES`; `deploy-test` menciona `main_branch`; las tres contienen `sobrescribas`; el límite de 60 líneas se mantiene.
- [ ] **Step 2: Ejecutar** `sh tests/test_skills.sh`. Esperado: FAIL.
- [ ] **Step 3: Escribir** las skills.
- [ ] **Step 4: Ejecutar** `sh tests/run.sh`. Esperado: `OK`.
- [ ] **Step 5: Commit** `Skills: deploy-prod con MR de develop a main y tags inmutables`.

### Task 8: Documentación, versión y CI

**Files:**
- Modify: `README.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `tests/test_skills.sh`, `tests/test_release.sh`, `.github/workflows/ci.yml`

**Interfaces:**
- Produces: versión `0.2.0` en los dos manifiestos; `CHANGELOG.md` sección `0.2.0` (prod solo desde main vía MR, RC fuera de main, tags inmutables, modo manual sin glab); README con `glab` opcional y el flujo de prod; `test_skills.sh` y `test_release.sh` esperan `0.2.0`; `shellcheck` de la CI incluye los tests nuevos (ya cubiertos por `tests/*.sh`).

- [ ] **Step 1: Actualizar** los tests de versión a `0.2.0` y ejecutar `sh tests/run.sh`. Esperado: FAIL en versión.
- [ ] **Step 2: Actualizar** manifiestos, CHANGELOG y README.
- [ ] **Step 3: Ejecutar** `sh tests/run.sh`, `sh scripts/sync.sh --check`, `sh scripts/check-version.sh v0.2.0` y `shellcheck` (docker) con los parámetros de la CI. Esperado: todo en 0.
- [ ] **Step 4: Commit** `Versión 0.2.0: documentación y changelog`.
- [ ] **Step 5: Pushear la rama** y verificar la CI en ubuntu, macos y windows con `gh run watch`; con todo en verde, fast-forward de `main` y push. El tag `v0.2.0` solo a pedido del dev.
