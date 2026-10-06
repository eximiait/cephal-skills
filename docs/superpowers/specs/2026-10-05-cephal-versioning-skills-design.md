# Skills de versionado y despliegue de la familia cephal

## Objetivo

Que un desarrollador de un cliente de EximiaIT pueda subir la versión de su app y desplegar a test y a prod, desde su agente (Claude Code, Codex, OpenCode u otro), sin conocer las reglas del pipeline de `gitlab-pipelines`.

Alcance inicial: versionado y tags. Plugin `cephal` con tres skills:

| Skill | Invocación en Claude Code | Qué hace |
|---|---|---|
| `bump-app-version` | `cephal:bump-app-version` | Sube la versión de la app en el archivo del lenguaje y alinea `appVersion` de `Chart.yaml` |
| `deploy-test` | `cephal:deploy-test` | Crea y pushea el tag `x.y.z-rc.n` |
| `deploy-prod` | `cephal:deploy-prod` | Crea y pushea el tag `x.y.z` |

## Modelo de versionado que asumen (ya implementado en el pipeline)

- La versión de la app vive en `pom.xml`, `build.gradle(.kts)` / `gradle.properties` o `package.json`. Es el tag de la imagen.
- El **tag de git es la versión del chart**: `x.y.z-rc.n` despliega a test; `x.y.z` habilita test y luego prod (gate manual).
- El CI estampa `version` y `appVersion` del chart al publicar, por eso las skills **no editan `version` de `Chart.yaml`**. El `appVersion` del repo se alinea solo para evitar el aviso de `version-bump-check` y como fallback.
- Un tag exige que la versión de la app sea `x.y.z`: con `-SNAPSHOT` el pipeline falla.

## Decisiones

1. **Base del tag**: siguiente semver del chart. El dev elige `patch`, `minor` o `major` sobre el último tag final (sin tags: se parte de `0.0.0`). La versión de la app va aparte.
2. **RC abierto**: base con tag `-rc.n` sin tag final de esa base y mayor que el último final. `deploy-test` continúa con `rc.n+1` de la base abierta más alta, sin preguntar. `deploy-prod` toma esa base, crea el final sobre `HEAD` e informa cuántos commits hay desde el último RC.
3. **Prod sin RC**: permitido, sin confirmación extra; el dev elige el tipo. Un `x.y.z` pasa obligatoriamente por test.
4. **Validación**: solo git local. No se consulta registry ni estado del pipeline (`version-bump-check` es la red de seguridad).
5. **`-SNAPSHOT`**: `deploy-*` avisan de forma resaltada que no se puede pasar a testing con el sufijo y proponen quitarlo con un commit `Release app x.y.z` (archivo del lenguaje y `appVersion`), previa confirmación.
6. **Bump**: el dev elige tipo; se conserva `-SNAPSHOT` (`1.3.1-SNAPSHOT` → `1.3.2-SNAPSHOT`). Solo corre en la rama de desarrollo. Deja los cambios sin commitear ni pushear.
7. **Seguridad**: nunca se pushea sin confirmación explícita del dev. Commits y tags usan la identidad git del dev; no llevan trailers ni menciones al agente ni a cephal. El script nunca setea `user.name`/`user.email`.
8. **Tono**: salidas de una línea, sin explicaciones; preguntas solo ante una decisión real. Los textos de las skills están en español.

## Arquitectura

```
cephal-skills/
├─ .claude-plugin/{plugin.json, marketplace.json}
├─ skills/{bump-app-version,deploy-test,deploy-prod}/
│  ├─ SKILL.md
│  └─ scripts/{cephal-version, cephal-version.ps1}   # copia sincronizada
├─ scripts/{cephal-version, cephal-version.ps1}      # copia canónica
├─ tests/
├─ .github/workflows/{ci.yml, release.yml}
├─ .gitattributes                                    # eol=lf para scripts
├─ CHANGELOG.md
└─ README.md
```

Los instaladores multi-agente copian la carpeta de cada skill, por eso el script vive dentro de cada una. La copia canónica está en `scripts/`; un paso `sync` la replica y el CI falla si alguna copia difiere.

### Script `cephal-version` (POSIX sh estricto)

Solo usa utilidades presentes en Git for Windows, Linux y macOS (sin opciones exclusivas de GNU). El wrapper `cephal-version.ps1` ubica el `bash.exe` de Git for Windows a partir de `git --exec-path` y ejecuta el script con los mismos argumentos. Los `SKILL.md` indican usar el `.ps1` en PowerShell y el script directo en el resto.

Salida: líneas `clave=valor` en stdout para que el agente las muestre. Errores: `ERR: <causa>` en stderr y código de salida 1.

| Subcomando | Función |
|---|---|
| `context` | Rama actual, rama de desarrollo, lenguaje, versión de la app, directorio del chart, último tag final y RC abierto |
| `check` | Validaciones comunes de `deploy-*` (ver abajo) |
| `bump <patch\|minor\|major\|x.y.z>` | Edita el archivo del lenguaje y `appVersion`; falla fuera de la rama de desarrollo |
| `release-prep` | Si hay `-SNAPSHOT`, informa y, con `--apply`, quita el sufijo y commitea `Release app x.y.z` |
| `next-tag test [<tipo>]` | Calcula el `x.y.z-rc.n` (`rc.1` si no hay RC de esa base) |
| `next-tag prod [<tipo>]` | Calcula el `x.y.z` final |
| `tag-push <tag>` | Crea el tag anotado (mensaje = nombre del tag) y hace `git push --atomic origin HEAD:refs/heads/<rama> refs/tags/<tag>` |

`<tipo>` es obligatorio solo cuando no hay RC abierto.

**Detección** (por orden): `pom.xml` → Maven; `build.gradle` o `build.gradle.kts` → Gradle; `package.json` con `pnpm-lock.yaml` → pnpm; `package.json` → npm. Si hay más de uno, el script falla e indica `--lang`.

**Lectura y edición de la versión** (estática, sin ejecutar la herramienta de build):
- Maven: `<version>` del proyecto (fuera de `<parent>`) o la propiedad `<revision>` si existe.
- Gradle: `version` en `gradle.properties` o `build.gradle(.kts)`.
- npm/pnpm: campo `version` de `package.json`.
- Si la versión no se puede resolver de forma estática (por ejemplo, una variable externa), falla e indica definirla a mano.

**Rama de desarrollo**: `DEVELOP_BRANCH` en `variables:` del `.gitlab-ci.yml` raíz; por defecto `develop`.

**Directorio del chart**: `HELM_BASEDIR` del `.gitlab-ci.yml`; por defecto `chart`. Si no existe `Chart.yaml`, `bump` omite el `appVersion` y lo informa.

**Validaciones de `check`**: árbol de trabajo limpio; `HEAD` igual a `origin/<rama>` tras `git fetch --tags origin`; rama con upstream; tag inexistente; formato semver válido; identidad git configurada.

Tras `release-prep --apply`, `HEAD` queda un commit adelante de `origin`; `tag-push` empuja ese commit y el tag en una sola operación atómica, con una única confirmación.

## Flujo de cada skill

**`bump-app-version`**: `context`; si la rama no es la de desarrollo, informa y termina. Pregunta `patch/minor/major` mostrando versión actual → resultante. `bump`; muestra el diff; sugiere el mensaje de commit y no commitea.

**`deploy-test`**: `context` y `check`. `release-prep`: si hay `-SNAPSHOT`, aviso resaltado y, con confirmación, `--apply`. Sin RC abierto, pregunta el tipo. `next-tag test`. Muestra `Tag 2.5.0-rc.1 sobre a1b2c3d (rama)` y pide confirmación; con el sí, `tag-push`.

**`deploy-prod`**: igual, con `next-tag prod`. Con RC abierto informa los commits desde el último RC. Sin RC, pregunta el tipo y sigue sin confirmación adicional por falta de RC (la confirmación previa al push se mantiene).

## Distribución e instalación

- Repo público `EximiaIT/cephal-skills` (MIT).
- Claude Code: `/plugin marketplace add eximiait/cephal-skills` y `/plugin install cephal@cephal-skills`.
- Codex, OpenCode y otros: `npx skills add eximiait/cephal-skills -g -a codex -a opencode`.
- Rutas que leen los agentes: Claude Code `~/.claude/skills/`; Codex `~/.codex/skills/` o `.agents/skills/`; OpenCode `~/.config/opencode/skills/` o `.opencode/skills/`.
- Versionado: tags `vX.Y.Z`, `CHANGELOG.md` y la misma versión en `plugin.json`; `release.yml` crea el GitHub Release al pushear el tag.

## Pruebas

Casos con repos git temporales, ejecutados en GitHub Actions sobre ubuntu, macos y windows, junto con `shellcheck` y el chequeo de sincronía de copias:

- Sin tags; con RC abierto; `HEAD` adelantado respecto del último RC; final sin RC.
- Versión con `-SNAPSHOT` (aviso y `--apply`).
- Rama distinta de la de desarrollo; `DEVELOP_BRANCH` personalizada.
- Tag duplicado; árbol sucio; rama detrás de `origin`; identidad git ausente.
- Bump en Maven (versión directa y `<revision>`), Gradle, npm y pnpm; `Chart.yaml` presente y ausente.
- El commit y el tag no contienen trailers ni menciones al agente.

## Fuera de alcance

- Soporte de Python u otros lenguajes (se agrega un detector por lenguaje cuando haga falta).
- Consulta a la registry de imágenes o al estado del pipeline en GitLab.
- Otros skills de la familia `cephal` (el plugin queda preparado para sumarlos).

## Pendientes de verificar al implementar

- Esquema vigente de `plugin.json` y `marketplace.json` de Claude Code.
- Cómo fijar una versión concreta con `npx skills add` para documentarlo en el README.
- Que las rutas de skills de Codex y OpenCode coincidan con la documentación oficial (hoy se confirmaron solo con guías de terceros).
