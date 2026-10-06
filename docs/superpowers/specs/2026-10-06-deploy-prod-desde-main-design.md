# deploy-prod desde main con MR de develop (v0.2.0)

Amplía `2026-10-05-cephal-versioning-skills-design.md`. Reemplaza sus decisiones 3 y 4; el resto sigue vigente.

## Objetivo

Que el tag `x.y.z` (prod) salga únicamente de la rama principal, después de integrar `develop` por MR con su CI en verde, y que ningún flujo pise un tag existente.

## Reglas de ramas (validadas en el script, no solo en las skills)

- Rama principal: `MAIN_BRANCH` de `variables:` del `.gitlab-ci.yml` raíz; por defecto `main`.
- `next-tag prod` y `tag-push` de un tag `x.y.z` solo en la rama principal: `ERR: deploy a prod solo desde <main>; estás en <rama>`.
- `next-tag test` y `tag-push` de un tag `x.y.z-rc.n` en cualquier rama menos la principal: `ERR: un RC no sale de <main>`.
- `release-prep --apply` nunca en la rama principal: `ERR: en <main> no se commitea: quitá -SNAPSHOT en otra rama y mergealo por MR`.
- `context` informa además `main_branch`.

## Nunca pisar tags

- Ningún script ni skill usa `--force`, `push -f` ni `tag -f`, ni ofrece borrar o mover un tag.
- `tag-push` rechaza un tag que exista local o remotamente y no lo modifica. Si el push falla, solo borra el tag local que acaba de crear.
- Si el tag existe, la skill lo informa y termina.

## Flujo de deploy-prod

Cada corrida detecta en qué paso quedó y continúa; retomarla nunca duplica MR ni tag. Se corre desde la rama de desarrollo o desde la principal; en otra rama informa y termina.

1. `git fetch`. Si `origin/<develop>` no está contenido en `origin/<main>` (`merge-base --is-ancestor`), hay cambios por integrar:
   - Requiere estar en la rama de desarrollo; si no, `pasate a <develop>` y termina.
   - Sin MR abierto de develop a main: `check`; si hay `-SNAPSHOT`, aviso resaltado, y con confirmación `release-prep --apply` y `push-branch`; luego, con confirmación, `mr-create`.
   - Con MR abierto, según `pipeline`:
     - `running`: `mr-wait` en tramos hasta el límite total.
     - `failed`, `canceled`, `skipped` o `manual`: muestra estado y link, y termina.
     - `none` (sin pipeline): lo informa; solo el dev puede mergear.
     - `success`: pregunta si mergea la skill o el dev. Si la skill: confirmación y `mr-merge`. Si el dev: `mr-wait … merged`.
2. Con develop contenido en main: `release-target` (checkout de main y `pull --ff-only`). Si `HEAD` ya tiene un tag `x.y.z`: `ya liberado: <tag>` y termina. Si `release-prep` informa `snapshot=yes`: aviso resaltado de que así no se puede liberar y de que el sufijo se quita en develop y se integra por MR; termina sin commitear. Si no: `next-tag prod` (cierra el RC abierto o pregunta el tipo), confirmación y `tag-push`.

**Modo manual** (sin `glab` o sin sesión): en lugar de crear y seguir el MR, `mr-link` da el link para crearlo; el dev avisa cuando está mergeado; `release-target` verifica con git y se sigue con el paso 2.

**Espera**: `mr-wait` consulta cada 30 s y vuelve en ~100 s como máximo (los agentes cortan comandos largos). La skill la repite hasta `CEPHAL_WAIT_MINUTES` (por defecto 20); al vencer: `volvé a correr deploy-prod cuando termine`. No se espera el pipeline de main tras el merge: el del tag vuelve a correr build, tests y scans antes del deploy manual a prod.

**Merge seguro**: merge commit (sin squash), nunca borra la rama de desarrollo, solo con el pipeline del MR en `success`, solo el SHA validado (`--sha`), sin auto-merge. Si GitLab exige aprobaciones pendientes, informa el motivo y lo deja al dev.

## Subcomandos nuevos

Salida `clave=valor`; errores `ERR:` y código 1. `<develop>` y `<main>` salen de `.gitlab-ci.yml`.

| Subcomando | Función |
|---|---|
| `gitlab-mode` | `gitlab=glab` si `glab` está y `glab auth status --hostname <host de origin>` pasa; si no, `gitlab=manual` |
| `mr-find` | MR abierto de develop a main: `mr_iid`, `mr_url`; o `mr=none` |
| `mr-create` | `glab mr create -s <develop> -b <main> -t "Release <develop> → <main>" -d "" --remove-source-branch=false --squash-before-merge=false --yes` → `mr_iid`, `mr_url` |
| `mr-status <iid>` | `state` (opened/merged/closed), `pipeline` (running/success/failed/canceled/skipped/manual/none), `sha`, `url` |
| `mr-wait <iid> <pipeline\|merged>` | Repite `mr-status` hasta que el pipeline salga de `running` o el MR quede `merged`, o vence el tramo (`timeout=yes`) |
| `mr-merge <iid> <sha>` | `glab mr merge <iid> --sha <sha> --auto-merge=false --yes` → `merged=yes`; si falla, `ERR:` con el motivo de glab |
| `mr-link` | URL `https://<host>/<proyecto>/-/merge_requests/new?merge_request[source_branch]=<develop>&merge_request[target_branch]=<main>` desde `origin` https o ssh |
| `push-branch` | `git push origin HEAD:refs/heads/<rama>` (sin force), solo fuera de la rama principal |
| `release-target` | Falla si `origin/<main>` no contiene `origin/<develop>`; si lo contiene: árbol limpio, `checkout <main>`, `pull --ff-only`; informa `head` y `tagged=<x.y.z>` si existe |

Los estados de pipeline `created`, `waiting_for_resource`, `preparing`, `pending`, `running` y `scheduled` se informan como `running`. Los campos se extraen del JSON de `glab -F json` con `awk` (sin `jq`): `iid`, `state`, `web_url`, `sha` y `head_pipeline.status` (`head_pipeline: null` → `none`).

`deploy-test` no cambia salvo la regla de no correr en la rama principal.

## Pruebas

Un `glab` falso en el `PATH` devuelve JSON con la forma real (tomada de un `glab mr view -F json` de solo lectura) y registra sus argumentos. Los intervalos de espera son configurables por variables para que las pruebas no esperen.

- `gitlab-mode`: sin glab, con sesión, sin sesión.
- `mr-find`, `mr-status`, `mr-wait`: sin MR; pipeline `running` que pasa a `success`; `failed`; `head_pipeline: null`; vencimiento del tramo.
- `mr-create` y `mr-merge`: los argumentos incluyen `--remove-source-branch=false`, `--squash-before-merge=false`, `--auto-merge=false` y `--sha`, y nunca `--force`, `-d`, `--squash` ni `--remove-source-branch` en `true`; rechazo por aprobaciones → `ERR:` con el motivo.
- `mr-link`: origin https y ssh, con y sin `.git`.
- `release-target`: develop no contenido → falla; contenido → queda en main actualizado; tag existente → `tagged=`.
- Reglas de ramas: prod fuera de main, RC en main, `tag-push` de cada tipo en la rama equivocada, `release-prep --apply` en main, `push-branch` en main, `MAIN_BRANCH` personalizado.
- Tags: un tag existente solo en el remoto se rechaza y sigue apuntando al mismo commit; scripts y skills no contienen `--force`, `push -f` ni `tag -f`.
- Las pruebas existentes que crean tags `x.y.z` desde develop pasan a hacerlo desde main.

## Documentación y versión

- README: `glab` como requisito opcional (sin él, modo manual) y el flujo de prod.
- `CHANGELOG.md` y manifiestos en `0.2.0`; el tag `v0.2.0` se crea solo a pedido del dev.

## Fuera de alcance

- Esperar el pipeline de main después del merge.
- Resolver aprobaciones o conflictos del MR (se informan y quedan para el dev).
- Integrar desde una rama distinta de la de desarrollo.
