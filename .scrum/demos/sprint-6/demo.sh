#!/usr/bin/env bash
# Sprint 6 のデモ。使い方：bash demo.sh [コードのディレクトリ] [--rehearse]
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
sed 's/\x1b\[[0-9;]*m//g' "$TMP_DIR/test.log" | grep -a 'Overall Summary\|Exit code\|ERROR'
echo "scripts/test.sh の終了コード：$TEST_CODE"
echo "ERROR の行数：$(grep -ac 'ERROR' "$TMP_DIR/test.log")（debugger ポートの既知の2行だけのはず）"
echo "WARNING・leaked・still in use の行数：$(grep -aci 'WARNING\|leaked\|still in use' "$TMP_DIR/test.log")（0 のはず）"
if [ "$TEST_CODE" -ne 0 ]; then
  echo "失敗したテストの抜粋："
  grep -a 'FAILED' "$TMP_DIR/test.log" | sed 's/\x1b\[[0-9;]*m//g' | head -20
  FAIL=1
fi
echo

echo "== 場面 1: 終わったゲームの定義を呼び続ける。条件990個のモデルで1ターンを測る =="
echo "--- 勝利して終わった後に、定義の関数11個を順に呼ぶ（全行が Locked、値は変わらない） ---"
run_script res://demo/freeze_demo.gd || FAIL=1
echo
echo "--- 条件990個×761文字のモデルは、#45 の上限（100000 命令）で作れなくなった（131個目で拒否される） ---"
run_script res://demo/condition_perf_demo.gd -- --conditions=990 --length=761 --turns=1 > "$TMP_DIR/over.log" 2>&1
head -n 2 "$TMP_DIR/over.log"
echo
echo "--- 1ターンの時間（形A：定数が変わらない、形B：毎ターン定数が変わる） ---"
echo "変更前（#37 の報告の測定。この場では測らない。条件990個×761文字、約 99 万命令）：形A 約 4208 ms/ターン（4195, 4164, 4266）、形B 約 4573 ms/ターン"
echo "変更後（今から測る。2ターン。上限に収まる形で測る。形Aの1ターン目は組み立てを含み、2ターン目からは組み立てを使い回す）"
echo "条件131個×761文字（約 10 万命令）："
run_script res://demo/condition_perf_demo.gd -- --conditions=131 --length=761 --turns=2 || FAIL=1
echo "条件990個×99文字（個数の最大、約 10 万命令）："
run_script res://demo/condition_perf_demo.gd -- --conditions=990 --length=99 --turns=2 || FAIL=1
echo "（形Bは定数が変わるたびに全条件を組み立て直すので、#46 まで下がらない。ただし上限で約 10 万命令に抑えられ、1ターン約 0.6 秒で止まる）"
echo

echo "== 場面 2: 命令数の上限を超える定義を足す。上限いっぱいのモデルとファンアウトのモデルを1ターン進める =="
echo "--- 拒否（補助変数・条件・フロー）、アクションの式も上限に入ること、5つの形の1ターンの時間 ---"
run_script res://demo/ops_limit_demo.gd -- --turns=2 || FAIL=1
echo "（アクションの式が上限に入ること：「アクションの定義の時間とメモリ」の節で、受け付けたアクションは 2 個、3 個目が Out of memory で拒否される）"
echo

echo "== 場面 3: 下限0・上限100の食料（50）に food = food + 1000 のアクションを適用する =="
run_script res://demo/action_range_demo.gd || FAIL=1
echo

if [ "$REHEARSE" = 1 ]; then
  echo "(リハーサル：終了)"
fi
exit "$FAIL"
