# Changelog

## 0.4.1 - 2026-10-07

- `bump-app-version` también deja en `Chart.yaml` la siguiente versión del chart cuando la actual ya fue liberada (pregunta el tipo): develop publicaba `1.0.0-develop-<sha>` aun después de liberar la 1.0.0, que por semver es anterior al release; ahora publica `1.1.0-develop-<sha>` y `deploy-prod` usa esa versión sin preguntar.
- Nuevo `chart-prep --write [tipo]`: escribe la versión del chart sin commitear (lo usa la skill; el diff lo muestra el `bump`).
- `flow` (y la skill `show-versioning-flow`) explica cuándo hacer el bump de versión: al cambiar código si la versión de la app ya se usó en un tag, un solo bump por ciclo, qué archivos sube, qué cambios no lo necesitan y que la versión del chart no se sube con el bump (es el tag).

## 0.4.0 - 2026-10-06

- Nueva skill `show-versioning-flow` (`/cephal:show-versioning-flow`): muestra en la terminal, en ASCII, el flujo de ramas y tags: qué pasa con un push a una feature o a `develop`, con un tag RC y con un tag final, y desde qué rama sale cada uno. Usa las ramas configuradas y marca el estado del repo (último final, RC abierto, rama actual).
- Nuevo subcomando `flow` en `cephal-version` (solo muestra, no cambia nada).

## 0.3.0 - 2026-10-06

- `deploy-prod`: la versión de prod se decide en la rama de desarrollo y viaja en `Chart.yaml` por el MR; en `main` el tag es exactamente esa versión, así el chart y el tag siempre coinciden. Si `Chart.yaml` ya tiene una versión liberable, se usa sin preguntar.
- Nuevo subcomando `chart-prep [--apply] [tipo]`: calcula la versión del chart (RC abierto o tipo) y, con `--apply`, la escribe y commitea `Chart a x.y.z` (nunca en `main`).
- `next-tag prod`: con `Chart.yaml`, el tag es su `version` validada (x.y.z, mayor que el último final y sin tag existente); sin `Chart.yaml`, como antes.
- `tag-push` y la validación de versión buscan el tag exacto en origin (`refs/tags/<tag>`) y, si no pueden consultarlo, fallan en lugar de asumir que no existe.
- `bump`, `release-prep --apply` y `chart-prep --apply` muestran la diff de lo que cambian (texto plano, formato fijo); las skills la presentan tal cual, coloreada como `git diff`, y se limitan a preguntas y una línea por resultado.
- README: sección de uso con ejemplos de cada skill (`docs/img/`, generados con `sh docs/img/generar.sh`).

## 0.2.0 - 2026-10-06

- `deploy-prod`: el tag de prod `x.y.z` solo sale desde la rama principal (`MAIN_BRANCH`, por defecto `main`). Desde la rama de desarrollo integra `develop` en `main` con un MR (`glab`) y, con el pipeline en verde, lo mergea antes de taguear.
- `deploy-test`: los RC `x.y.z-rc.n` salen desde cualquier rama excepto `main`.
- Los tags son inmutables: nunca se sobrescriben, mueven ni borran (sin `--force`).
- Sin `glab` o sin sesión iniciada, `deploy-prod` funciona en modo manual: indica los pasos del MR para que los haga el dev.
- `tag-push` de un tag final exige que `main` coincida con `origin/main`: nunca empuja a `main` commits que no llegaron por MR.
- `mr-merge` nunca borra la rama de desarrollo: pasa `--remove-source-branch=false` y se niega si el MR tiene activado "Delete source branch".
- `release-target` configura el upstream de `main` (`origin/main`) si la rama local no lo tiene, para que el tag final no falle al último paso.

## 0.1.0 - 2026-10-05

- Skills `bump-app-version`, `deploy-test` y `deploy-prod`.
- Script `cephal-version` (sh POSIX) con wrapper de PowerShell.
- Soporte de Maven, Gradle, npm y pnpm.
