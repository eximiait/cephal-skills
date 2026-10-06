# cephal-skills

Skills para agentes de código (Claude Code, Codex, OpenCode y otros) que ayudan a versionar la app y a desplegar por tags a test y prod en proyectos que usan los pipelines de la familia cephal.

| Skill | Qué hace |
|---|---|
| `bump-app-version` | Sube la versión de la app (pom, gradle, npm, pnpm) y alinea `appVersion` de `Chart.yaml`. Solo en la rama de desarrollo. No commitea. |
| `deploy-test` | Crea y pushea el tag `x.y.z-rc.n` (despliega a test). No corre en `main`. |
| `deploy-prod` | Integra `develop` en `main` por MR y crea el tag `x.y.z` en `main` (habilita prod). Puede salir sin RC previo. |

Nunca se pushea sin confirmación. Los commits y tags usan tu identidad git.

## Requisitos

- `git`. En Windows, Git for Windows (aporta `bash`).
- `glab` (opcional), con sesión iniciada. Sin `glab` o sin sesión iniciada, `deploy-prod` funciona en modo manual: indica los pasos del MR para que los haga el dev.

## Instalación

Claude Code:

```
/plugin marketplace add eximiait/cephal-skills
/plugin install cephal@cephal-skills
```

Codex, OpenCode y otros agentes (copia las skills al directorio de cada agente):

```
npx skills add eximiait/cephal-skills -g -a codex -a opencode
```

Actualizar: `/plugin marketplace update cephal-skills` (Claude Code) o `npx skills update` (los demás). El instalador `npx skills` no documenta un flag para fijar versión; para fijarla, copiá `skills/` desde el tag `vX.Y.Z` del repo.

## Uso

Desde la raíz del proyecto, pedile al agente `bump-app-version`, `deploy-test` o `deploy-prod` (en Claude Code: `cephal:bump-app-version`, etc.).

## Flujo de prod

1. `deploy-prod` desde `develop`: crea el MR `develop` → `main`.
2. Con el CI del MR en verde, se mergea (sin squash y sin borrar `develop`).
3. Se crea y pushea el tag `x.y.z` en `main`, sobre el mismo commit que `origin/main`.

Modo manual (sin `glab` o sin sesión iniciada): `deploy-prod` indica los pasos del MR para que los haga el dev (te da el link para abrirlo); cuando avisás que está mergeado, sigue con el tag.

Mientras corre el pipeline del MR, la skill espera hasta `CEPHAL_WAIT_MINUTES` minutos (por defecto 20); si no termina, volvé a correr `deploy-prod`: retoma donde quedó.

`develop` y `main` son configurables con `DEVELOP_BRANCH` y `MAIN_BRANCH` en el bloque `variables:` del `.gitlab-ci.yml`.

El tag de prod solo sale desde `main`; `deploy-test` no corre ahí. Los tags nunca se sobrescriben ni se mueven.

## Desarrollo

```
sh tests/run.sh               # pruebas
sh scripts/sync.sh            # copia el script a cada skill (tras editar scripts/)
sh scripts/sync.sh --check    # lo que verifica la CI
```

Diseño: `docs/superpowers/specs/`. Versiones: tags `vX.Y.Z` y `CHANGELOG.md`; la versión de `.claude-plugin/plugin.json` debe coincidir con el tag.
