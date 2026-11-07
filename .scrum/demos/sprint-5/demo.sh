#!/usr/bin/env bash
# Sprint 5 のデモ。使い方：bash demo.sh [コードのディレクトリ] [--rehearse]
# 待つ場面は無いので、--rehearse は受け取るだけで動作は変わらない。
set -u

DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODE_DIR="${1:-$(cd "$DEMO_DIR/../../.." && pwd)}"
CODE_DIR="$(cd "$CODE_DIR" && pwd)"
REHEARSE=0
if [ "${2:-}" = "--rehearse" ]; then
  REHEARSE=1
fi

export PATH="$HOME/.local/bin:$PATH"

# テストのレポート（reports/）が元から無ければ、終了時に消す。
REPORTS_EXISTED=1
if [ ! -e "$CODE_DIR/reports" ]; then
  REPORTS_EXISTED=0
fi
TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
  if [ "$REPORTS_EXISTED" = 0 ]; then
    rm -rf "$CODE_DIR/reports"
  fi
}
trap cleanup EXIT

FAIL=0

run_script() {
  godot --headless --no-header --path "$CODE_DIR" -s "$1" "${@:2}"
}

echo "コード：$CODE_DIR"
echo

echo "== 場面 0: scripts/test.sh を実行する =="
if [ ! -d "$CODE_DIR/addons/gdUnit4" ]; then
  echo "gdUnit4 が無いので scripts/setup.sh を先に実行する"
  (cd "$CODE_DIR" && scripts/setup.sh) || FAIL=1
fi
(cd "$CODE_DIR" && scripts/test.sh) > "$TMP_DIR/test.log" 2>&1
TEST_CODE=$?
cat "$TMP_DIR/test.log"
echo "scripts/test.sh の終了コード：$TEST_CODE"
echo "ERROR の行数：$(grep -c 'ERROR' "$TMP_DIR/test.log")（debugger ポートの既知の2行だけのはず）"
echo "WARNING・leaked・still in use の行数：$(grep -ci 'WARNING\|leaked\|still in use' "$TMP_DIR/test.log")（0 のはず）"
if [ "$TEST_CODE" -ne 0 ]; then
  FAIL=1
fi
echo

echo "== 場面 1: 誤った式と名前を渡す（0 < x < 10、人口 * 0.02、1e3、2x、「人口」や空白だけの名前） =="
echo "--- 式のパーサ（位置つきのエラー。(a < b) < c は通る） ---"
run_script res://demo/expr_parse_demo.gd || FAIL=1
echo "--- 定義の名前（ストック・定数・フロー） ---"
run_script res://demo/name_rule_demo.gd || FAIL=1
echo

echo "== 場面 2: 下限0・上限100の食料と、下限の無いお金を進める。下限が上限より大きい設定も渡す =="
run_script res://demo/range_demo.gd || FAIL=1
echo

echo "== 場面 3: 補助変数の定義の順だけを変えた2つのモデルを回す。循環するモデルも渡す。町のゴールデン値を確かめる =="
echo "--- 補助変数（順序の独立、循環、フローの量の参照、実行時エラー、1000個の鎖） ---"
run_script res://demo/auxiliary_demo.gd || FAIL=1
echo "--- 町のゴールデン値のテスト（期待値は #20 のまま。通れば値は変わっていない） ---"
(cd "$CODE_DIR" && godot --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/sample/town_golden_test.gd) > "$TMP_DIR/golden.log" 2>&1
GOLDEN_CODE=$?
grep -a 'PASSED\|FAILED' "$TMP_DIR/golden.log" | grep -a ' > ' | sed 's/\x1b\[[0-9;]*m//g'
grep -a 'Overall Summary\|Exit code' "$TMP_DIR/golden.log" | sed 's/\x1b\[[0-9;]*m//g'
echo "町のゴールデン値のテストの終了コード：$GOLDEN_CODE"
if [ "$GOLDEN_CODE" -ne 0 ]; then
  FAIL=1
fi
echo

echo "== 場面 4: stock / divisor で divisor が 0 のモデルを回す =="
run_script res://demo/error_names_demo.gd || FAIL=1
echo

if [ "$REHEARSE" = 1 ]; then
  echo "(リハーサル：終了)"
fi
exit "$FAIL"
