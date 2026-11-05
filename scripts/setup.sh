#!/usr/bin/env bash
# Meguri の開発環境を導入する。Godot と gdUnit4 を、固定した版で、ユーザのディレクトリに入れる。
# sudo は使わない。版を変えるときは、このファイルと .github/workflows/test.yml と README.md を同時に直す。
set -euo pipefail

GODOT_VERSION="4.7.1"
GODOT_ZIP_SHA512="4ccdab7a48eeccbe8819a2fc1f6262f8d72065d98601bcb3743fcbd7ebd39f373758a788ee3293a05ec5b2c48538266c437404312e372225cd2df273945a2de9"
GDUNIT4_TAG="v6.2.3"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPT_DIR="${HOME}/.local/opt/godot/${GODOT_VERSION}-stable"
BIN_DIR="${HOME}/.local/bin"
ZIP_NAME="Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
BIN_NAME="Godot_v${GODOT_VERSION}-stable_linux.x86_64"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

if [ ! -x "${OPT_DIR}/${BIN_NAME}" ]; then
  echo "Godot ${GODOT_VERSION} を ${OPT_DIR} に導入する"
  curl -fsSL -o "${WORK}/${ZIP_NAME}" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/${ZIP_NAME}"
  echo "${GODOT_ZIP_SHA512}  ${WORK}/${ZIP_NAME}" | sha512sum --check --status
  mkdir -p "${OPT_DIR}"
  unzip -q -o "${WORK}/${ZIP_NAME}" -d "${OPT_DIR}"
  chmod +x "${OPT_DIR}/${BIN_NAME}"
fi
mkdir -p "${BIN_DIR}"
ln -sf "${OPT_DIR}/${BIN_NAME}" "${BIN_DIR}/godot"

if [ ! -f "${ROOT}/addons/gdUnit4/plugin.cfg" ] || ! grep -q "version=\"${GDUNIT4_TAG#v}\"" "${ROOT}/addons/gdUnit4/plugin.cfg"; then
  echo "gdUnit4 ${GDUNIT4_TAG} を ${ROOT}/addons/gdUnit4 に導入する"
  git clone --quiet --depth 1 --branch "${GDUNIT4_TAG}" \
    https://github.com/godot-gdunit-labs/gdUnit4 "${WORK}/gdunit4"
  rm -rf "${ROOT}/addons/gdUnit4"
  mkdir -p "${ROOT}/addons"
  cp -R "${WORK}/gdunit4/addons/gdUnit4" "${ROOT}/addons/gdUnit4"
  rm -rf "${ROOT}/addons/gdUnit4/test"
  chmod +x "${ROOT}/addons/gdUnit4/runtest.sh"
fi

echo "導入が終わった。~/.local/bin が PATH に入っていることを確かめ、godot --version を実行する。"
