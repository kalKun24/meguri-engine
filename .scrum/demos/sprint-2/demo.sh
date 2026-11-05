#!/usr/bin/env bash
# Sprint 2 のデモ。使い方：bash demo.sh [コードのディレクトリ] [--rehearse]
# --rehearse を付けると、場面 4 の入力（Enter 12 回と q）を自動で渡して最後まで進む。
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

echo "コード：$CODE_DIR"
echo

echo "== 場面 0: README の手順でテストを実行する =="
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

echo "== 場面 1: 壊れた定義（NaN の初期値・無限大の量・空の名前・未定義の名前）を SimModel に渡す =="
godot --headless --path "$CODE_DIR" -s res://demo/model_validation_demo.gd || FAIL=1
echo

echo "== 場面 2・3: フローを式で書いたモデルを進める。0 除算と OS.get_name() を含むモデルも動かす =="
godot --headless --path "$CODE_DIR" -s res://demo/flow_expression_demo.gd || FAIL=1
echo

echo "== 場面 4: テキスト版の町を起動し、Enter で 12 ターン進めて q で終える =="
TOWN_CMD="godot --headless --path $CODE_DIR -s res://demo/text_town.gd"
echo "起動するコマンド：$TOWN_CMD"
if [ "$REHEARSE" = 1 ]; then
  INPUT="$TMP_DIR/town_input.txt"
  : > "$INPUT"
  for _ in $(seq 1 12); do
    echo "" >> "$INPUT"
  done
  echo "q" >> "$INPUT"
  echo "(リハーサル：Enter 12 回と q を自動で入力する)"
  $TOWN_CMD < "$INPUT" || FAIL=1
else
  echo "(Enter で 1 ターン進む。12 ターンほど進めたら q で終える)"
  $TOWN_CMD || FAIL=1
fi
echo

if [ "$REHEARSE" = 1 ]; then
  echo "(リハーサル：終了)"
fi
exit "$FAIL"
