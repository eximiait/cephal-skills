---
name: deploy-prod
description: Crea y pushea el tag x.y.z que habilita el despliegue a prod desde la rama actual. Usala para liberar una versión; puede salir directo, sin RC previo.
---

# Desplegar a prod

`CV` es el script junto a este archivo, con el proyecto como directorio actual:
`sh <esta carpeta>/scripts/cephal-version`. En PowerShell:
`powershell -NoProfile -ExecutionPolicy Bypass -File <esta carpeta>/scripts/cephal-version.ps1`.
Mostrá solo lo imprescindible.

1. `CV context` y `CV check`. Si alguno falla, mostrá el error y terminá.
2. `CV release-prep`. Si `snapshot=yes`:
   - Destacá: **⚠️ La versión tiene -SNAPSHOT: así no se puede liberar** (el pipeline falla en un tag).
   - Proponé quitarlo (`<release>`) en el archivo del lenguaje y en `appVersion`, con el commit `Release app <release>`, y preguntá si lo aplicás.
   - Si acepta: `CV release-prep --apply`. Si no, terminá.
3. Si `open_rc` es `none`, preguntá `¿patch, minor o major sobre <last_final>?`. Con un RC abierto no preguntes.
4. `CV next-tag prod [<tipo>]` devuelve `tag`. Con `rc_open=yes`, informá `<commits_since_rc> commits desde el último RC`.
5. Mostrá `Tag <tag> sobre <sha corto> (<branch>)`; si hubo commit de release, aclará que se pushea junto con el tag. Pedí confirmación explícita.
6. Solo con el sí: `CV tag-push <tag>` e informá `pushed=<tag>`.

Salir directo con `x.y.z`, sin RC, es válido: el pipeline igual pasa por test. Nunca pushees sin confirmación. Commits y tags llevan la identidad git del dev: sin firmas ni menciones al agente.
