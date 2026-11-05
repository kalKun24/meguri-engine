#!/usr/bin/env bash
# test/ のテストを godot --headless で実行する。失敗があれば、終了コードが 0 以外になる。
# 使い方：scripts/test.sh [gdUnit4 に渡す引数]
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
cd "${ROOT}" || exit 1

# 初回、または版を変えた後に、リソースの取り込みを済ませる。
"${GODOT_BIN}" --headless --path . --import --quit-after 2000 > /dev/null 2>&1

# 6.x の gdUnit4 は、ヘッドレスで動かすときに --ignoreHeadlessMode が要る。
# --remote-debug は、スクリプトの読み込みエラー時に対話デバッガで止まらないようにするためである。
"${GODOT_BIN}" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test "$@"
exit $?
