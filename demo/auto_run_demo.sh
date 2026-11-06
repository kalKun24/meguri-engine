#!/usr/bin/env bash
# 自動実行（N ターン回して CSV を出す入口）のデモ。リポジトリの直下で実行する。
# 使い方：demo/auto_run_demo.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
cd "${ROOT}" || exit 1

TOWN="res://src/sample/town_model.gd"
# 入口。--no-header で、Godot のバナーが標準出力に混ざらないようにする。
run() {
  "${GODOT_BIN}" --headless --no-header --path . -s res://src/auto_run/auto_run_main.gd -- "$@"
}

WORK="$(mktemp -d)"
trap 'rm -f "${WORK}/a.csv" "${WORK}/b.csv" "${WORK}/out.csv"; rmdir "${WORK}"' EXIT

echo "== 1. サンプルの町を、シード 1 で 30 ターン回し、CSV を標準出力に出す =="
run --model="${TOWN}" --turns=30 --seed=1
echo "終了コード：$?"

echo
echo "== 2. 同じ指定で2回回して、ファイルに出し、cmp で比べる =="
run --model="${TOWN}" --turns=30 --seed=1 --out="${WORK}/a.csv"
echo "1回目の終了コード：$?"
run --model="${TOWN}" --turns=30 --seed=1 --out="${WORK}/b.csv"
echo "2回目の終了コード：$?"
if cmp "${WORK}/a.csv" "${WORK}/b.csv"; then
  echo "cmp：バイト単位で同じ（$(wc -c < "${WORK}/a.csv") バイト）"
fi

echo
echo "== 3. 上限を超える N（100001）は、実行の前に Error になる =="
run --model="${TOWN}" --turns=100001
echo "終了コード：$?"

echo
echo "== 4. build の無いクラスは Error になる =="
run --model=res://test/fixtures/no_build_model.gd --turns=3
echo "終了コード：$?"

echo
echo "== 5. 実行時エラー（ターン 4 で 0 除算）は、そのターンまでの CSV を標準出力に、理由を標準エラーに出す =="
run --model=res://test/fixtures/failing_model.gd --turns=10 --seed=5 2> "${WORK}/out.csv"
echo "終了コード：$?"
echo "--- 標準エラー ---"
cat "${WORK}/out.csv"

echo
echo "== 6. 出力先の親ディレクトリが無いと Error になる =="
run --model="${TOWN}" --turns=3 --out="${WORK}/no_such_dir/out.csv"
echo "終了コード：$?"
