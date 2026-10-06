---
name: show-versioning-flow
description: Muestra en la terminal el flujo de ramas, versionado y tags (push a feature y a develop, tag RC y tag final) y desde qué rama sale cada tag. Usala para explicar o repasar cómo se versiona y se despliega.
---

# Mostrar el flujo de versionado

`CV` es el script junto a este archivo, con el proyecto como directorio actual:
`sh "<esta carpeta>/scripts/cephal-version"`. En PowerShell:
`powershell -NoProfile -ExecutionPolicy Bypass -File "<esta carpeta>/scripts/cephal-version.ps1"`.
Citá la ruta: puede tener espacios.

1. Corré `CV flow`. Si falla, mostrá el error y terminá.
2. Mostrá la salida tal cual en un bloque de código, sin resumirla ni explicarla ni agregar texto.

No cambia nada: no commitea, no taguea ni pushea.
