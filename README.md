# cephal-skills

Skills para agentes de código (Claude Code, Codex, OpenCode y otros) que ayudan a versionar la app y a desplegar por tags a test y prod en proyectos que usan los pipelines de la familia cephal.

| Skill | Qué hace |
|---|---|
| `bump-app-version` | Sube la versión de la app (pom, gradle, npm, pnpm) y alinea `appVersion` de `Chart.yaml`. Solo en la rama de desarrollo. No commitea. |
| `deploy-test` | Crea y pushea el tag `x.y.z-rc.n` (despliega a test). |
| `deploy-prod` | Crea y pushea el tag `x.y.z` (habilita prod). Puede salir sin RC previo. |

Nunca se pushea sin confirmación. Los commits y tags usan tu identidad git.

## Requisitos

- `git`. En Windows, Git for Windows (aporta `bash`).

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

## Uso

Desde la raíz del proyecto, pedile al agente `bump-app-version`, `deploy-test` o `deploy-prod` (en Claude Code: `cephal:bump-app-version`, etc.).

## Desarrollo

```
sh tests/run.sh               # pruebas
sh scripts/sync.sh            # copia el script a cada skill (tras editar scripts/)
sh scripts/sync.sh --check    # lo que verifica la CI
```

Diseño: `docs/superpowers/specs/`. Versiones: tags `vX.Y.Z` y `CHANGELOG.md`; la versión de `.claude-plugin/plugin.json` debe coincidir con el tag.
