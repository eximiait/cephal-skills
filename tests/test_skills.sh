. "$(dirname "$0")/lib.sh"
cd "$ROOT" || exit 1

SKILLS="bump-app-version deploy-test deploy-prod"

for s in $SKILLS; do
  f="skills/$s/SKILL.md"
  assert_eq "---" "$(sed -n 1p "$f" 2>/dev/null)" "$s: frontmatter abre"
  assert_eq "name: $s" "$(sed -n 2p "$f" 2>/dev/null)" "$s: name igual al directorio"
  case "$(sed -n 3p "$f" 2>/dev/null)" in "description: "?*) d=ok ;; *) d=falta ;; esac
  assert_eq ok "$d" "$s: tiene description"
  assert_eq "---" "$(sed -n 4p "$f" 2>/dev/null)" "$s: frontmatter cierra"
  n=$(wc -l < "$f" 2>/dev/null || echo 999)
  [ "$n" -le 60 ] && l=ok || l="$n líneas"
  assert_eq ok "$l" "$s: ≤ 60 líneas"
  assert_eq yes "$(grep -q 'scripts/cephal-version' "$f" 2>/dev/null && echo yes || echo no)" "$s: referencia el script"
  assert_eq yes "$(grep -qF 'sh "<esta carpeta>/scripts/cephal-version"' "$f" 2>/dev/null && echo yes || echo no)" "$s: ruta del script entre comillas"
  assert_eq yes "$(grep -qF -- '-File "<esta carpeta>/scripts/cephal-version.ps1"' "$f" 2>/dev/null && echo yes || echo no)" "$s: ruta del wrapper entre comillas"
  assert_eq yes "$(grep -qF -- '--lang' "$f" 2>/dev/null && echo yes || echo no)" "$s: explica --lang"
  assert_eq yes "$(grep -qF 'chart=skipped' "$f" 2>/dev/null && echo yes || echo no)" "$s: avisa chart=skipped"
  assert_eq same "$(cmp -s scripts/cephal-version "skills/$s/scripts/cephal-version" && echo same || echo differ)" "$s: copia del script"
  assert_eq same "$(cmp -s scripts/cephal-version.ps1 "skills/$s/scripts/cephal-version.ps1" && echo same || echo differ)" "$s: copia del wrapper"
done

for s in deploy-test deploy-prod; do
  assert_eq yes "$(grep -qi 'confirm' "skills/$s/SKILL.md" && echo yes || echo no)" "$s: pide confirmación"
  assert_eq yes "$(grep -q 'SNAPSHOT' "skills/$s/SKILL.md" && echo yes || echo no)" "$s: trata -SNAPSHOT"
  assert_eq yes "$(grep -qF 'Tag <tag> sobre <head>' "skills/$s/SKILL.md" && echo yes || echo no)" "$s: usa head= de next-tag"
  assert_eq yes "$(grep -qF 'queda local' "skills/$s/SKILL.md" && echo yes || echo no)" "$s: aclara que sin confirmación el commit queda local"
done
for k in mr-find mr-create mr-wait mr-merge mr-link release-target gitlab-mode push-branch CEPHAL_WAIT_MINUTES; do
  assert_eq yes "$(grep -qF -- "$k" skills/deploy-prod/SKILL.md && echo yes || echo no)" "deploy-prod: menciona $k"
done
# sin glab: caída a manual, pasos manuales y skills que no lo necesitan
assert_eq yes "$(grep -qF 'seguí en modo manual' skills/deploy-prod/SKILL.md && echo yes || echo no)" "deploy-prod: si falla un mr-*, sigue en modo manual"
for k in 'SIN tildar `Delete source branch`' 'SIN `Squash commits`' 'sin el link' 'GitLab todavía no muestra el merge en <main_branch>'; do
  assert_eq yes "$(grep -qF -- "$k" skills/deploy-prod/SKILL.md && echo yes || echo no)" "deploy-prod: modo manual dice $k"
done
fb=$(grep -F 'seguí en modo manual' skills/deploy-prod/SKILL.md)
for k in mr-find mr-create mr-status mr-wait mr-merge; do
  assert_eq yes "$(printf '%s' "$fb" | grep -qF -- "$k" && echo yes || echo no)" "deploy-prod: la línea de caída a manual lista $k"
done
for s in bump-app-version deploy-test; do
  assert_eq "" "$(grep -E 'glab|mr-' "skills/$s/SKILL.md")" "$s: no usa glab ni mr-*"
done
assert_eq yes "$(grep -qF 'sigue en modo manual' README.md && echo yes || echo no)" "README: caída a modo manual si glab falla"
assert_eq yes "$(grep -qF 'main_branch' skills/deploy-test/SKILL.md && echo yes || echo no)" "deploy-test: no crea RC en main_branch"
for s in $SKILLS; do
  assert_eq yes "$(grep -qF 'sobrescribas' "skills/$s/SKILL.md" && echo yes || echo no)" "$s: tags inmutables"
done
assert_eq yes "$(grep -qi 'sin commitear\|no commite' skills/bump-app-version/SKILL.md && echo yes || echo no)" "bump-app-version: no commitea"

# nunca force ni borrar tags
assert_eq "" "$(grep -rhE -- '--force|push -f|tag -f' scripts skills 2>/dev/null | grep -vxF 'Nunca muevas, borres ni sobrescribas un tag, ni ofrezcas `--force`; si el tag existe, informalo y terminá.')" "sin --force, push -f ni tag -f"

# sync
sh scripts/sync.sh --check >/dev/null 2>&1; assert_eq 0 "$?" "sync --check: copias al día"
printf '# alterado\n' >> skills/deploy-test/scripts/cephal-version
sh scripts/sync.sh --check >/dev/null 2>&1; assert_eq 1 "$?" "sync --check: detecta una copia alterada"
sh scripts/sync.sh >/dev/null 2>&1
sh scripts/sync.sh --check >/dev/null 2>&1; assert_eq 0 "$?" "sync: restaura las copias"

# manifiestos
assert_eq yes "$(grep -q '"name": "cephal"' .claude-plugin/plugin.json && echo yes || echo no)" "plugin.json: name"
assert_eq yes "$(grep -q '"version": "0.4.0"' .claude-plugin/plugin.json && echo yes || echo no)" "plugin.json: version 0.4.0"
assert_eq yes "$(grep -q '"name": "cephal-skills"' .claude-plugin/marketplace.json && echo yes || echo no)" "marketplace.json: name"
assert_eq yes "$(grep -q '"source": "./"' .claude-plugin/marketplace.json && echo yes || echo no)" "marketplace.json: source"
if command -v node >/dev/null 2>&1; then
  for j in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
    node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$j" 2>/dev/null
    assert_eq 0 "$?" "$j: JSON válido"
  done
fi

# Preparar se puede repetir: la skill no depende de que el agente recuerde si ya lo corrió
assert_eq no "$(grep -qF 'si aún no lo hiciste' skills/deploy-prod/SKILL.md && echo yes || echo no)" "deploy-prod: Preparar no depende de recordar el estado"
assert_eq yes "$(grep -qF 'repetirlo es seguro' skills/deploy-prod/SKILL.md && echo yes || echo no)" "deploy-prod: aclara que Preparar se puede repetir"

assert_eq yes "$(grep -qF 'chart-prep' skills/deploy-prod/SKILL.md && echo yes || echo no)" "deploy-prod: decide la versión del chart con chart-prep"
assert_eq yes "$(grep -qF 'Versión a liberar' skills/deploy-prod/SKILL.md && echo yes || echo no)" "deploy-prod: informa la versión a liberar"

assert_eq yes "$(grep -qF -- '- `mr_iid`: *Preparar*' skills/deploy-prod/SKILL.md && echo yes || echo no)" "deploy-prod: con un MR abierto también corre Preparar"
assert_eq yes "$(grep -qF 'volvé a `develop_branch`' skills/deploy-prod/SKILL.md && echo yes || echo no)" "deploy-prod: salida cuando la versión del chart no es liberable en main"
assert_eq no "$(grep -qF 'Si una salida trae `chart=skipped`' skills/deploy-prod/SKILL.md && echo yes || echo no)" "deploy-prod: el aviso de appVersion no aplica a chart-prep"

for s in $SKILLS; do
  assert_eq yes "$(grep -qF 'bloque ```diff' "skills/$s/SKILL.md" && echo yes || echo no)" "$s: muestra la diff en un bloque diff"
  assert_eq yes "$(grep -qF 'tal cual' "skills/$s/SKILL.md" && echo yes || echo no)" "$s: la diff va tal cual"
done

for img in bump-app-version deploy-test deploy-prod flujo; do
  assert_eq yes "$(grep -qF "docs/img/$img.svg" README.md && [ -f "docs/img/$img.svg" ] && echo yes || echo no)" "README: imagen $img referenciada y presente"
done

# show-versioning-flow: solo muestra, no cambia nada
s=show-versioning-flow
f="skills/$s/SKILL.md"
assert_eq "name: $s" "$(sed -n 2p "$f" 2>/dev/null)" "$s: name igual al directorio"
assert_eq "---" "$(sed -n 4p "$f" 2>/dev/null)" "$s: frontmatter cierra"
n=$(wc -l < "$f" 2>/dev/null || echo 999)
[ "$n" -le 30 ] && l=ok || l="$n líneas"
assert_eq ok "$l" "$s: ≤ 30 líneas"
assert_eq yes "$(grep -qF 'sh "<esta carpeta>/scripts/cephal-version"' "$f" && echo yes || echo no)" "$s: ruta del script entre comillas"
assert_eq yes "$(grep -qF -- '-File "<esta carpeta>/scripts/cephal-version.ps1"' "$f" && echo yes || echo no)" "$s: ruta del wrapper entre comillas"
assert_eq yes "$(grep -qF '`CV flow`' "$f" && echo yes || echo no)" "$s: corre flow"
assert_eq yes "$(grep -qF 'sin resumirla' "$f" && echo yes || echo no)" "$s: muestra la salida tal cual"
assert_eq "" "$(grep -E 'glab|mr-|tag-push|push-branch' "$f")" "$s: no pushea ni usa glab"
assert_eq same "$(cmp -s scripts/cephal-version "skills/$s/scripts/cephal-version" && echo same || echo differ)" "$s: copia del script"
assert_eq same "$(cmp -s scripts/cephal-version.ps1 "skills/$s/scripts/cephal-version.ps1" && echo same || echo differ)" "$s: copia del wrapper"
assert_eq yes "$(grep -qF 'show-versioning-flow' README.md && echo yes || echo no)" "README: lista show-versioning-flow"

finish
