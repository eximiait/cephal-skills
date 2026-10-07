#!/bin/sh
# Genera las imágenes del README a partir de la salida real de scripts/cephal-version.
# Uso: sh docs/img/generar.sh   (escribe docs/img/*.svg)
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CV="$ROOT/scripts/cephal-version"
OUTDIR="$ROOT/docs/img"
GIT_CONFIG_GLOBAL=/dev/null; GIT_CONFIG_NOSYSTEM=1; export GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM

repo() { # crea un repo con remoto y deja el cwd ahí
  T=$(mktemp -d); git init -q --bare -b develop "$T/origin.git"; git init -q -b develop "$T/r"; cd "$T/r" || exit 1
  git config user.name Dev; git config user.email dev@example.com; git config commit.gpgsign false; git config core.autocrlf false
  git remote add origin "$T/origin.git"
  mkdir -p chart
  printf '<project>\n  <artifactId>demo</artifactId>\n  <version>%s</version>\n</project>\n' "$1" > pom.xml
  printf 'apiVersion: v2\nname: demo\nversion: %s\nappVersion: "%s"\n' "$2" "$1" > chart/Chart.yaml
  git add -A; git commit -q -m base; git push -q -u origin develop
  git branch -q main; git push -q -u origin main 2>/dev/null
}
diffpart() { sed -n '/^diff --git/,$p'; }

# render <archivo .svg> <título> < líneas "P|…" (prompt) "A|…" (agente) "D|…" (diff)
render() {
  awk -v title="$2" '
    function esc(s,   r, i, c) {
      r = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "&") c = "&amp;"; else if (c == "<") c = "&lt;"; else if (c == ">") c = "&gt;"
        r = r c
      }
      return r
    }
    { t = substr($0, 1, 1); s = substr($0, 3); n++; T[n] = t; S[n] = s }
    END {
      lh = 20; w = 920; h = n * lh + 64
      printf "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\" font-family=\"ui-monospace,SFMono-Regular,Menlo,Consolas,monospace\" font-size=\"13\">\n", w, h, w, h
      printf "<rect width=\"%d\" height=\"%d\" rx=\"8\" fill=\"#0d1117\"/>\n", w, h
      printf "<circle cx=\"18\" cy=\"16\" r=\"5\" fill=\"#ff5f56\"/><circle cx=\"36\" cy=\"16\" r=\"5\" fill=\"#ffbd2e\"/><circle cx=\"54\" cy=\"16\" r=\"5\" fill=\"#27c93f\"/>\n"
      printf "<text x=\"%d\" y=\"20\" fill=\"#8b949e\" text-anchor=\"middle\">%s</text>\n", w / 2, esc(title)
      for (i = 1; i <= n; i++) {
        y = 44 + (i - 1) * lh; s = S[i]; c = "#c9d1d9"; wgt = "normal"
        if (T[i] == "P") c = "#d2a8ff"
        else if (T[i] == "D") {
          f = substr(s, 1, 1)
          if (s ~ /^(diff --git|index |--- |\+\+\+ )/) { c = "#e6edf3"; wgt = "bold" }
          else if (f == "@") c = "#58a6ff"
          else if (f == "+") c = "#3fb950"
          else if (f == "-") c = "#f85149"
        }
        printf "<text x=\"16\" y=\"%d\" fill=\"%s\" font-weight=\"%s\" xml:space=\"preserve\">%s</text>\n", y, c, wgt, esc(s)
      }
      print "</svg>"
    }' > "$1"
}

# bump-app-version
repo 0.1.0 1.0.0; git tag 1.0.0
sh "$CV" chart-prep --write minor >/dev/null
D=$(sh "$CV" bump minor | diffpart)
{ printf 'P|> /cephal:bump-app-version\n'; printf 'A|¿patch, minor o major? (versión actual: 0.1.0)\n'; printf 'P|> minor\n'
  printf 'A|¿patch, minor o major para el chart? (último release: 1.0.0)\n'; printf 'P|> minor\n'; printf 'A|Chart: 1.1.0\n'
  printf '%s\n' "$D" | sed 's/^/D|/'; printf 'A|0.1.0 → 0.2.0. Listo. Commiteá los cambios.\n'; } | render "$OUTDIR/bump-app-version.svg" "bump-app-version"

# deploy-test (con -SNAPSHOT)
repo 2.0.0-SNAPSHOT 1.0.0; git tag 1.0.0
D=$(sh "$CV" release-prep --apply | diffpart); H=$(git rev-parse --short HEAD)
{ printf 'P|> /cephal:deploy-test\n'; printf 'A|⚠️ La versión tiene -SNAPSHOT: así no se puede pasar a testing.\n'
  printf 'A|¿Quito -SNAPSHOT (2.0.0) con el commit «Release app 2.0.0»?\n'; printf 'P|> sí\n'
  printf '%s\n' "$D" | sed 's/^/D|/'; printf 'A|¿patch, minor o major sobre 1.0.0?\n'; printf 'P|> minor\n'
  printf 'A|Tag 1.1.0-rc.1 sobre %s (develop). ¿Confirmás el push?\n' "$H"; printf 'P|> sí\n'; printf 'A|pushed=1.1.0-rc.1\n'; } | render "$OUTDIR/deploy-test.svg" "deploy-test"

# deploy-prod (versión del chart decidida en develop)
repo 2.0.0 1.0.0; git tag 1.0.0; git tag 1.1.0-rc.1
D=$(sh "$CV" chart-prep --apply | diffpart)
{ printf 'P|> /cephal:deploy-prod\n'; printf 'A|Versión a liberar: 1.1.0\n'; printf 'A|¿Commiteo «Chart a 1.1.0» y pusheo develop?\n'; printf 'P|> sí\n'
  printf '%s\n' "$D" | sed 's/^/D|/'; printf 'A|MR creado: https://gitlab.example.com/grupo/proyecto/-/merge_requests/12\n'
  printf 'A|Pipeline del MR en verde. ¿Mergeo yo o lo hacés vos?\n'; printf 'P|> mergealo\n'
  printf 'A|Mergeado. El checkout ahora está en main.\n'; printf 'A|Tag 1.1.0 sobre 9f3c2ab (main). ¿Confirmás el push?\n'; printf 'P|> sí\n'; printf 'A|pushed=1.1.0\n'; } | render "$OUTDIR/deploy-prod.svg" "deploy-prod"
echo "imágenes en $OUTDIR"
