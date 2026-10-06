# Changelog

## 0.3.0 - 2026-10-06

- `deploy-prod`: la versión de prod se decide en la rama de desarrollo y viaja en `Chart.yaml` por el MR; en `main` el tag es exactamente esa versión, así el chart y el tag siempre coinciden. Si `Chart.yaml` ya tiene una versión liberable, se usa sin preguntar.
- Nuevo subcomando `chart-prep [--apply] [tipo]`: calcula la versión del chart (RC abierto o tipo) y, con `--apply`, la escribe y commitea `Chart a x.y.z` (nunca en `main`).
- `next-tag prod`: con `Chart.yaml`, el tag es su `version` validada (x.y.z, mayor que el último final y sin tag existente); sin `Chart.yaml`, como antes.

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
