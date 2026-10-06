# Versión del chart coherente con el tag de prod (v0.3.0)

Amplía `2026-10-06-deploy-prod-desde-main-design.md`. El resto sigue vigente.

## Objetivo

Que el `Chart.yaml` de la rama principal tenga siempre `version` igual al último tag de prod. La versión se decide en la rama de desarrollo y llega a `main` por el MR; nunca se commitea en `main`.

Fuera de alcance: RC y `deploy-test` (no tocan `Chart.yaml`), `appVersion` (lo maneja `bump-app-version`), y el pipeline (sigue tomando la versión del chart desde el tag).

## Decisiones

1. El tag de prod en `main` es exactamente la `version` de `Chart.yaml` (validada). No hay un segundo cálculo en `main`.
2. Si `Chart.yaml` ya tiene una versión liberable (`x.y.z`, mayor que el último tag final y sin tag), se usa sin preguntar: retomar una corrida no repite preguntas ni commits, y el dev puede fijar la versión editando el archivo.
3. Repos sin `Chart.yaml`: comportamiento actual (la versión se calcula en `main`).

## Script

Directorio del chart: `HELM_BASEDIR` del `.gitlab-ci.yml` (por defecto `chart`), como en `bump`.

| Subcomando | Comportamiento |
|---|---|
| `chart-prep [tipo]` | Sin `Chart.yaml`: `chart=skipped`. Si `version` es liberable: `version=<x.y.z>`, `changed=no`. Si no: calcula la versión (base del RC abierto; si no hay, `semver_bump <último final> <tipo>`; sin RC y sin tipo: `ERR: falta el tipo (patch\|minor\|major)`) y devuelve `version=<x.y.z>`, `changed=yes`. No modifica nada. |
| `chart-prep --apply [tipo]` | Lo mismo; con `changed=yes` escribe `version` en `Chart.yaml` (conserva comillas, CRLF y la falta de salto final) y commitea con mensaje exacto `Chart a <x.y.z>`; agrega `committed=yes`. Falla en la rama principal (`ERR: en <main> no se commitea: …`, como `release-prep`) y con cambios sin commitear. Con `changed=no` no escribe ni commitea. |
| `next-tag prod` | Con `Chart.yaml`: `tag=<version>` si es `x.y.z`, mayor que el último final y sin tag local ni remoto; si no, `ERR:` que explica cuál de las tres falla y que la versión se decide en develop con `chart-prep`. No pide tipo; un tipo pasado se ignora. Mantiene `head`, `rc_open` y `commits_since_rc`. Sin `Chart.yaml`: como hoy. |

`version` en `Chart.yaml`: línea de primer nivel `version:` (con o sin comillas). Si falta, `chart-prep --apply` la agrega.

## Skill deploy-prod

- *Preparar* (en la rama de desarrollo, antes de `mr-create` o del modo manual), después de `release-prep`: `CV chart-prep`.
  - `chart=skipped`: nada.
  - `changed=no`: informar `Versión a liberar: <version> (ya en Chart.yaml)`.
  - `changed=yes`: si falla con `falta el tipo`, preguntar `¿patch, minor o major sobre <last_final>?` y repetir con el tipo. Ofrecer `CV chart-prep --apply [tipo]` + `CV push-branch` con una sola confirmación (junto con la del `-SNAPSHOT` si también aplica). Si no acepta, terminar.
- Paso 6 en `main`: `CV next-tag prod`; con `Chart.yaml` no se pregunta el tipo. Si falla, mostrar el error y terminar (la versión se corrige en develop y se integra por MR).

## Pruebas

- `chart-prep`: sin `Chart.yaml`; versión liberable → `changed=no`; versión igual al último final → calcula; RC abierto → base del RC; por tipo; sin RC ni tipo → falla; no modifica archivos.
- `chart-prep --apply`: escribe y commitea `Chart a x.y.z` (mensaje exacto, autor el dev); conserva comillas y CRLF; agrega `version` si falta; falla en `main`; falla con árbol sucio; con `changed=no` no commitea.
- `next-tag prod` con `Chart.yaml`: válido → ese tag sin tipo; menor o igual al último final → falla; ya tagueado → falla; no `x.y.z` (p. ej. `0.0.0-SNAPSHOT` o `1.2`) → falla. Sin `Chart.yaml` → comportamiento actual (los tests existentes siguen pasando).
- `test_skills.sh`: deploy-prod menciona `chart-prep` y `Versión a liberar`.

## Documentación y versión

README (flujo de prod: la versión se decide en develop y viaja en `Chart.yaml`), `CHANGELOG.md` `0.3.0` y manifiestos en `0.3.0`; el tag `v0.3.0` solo a pedido del dev.
