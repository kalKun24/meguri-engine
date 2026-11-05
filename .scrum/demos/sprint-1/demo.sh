#!/usr/bin/env bash
# Sprint 1 のデモ。使い方：bash demo.sh [コードのディレクトリ] [--rehearse]
# 待つ場面は無いので、--rehearse は受け取って無視する。
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
cleanup() {
  if [ "$REPORTS_EXISTED" = 0 ]; then
    rm -rf "$CODE_DIR/reports"
  fi
}
trap cleanup EXIT

REPO=kalKun24/meguri-engine
FAIL=0

echo "コード：$CODE_DIR"
echo

echo "== 場面 1: README の手順でテストを実行する =="
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

echo "== 場面 2: PR の Checks 欄と、意図的に失敗させたときの記録を開く =="
echo "draft PR：https://github.com/$REPO/pull/13"
show_run() {
  local id="$1" label="$2"
  echo "--- $label"
  echo "URL：https://github.com/$REPO/actions/runs/$id"
  if command -v gh >/dev/null 2>&1; then
    gh run view "$id" -R "$REPO" || echo "(gh run view に失敗した。URL をブラウザで開く)"
    echo -n "結論："
    gh run view "$id" -R "$REPO" --json conclusion --jq .conclusion || true
  else
    echo "(gh CLI が無いので、URL をブラウザで開く)"
  fi
}
show_run 42022965513 "成功 run"
show_run 42023246682 "成功 run"
show_run 42023098068 "意図的に失敗させた run"
echo

echo "== 場面 3: A→B→C のモデルを3ターン進める =="
echo "== 場面 4: フローの定義順を入れ替えたモデルで同じことをする =="
echo "(1回の実行で、定義順 A->B,B->C と B->C,A->B の2つを順に表示する)"
godot --headless --path "$CODE_DIR" -s res://demo/stock_flow_demo.gd
echo

echo "== 場面 5: 正しい式と誤った式を式のパーサに渡す =="
godot --headless --path "$CODE_DIR" -s res://demo/expr_parse_demo.gd
echo

if [ "$REHEARSE" = 1 ]; then
  echo "(リハーサル：終了)"
fi
exit "$FAIL"
