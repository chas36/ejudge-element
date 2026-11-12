#!/bin/bash
set -euo pipefail
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat > "$work/executor" <<'EOF'
#!/bin/sh
if [ "${1:-}" = -v ]; then echo 'Запускается 1С:Предприятие.Элемент Скрипт версии 10.0.2-1'; exit 0; fi
echo ELEMENT_OK
EOF
chmod +x "$work/executor"
printf 'version="10.0.2-1"\nELEMENTPATH="%s"\n' "$work/executor" > "$work/element.cfg"
cp examples/element/hello.sbsl "$work/main.sbsl"
EJUDGE_LANG_CONFIG="$work/element.cfg" EJUDGE_EXE_PROPERTIES=1 \
  bash scripts/element.in "$work/main.sbsl" "$work/output" "$work/properties.json"
cmp "$work/main.sbsl" "$work/output"
python3 - "$work/properties.json" "$work/executor" <<'PY'
import json,sys
obj=json.load(open(sys.argv[1]))
assert obj['start_cmd']==sys.argv[2]
assert obj['start_args']==[sys.argv[2]]
PY
EJUDGE_LANG_CONFIG="$work/element.cfg" bash scripts/element.in \
  "$work/main.sbsl" "$work/wrapper"
cmp <(printf 'ELEMENT_OK\n') <("$work/wrapper")
config=$(bash scripts/element-version.in -r "$work/executor")
printf '%s\n' "$config" | grep -q 'version="10.0.2-1"'
printf '%s\n' "$config" | grep -q "ELEMENTPATH=\"$(readlink -f "$work/executor")\""
echo 'Element adapter smoke test passed'
