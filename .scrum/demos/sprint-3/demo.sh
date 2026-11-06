#!/usr/bin/env bash
# Sprint 3 のデモ。使い方：bash demo.sh [コードのディレクトリ] [--rehearse]
# --rehearse を付けると、場面 4 の入力を自動で渡して最後まで進む。
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

echo "== 場面 1: ゴールデン値のテストを実行し、町の定数を 1 つ変えてもう一度実行する =="
# 元のコードは書き換えない。一時ディレクトリにコピーし、コピーの側で定数を変える。
COPY_DIR="$TMP_DIR/code_copy"
mkdir -p "$COPY_DIR"
(cd "$CODE_DIR" && tar --exclude=./.git --exclude=./.claude --exclude=./.scrum --exclude=./reports -cf - .) | (cd "$COPY_DIR" && tar -xf -)
GOLDEN_TEST="res://test/sample/town_golden_test.gd"
run_golden() {
  (cd "$COPY_DIR" && godot --headless --path "$COPY_DIR" -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a "$GOLDEN_TEST")
}
echo "--- 1 回目：変更なし（通るはず） ---"
run_golden
FIRST_CODE=$?
echo "終了コード：$FIRST_CODE"
if [ "$FIRST_CODE" -ne 0 ]; then
  FAIL=1
fi
echo
echo "--- 2 回目：コピーの src/sample/town_model.gd で birth_rate を 0.08 から 0.09 に変える（元のコードは変えない） ---"
sed -i 's/"birth_rate": 0.08,/"birth_rate": 0.09,/' "$COPY_DIR/src/sample/town_model.gd"
grep -n '"birth_rate"' "$COPY_DIR/src/sample/town_model.gd"
run_golden
SECOND_CODE=$?
echo "終了コード：$SECOND_CODE（0 以外になるはず）"
if [ "$SECOND_CODE" -eq 0 ]; then
  echo "想定外：定数を変えたのにゴールデン値のテストが通った"
  FAIL=1
fi
echo

echo "== 場面 2: 右から左の文字・ゼロ幅の文字・異体字選択子を含む名前や式を渡す =="
godot --headless --path "$CODE_DIR" -s res://demo/escape_demo.gd || FAIL=1
echo

echo "== 場面 3: 畑を広げるアクションを、お金が足りるときと足りないときに実行する =="
godot --headless --path "$CODE_DIR" -s res://demo/action_demo.gd || FAIL=1
echo

echo "== 場面 4: テキスト版の町を 2 回動かして比べる（何もしない場合と、アクションを選ぶ場合） =="
TOWN_CMD="godot --headless --path $CODE_DIR -s res://demo/text_town.gd"
echo "起動するコマンド：$TOWN_CMD"
if [ "$REHEARSE" = 1 ]; then
  IDLE_INPUT="$TMP_DIR/town_idle.txt"
  ACT_INPUT="$TMP_DIR/town_action.txt"
  : > "$IDLE_INPUT"
  for _ in $(seq 1 6); do
    echo "" >> "$IDLE_INPUT"
  done
  echo "q" >> "$IDLE_INPUT"
  printf '1\n2\n2\n' > "$ACT_INPUT"
  for _ in $(seq 1 6); do
    echo "" >> "$ACT_INPUT"
  done
  echo "q" >> "$ACT_INPUT"
  echo "--- 何もしない場合（リハーサル：Enter 6 回と q） ---"
  $TOWN_CMD < "$IDLE_INPUT" || FAIL=1
  echo
  echo "--- アクションを選ぶ場合（リハーサル：1 畑を広げる、2 税率を上げる、2 税率を上げる、Enter 6 回、q） ---"
  $TOWN_CMD < "$ACT_INPUT" || FAIL=1
else
  echo "(Enter で 1 ターン進む。番号か名前でアクションを選ぶ。1 は「畑を広げる」、2 は「税率を上げる」。q で終える)"
  echo "(1 回目は何もせず Enter だけで数ターン進め、2 回目は同じ起動で「畑を広げる」「税率を変える」を選んで、推移を比べる)"
  $TOWN_CMD || FAIL=1
fi
echo

if [ "$REHEARSE" = 1 ]; then
  echo "(リハーサル：終了)"
fi
exit "$FAIL"
