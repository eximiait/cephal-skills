---
name: deploy-prod
description: Libera a prod. Integra develop en main por MR y pushea el tag x.y.z desde main, que habilita el despliegue. Usala para liberar una versión; puede salir directo, sin RC previo.
---

# Desplegar a prod

`CV` es el script junto a este archivo, con el proyecto como directorio actual:
`sh "<esta carpeta>/scripts/cephal-version"`. En PowerShell:
`powershell -NoProfile -ExecutionPolicy Bypass -File "<esta carpeta>/scripts/cephal-version.ps1"`.
Citá la ruta: puede tener espacios. Si `CV` pide `--lang`, preguntá el lenguaje y anteponé `--lang <maven|gradle|npm|pnpm>` a cada subcomando.
Si una salida trae `chart=skipped`, avisá: `No se encontró Chart.yaml: appVersion no se alineó.`
Mostrá solo lo imprescindible. Cada corrida retoma donde quedó; no duplica MR ni tag.

1. `CV context`. Si `branch` no es `develop_branch` ni `main_branch`, decilo y terminá. Después `git fetch`.
2. `CV release-target`. Si falla con `falta integrar el MR`, develop tiene cambios sin integrar (otro error: mostralo y terminá). Si anda, seguí en el paso 4.
3. Integrar develop (solo desde `develop_branch`; si no: `Pasate a <develop_branch>` y terminá). `CV gitlab-mode`:
   - `gitlab=manual`: dá `CV mr-link`, pedí que cree y mergee el MR y que te avise. Con el aviso, volvé al paso 2.
   - `gitlab=glab`: `CV mr-find`.
     - `mr=none`: `CV check`, luego `CV release-prep`. Con `snapshot=yes`, destacá **⚠️ -SNAPSHOT: no se puede liberar** y ofrecé `CV release-prep --apply` + `CV push-branch` (con confirmación); si no acepta, terminá. Después pedí confirmación y `CV mr-create`; informá `mr_url`, y seguí con su `mr_iid`.
     - `mr_iid`: `CV mr-status <iid>`, según `pipeline`:
       - `running`: repetí `CV mr-wait <iid> pipeline` mientras `timeout=yes`, hasta `CEPHAL_WAIT_MINUTES` (20) en total; al vencer: `Volvé a correr deploy-prod cuando termine.` Con `timeout=no`, seguí según el `pipeline` devuelto (ramas siguientes).
       - `failed`, `canceled`, `skipped`, `manual`: mostrá `state` y `url` y terminá.
       - `none`: sin pipeline, solo el dev puede mergear; avisá y terminá.
       - `success`: preguntá `¿Mergeo yo o lo hacés vos?`. Si yo: confirmación y `CV mr-merge <iid> <sha>` (`sha` de `mr-status`). Si el dev: repetí `CV mr-wait <iid> merged` mientras `timeout=yes`, con el mismo límite y salida; con `state=closed` decí `El MR se cerró sin mergear` y terminá.
     - Si `mr-merge` falla, mostrá el motivo y dejalo al dev.
   - Con el MR mergeado, volvé al paso 2.
4. `release-target` deja el checkout en `main_branch` y trae `head` y, si existe, `tagged`. Con `tagged`: `Ya liberado: <tag>` y terminá.
5. `CV release-prep`. Con `snapshot=yes`: destacá **⚠️ Así no se puede liberar: quitá -SNAPSHOT en develop y mergealo por MR**, sin commitear, y terminá.
6. Si `open_rc` es `none`, preguntá `¿patch, minor o major sobre <last_final>?`; con un RC abierto no preguntes. `CV next-tag prod [<tipo>]` devuelve `tag` y `head`; con `rc_open=yes`, informá `<commits_since_rc> commits desde el último RC`.
7. Mostrá `Tag <tag> sobre <head> (<branch>)` y pedí confirmación explícita.
8. Solo con el sí: `CV tag-push <tag>` e informá `pushed=<tag>`. Sin el sí no pushees: lo local queda local.

Nunca muevas, borres ni sobrescribas un tag, ni ofrezcas `--force`; si el tag existe, informalo y terminá.
Nunca pushees ni mergees sin confirmación. Commits y tags llevan la identidad git del dev: sin firmas ni menciones al agente.
