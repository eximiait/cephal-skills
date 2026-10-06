. "$(dirname "$0")/lib.sh"

setup() {
  new_repo
  add_file pom.xml '<project>
  <artifactId>demo</artifactId>
  <version>1.3.1</version>
</project>'
  commit_all "pom"
}
line() { printf '%s\n' "$OUT" | sed -n "$1p"; }

# salida exacta (repo sin tags, en develop)
setup
run_cv flow
assert_eq 0 "$RC" "flow: sale 0"
assert_eq "" "$ERRO" "flow: sin errores"
EXPECTED=$(cat <<'TXT'
 repo | app 1.3.1 | último final ninguno | RC abierto ninguno

 main       ------------------------------*-------->  [4] tag x.y.z -> prod (solo desde main)
                                          ^
                                          | MR develop -> main (deploy-prod)
 develop    ---*--------*---------*-------*-------->  [2] push -> dev
                \      /          |
                 \    /           +-- [3] tag x.y.z-rc.n -> test (deploy-test)
 feature/x        *--*
                  [1] push: solo valida, no publica

 Evento                Desde                  Publica                             Despliega
 [1] push a feature/*  feature/*              nada (el build solo valida)         -
 [2] push a develop    develop                imagen x.y.z-develop + chart        dev (auto)
 [3] tag x.y.z-rc.n    cualquiera menos main  imagen x.y.z (o la reusa) + chart   dev auto, test manual
 [4] tag x.y.z         main                   imagen x.y.z (o la reusa) + chart   dev auto, test y prod manual

 Estás en develop: en develop se sube la versión (bump-app-version), se crea el RC (deploy-test) y se arranca deploy-prod.

 Reglas
  - La versión de la app se sube en develop (bump-app-version); un tag no puede llevar -SNAPSHOT.
  - La versión del chart es el tag de Git; deploy-prod la deja en Chart.yaml y viaja por el MR.
  - El tag final sale solo de main y después del MR; el RC, de cualquier rama menos main.
  - Los tags no se mueven ni se pisan; nada se pushea sin tu confirmación.
TXT
)
assert_eq "$EXPECTED" "$OUT" "flow: salida exacta"
assert_eq "" "$(printf '%s' "$OUT" | grep -n '	' )" "flow: sin tabulaciones"

# estado de tags: último final y RC abierto en el encabezado
setup
git tag 1.0.0
git tag 1.1.0-rc.2
run_cv flow
assert_eq " repo | app 1.3.1 | último final 1.0.0 | RC abierto 1.1.0" "$(line 1)" "flow: encabezado con RC abierto"
git tag 1.1.0
run_cv flow
assert_eq " repo | app 1.3.1 | último final 1.1.0 | RC abierto ninguno" "$(line 1)" "flow: el RC se cierra con su tag final"

# "estás en" según la rama
setup
git checkout -q -b feature/x
run_cv flow
assert_contains "$OUT" " Estás en feature/x: desde feature/x se crea el RC (deploy-test); bump-app-version y deploy-prod se hacen en develop." "flow: en una feature"
git checkout -q main
run_cv flow
assert_contains "$OUT" " Estás en main: en main solo se crea el tag x.y.z (deploy-prod); deploy-test no corre acá." "flow: en main"
git checkout -q --detach
run_cv flow
assert_contains "$OUT" " Estás en (detached): desde (detached) se crea el RC" "flow: HEAD desacoplado"

# ramas configuradas (más largas que las etiquetas por defecto)
setup
add_file .gitlab-ci.yml 'variables:
  DEVELOP_BRANCH: "integracion-continua"
  MAIN_BRANCH: "produccion"'
commit_all "ci"
git checkout -q -b integracion-continua
run_cv flow
assert_contains "$OUT" "| MR integracion-continua -> produccion (deploy-prod)" "flow: usa las ramas configuradas"
assert_contains "$OUT" "(solo desde produccion)" "flow: el tag final sale de la rama principal configurada"
assert_contains "$OUT" " integracion-continua  ---*" "flow: etiqueta de la rama de desarrollo sin truncar"
assert_contains "$OUT" " Estás en integracion-continua: en integracion-continua se sube la versión" "flow: rama de desarrollo configurada"
assert_contains "$OUT" "cualquiera menos produccion" "flow: el RC sale de cualquiera menos la principal configurada"

# sin proyecto detectable y fuera de un repo
new_repo
run_cv flow
assert_eq 0 "$RC" "flow: sin pom también funciona"
assert_eq " repo | app sin detectar | último final ninguno | RC abierto ninguno" "$(line 1)" "flow: encabezado sin proyecto"
assert_eq "" "$ERRO" "flow: sin pom no escribe errores"
T2=$(mktemp -d)
cd "$T2" || exit 1
run_cv flow
assert_eq 1 "$RC" "flow: fuera de un repo falla"
assert_contains "$ERRO" "no es un repositorio git" "flow: fuera de un repo, mensaje"

finish
