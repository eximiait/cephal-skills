. "$(dirname "$0")/lib.sh"
CHK="$ROOT/scripts/check-version.sh"

sh "$CHK" v0.4.0 >/dev/null 2>&1
assert_eq 0 "$?" "tag igual a plugin.json y marketplace.json"
sh "$CHK" v0.2.0 >/dev/null 2>&1
assert_eq 1 "$?" "tag distinto falla"

# marketplace.json desalineado con plugin.json
D=$(mktemp -d)
mkdir -p "$D/.claude-plugin"
cp "$ROOT/.claude-plugin/plugin.json" "$D/.claude-plugin/"
sed 's/"version": "0.4.0"/"version": "0.0.9"/' "$ROOT/.claude-plugin/marketplace.json" > "$D/.claude-plugin/marketplace.json"
OUT=$(CEPHAL_SKILLS_ROOT="$D" sh "$CHK" v0.4.0 2>&1); RC=$?
assert_eq 1 "$RC" "marketplace.json desalineado falla"
assert_contains "$OUT" "marketplace.json" "marketplace.json desalineado: nombra el archivo"

finish
