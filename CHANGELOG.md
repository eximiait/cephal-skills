# Changelog

## 0.2.0 - 2026-10-06

- `deploy-prod`: el tag de prod `x.y.z` solo sale desde la rama principal (`MAIN_BRANCH`, por defecto `main`). Desde la rama de desarrollo integra `develop` en `main` con un MR (`glab`) y, con el pipeline en verde, lo mergea antes de taguear.
- `deploy-test`: los RC `x.y.z-rc.n` salen desde cualquier rama excepto `main`.
- Los tags son inmutables: nunca se sobrescriben, mueven ni borran (sin `--force`).
- Sin `glab` o sin sesión iniciada, `deploy-prod` funciona en modo manual: indica los pasos del MR para que los haga el dev.

## 0.1.0 - 2026-10-05

- Skills `bump-app-version`, `deploy-test` y `deploy-prod`.
- Script `cephal-version` (sh POSIX) con wrapper de PowerShell.
- Soporte de Maven, Gradle, npm y pnpm.
