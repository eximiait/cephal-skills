---
name: deploy-test
description: Crea y pushea el tag x.y.z-rc.n que despliega a test desde la rama actual. Usala cuando haya que probar cambios en el ambiente de test.
---

# Desplegar a test

`CV` es el script junto a este archivo, con el proyecto como directorio actual:
`sh "<esta carpeta>/scripts/cephal-version"`. En PowerShell:
`powershell -NoProfile -ExecutionPolicy Bypass -File "<esta carpeta>/scripts/cephal-version.ps1"`.
Citá la ruta: puede tener espacios. Si `CV` pide `--lang`, preguntá el lenguaje y anteponé `--lang <maven|gradle|npm|pnpm>` a cada subcomando.
Si una salida trae `chart=skipped`, avisá: `No se encontró Chart.yaml: appVersion no se alineó.`
Mostrá solo lo imprescindible.

1. `CV context` y `CV check`. Si alguno falla, mostrá el error y terminá.
2. `CV release-prep`. Si `snapshot=yes`:
   - Destacá: **⚠️ La versión tiene -SNAPSHOT: así no se puede pasar a testing** (el pipeline falla en un tag).
   - Proponé quitarlo (`<release>`) en el archivo del lenguaje y en `appVersion`, con el commit `Release app <release>`, y preguntá si lo aplicás.
   - Si acepta: `CV release-prep --apply`. Si no, terminá.
3. Si `open_rc` es `none`, preguntá `¿patch, minor o major sobre <last_final>?`. Con un RC abierto no preguntes.
4. `CV next-tag test [<tipo>]` devuelve `tag` y `head`.
5. Mostrá `Tag <tag> sobre <head> (<branch>)`; si hubo commit de release, aclará que se pushea junto con el tag. Pedí confirmación explícita.
6. Solo con el sí: `CV tag-push <tag>` e informá `pushed=<tag>`. Sin el sí no pushees: el commit de release, si lo hubo, queda local.

Nunca pushees sin confirmación. Commits y tags llevan la identidad git del dev: sin firmas ni menciones al agente.
