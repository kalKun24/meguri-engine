#!/usr/bin/env bash
# Sprint 4 のデモ。使い方：bash demo.sh [コードのディレクトリ] [--rehearse]
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
TOWN="res://src/sample/town_model.gd"

# 自動実行の入口。--no-header で、Godot のバナーが標準出力に混ざらないようにする。
run_auto() {
  godot --headless --no-header --path "$CODE_DIR" -s res://src/auto_run/auto_run_main.gd -- "$@"
}

echo "コード：$CODE_DIR"
echo

echo "== 場面 0: scripts/test.sh を実行する =="
if [ ! -d "$CODE_DIR/addons/gdUnit4" ]; then
  echo "gdUnit4 が無いので scripts/setup.sh を先に実行する"
  (cd "$CODE_DIR" && scripts/setup.sh) || FAIL=1
fi
(cd "$CODE_DIR" && scripts/test.sh)
TEST_CODE=$?
echo "scripts/test.sh の終了コード：$TEST_CODE"
if [ "$TEST_CODE" -ne 0 ]; then
  FAIL=1
fi
echo

echo "== 場面 1: 10万文字の式と、不可視文字10万字の式をモデルに渡す =="
godot --headless --path "$CODE_DIR" -s res://demo/excerpt_demo.gd || FAIL=1
echo

echo "== 場面 2: サンプルの町を、シード 1 で 30 ターン自動で回す =="
echo "コマンド：godot --headless --no-header --path <コード> -s res://src/auto_run/auto_run_main.gd -- --model=$TOWN --turns=30 --seed=1"
run_auto --model="$TOWN" --turns=30 --seed=1
CODE=$?
echo "終了コード：$CODE"
if [ "$CODE" -ne 0 ]; then
  FAIL=1
fi
echo

echo "== 場面 3: 同じ指定で2回回して比べる。上限を超える N と、build の無いクラスも渡す =="
echo "--- 同じ指定で2回（--out でファイルに出し、cmp で比べる） ---"
run_auto --model="$TOWN" --turns=30 --seed=1 --out="$TMP_DIR/a.csv"
CODE=$?
echo "1回目の終了コード：$CODE"
if [ "$CODE" -ne 0 ]; then
  FAIL=1
fi
run_auto --model="$TOWN" --turns=30 --seed=1 --out="$TMP_DIR/b.csv"
CODE=$?
echo "2回目の終了コード：$CODE"
if [ "$CODE" -ne 0 ]; then
  FAIL=1
fi
if cmp "$TMP_DIR/a.csv" "$TMP_DIR/b.csv"; then
  echo "cmp：バイト単位で同じ（$(wc -c < "$TMP_DIR/a.csv") バイト）"
else
  echo "想定外：2回の出力が違う"
  FAIL=1
fi
echo "--- 上限を超える N（100001）。標準エラーに理由が出て、終了コードが 0 以外になるはず ---"
run_auto --model="$TOWN" --turns=100001
CODE=$?
echo "終了コード：$CODE（0 以外になるはず）"
if [ "$CODE" -eq 0 ]; then
  echo "想定外：終了コードが 0"
  FAIL=1
fi
echo "--- build の無いクラス。標準エラーに理由が出て、終了コードが 0 以外になるはず ---"
run_auto --model=res://test/fixtures/no_build_model.gd --turns=3
CODE=$?
echo "終了コード：$CODE（0 以外になるはず）"
if [ "$CODE" -eq 0 ]; then
  echo "想定外：終了コードが 0"
  FAIL=1
fi
echo

echo "== 場面 4: 勝利と敗北の条件を持つモデルを自動で回す =="
echo "--- 条件を式で書いたモデル（勝利・敗北・同時・終了後の呼び出し） ---"
godot --headless --path "$CODE_DIR" -s res://demo/end_condition_demo.gd || FAIL=1
echo "--- 入口から、ターン 5 に勝利するモデルを --turns=30 で回す ---"
run_auto --model=res://test/fixtures/ending_model.gd --turns=30 --seed=1
CODE=$?
echo "終了コード：$CODE"
if [ "$CODE" -ne 0 ]; then
  FAIL=1
fi
echo

if [ "$REHEARSE" = 1 ]; then
  echo "(リハーサル：終了)"
fi
exit "$FAIL"
