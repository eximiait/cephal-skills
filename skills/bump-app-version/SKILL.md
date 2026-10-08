---
name: bump-app-version
description: Sube la versión de la app (pom, gradle, npm o pnpm), alinea appVersion de Chart.yaml y, si el chart ya fue liberado, deja la siguiente versión del chart. Usala en la rama de desarrollo antes de liberar cambios de código.
---

# Subir la versión de la app

`CV` es el script junto a este archivo, con el proyecto como directorio actual:
`sh "<esta carpeta>/scripts/cephal-version"`. En PowerShell:
`powershell -NoProfile -ExecutionPolicy Bypass -File "<esta carpeta>/scripts/cephal-version.ps1"`.
Citá la ruta: puede tener espacios. Si `CV` pide `--lang`, preguntá el lenguaje y anteponé `--lang <maven|gradle|npm|pnpm>` a cada subcomando.
Si `bump` o `release-prep --apply` traen `chart=skipped`, avisá: `No se encontró Chart.yaml: appVersion no se alineó.`
Al dev mostrale solo las preguntas, una línea por resultado y, si un comando trae líneas `diff --git`, esas líneas tal cual en un bloque ```diff (sin resumirlas ni explicarlas).

1. `CV context`. Si falla, mostrá el error y terminá.
2. Si `branch` es distinto de `develop_branch`: `Estás en <branch>; el bump se hace en <develop_branch>.` y terminá.
3. Preguntá: `¿patch, minor o major? (versión actual: <version>)`.
4. `CV chart-prep --write`. Si falla con `falta el tipo`, preguntá `¿patch, minor o major para el chart? (último release: <last_final>)` y repetilo con el tipo; con otro error, mostralo y terminá. Con `changed=yes`, informá `Chart: <version>`; con `changed=no` o `chart=skipped`, no digas nada del chart.
5. `CV bump <tipo>`. Mostrá la diff y `<from> → <to>`. Si falla con `ya fue tag`, esa versión ya tiene imagen publicada y se reutilizaría con código viejo: mostrá el error, preguntá `¿Qué versión x.y.z usamos? (sugerida: <la del error>)` y repetí con `CV bump <x.y.z>`.
6. Cerrá con una línea: `Listo. Commiteá los cambios.`

No commitees ni pushees: eso lo decide el dev.
Nunca muevas, borres ni sobrescribas un tag, ni ofrezcas `--force`; si el tag existe, informalo y terminá.
