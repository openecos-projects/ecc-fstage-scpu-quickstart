#!/usr/bin/env bash
set -euo pipefail

# This script is safe to run repeatedly. Large downloads stay outside git.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
QUICKSTART_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
DEPS_ROOT=${ECC_DEPS_ROOT:-"$QUICKSTART_ROOT/.ecc-deps"}
ECC_VERSION=${ECC_VERSION:-v0.1.0-alpha.10}
YOSYS_RELEASE_TAG=${YOSYS_RELEASE_TAG:-2026-08-08}
YOSYS_RELEASE_DATE=${YOSYS_RELEASE_DATE:-20260808}
PDK_VERSION=${PDK_VERSION:-v1.10.102}

case "$(uname -s):$(uname -m)" in
  Linux:x86_64) ;;
  *)
    printf 'This quickstart installer supports Linux x86_64 only.\n' >&2
    exit 2
    ;;
esac

for command_name in curl tar git make bzip2 sha256sum find; do
  command -v "$command_name" >/dev/null || {
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 2
  }
done

mkdir -p "$DEPS_ROOT/downloads" "$DEPS_ROOT"

ECC_ARCHIVE="$DEPS_ROOT/downloads/ecc-cli-linux-x86_64.tar.gz"
ECC_DIR="$DEPS_ROOT/ecc-${ECC_VERSION#v}"
ECC_URL="https://github.com/openecos-projects/ecc/releases/download/${ECC_VERSION}/ecc-cli-linux-x86_64.tar.gz"
if [[ "$ECC_VERSION" == "v0.1.0-alpha.10" ]]; then
  ECC_SHA256=${ECC_SHA256:-fc3daaca24dddb04ba3490329042f52da05190da03c3831042293dd0cbffdca6}
else
  ECC_SHA256=${ECC_SHA256:-}
fi

if [[ ! -s "$ECC_ARCHIVE" ]]; then
  curl -fL --retry 3 "$ECC_URL" -o "$ECC_ARCHIVE"
fi
if [[ -n "$ECC_SHA256" ]]; then
  printf '%s  %s\n' "$ECC_SHA256" "$ECC_ARCHIVE" | sha256sum -c -
else
  printf 'Warning: ECC_SHA256 is not set; skipping ECC archive verification for %s.\n' \
    "$ECC_VERSION" >&2
fi
mkdir -p "$ECC_DIR"
if [[ -z "$(find "$ECC_DIR" -type f -name ecc -perm -111 -print -quit)" ]]; then
  tar -xzf "$ECC_ARCHIVE" -C "$ECC_DIR"
fi
ECC_BIN=$(find "$ECC_DIR" -type f -name ecc -perm -111 -print -quit)
test -x "$ECC_BIN"

YOSYS_ARCHIVE="$DEPS_ROOT/downloads/oss-cad-suite-linux-x64-${YOSYS_RELEASE_DATE}.tgz"
YOSYS_DIR="$DEPS_ROOT/oss-cad-suite-${YOSYS_RELEASE_DATE}"
YOSYS_URL="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${YOSYS_RELEASE_TAG}/oss-cad-suite-linux-x64-${YOSYS_RELEASE_DATE}.tgz"
if [[ ! -s "$YOSYS_ARCHIVE" ]]; then
  curl -fL --retry 3 "$YOSYS_URL" -o "$YOSYS_ARCHIVE"
fi
mkdir -p "$YOSYS_DIR"
if [[ -z "$(find "$YOSYS_DIR" -type f -path '*/bin/yosys' -perm -111 -print -quit)" ]]; then
  tar -xzf "$YOSYS_ARCHIVE" -C "$YOSYS_DIR"
fi
YOSYS_BIN=$(find "$YOSYS_DIR" -type f -path '*/bin/yosys' -perm -111 -print -quit)
test -x "$YOSYS_BIN"
YOSYS_ROOT=$(cd -- "$(dirname -- "$YOSYS_BIN")/.." && pwd)

PDK_ROOT="$DEPS_ROOT/icsprout55-pdk"
if [[ ! -d "$PDK_ROOT/.git" ]]; then
  git clone --depth 1 --branch "$PDK_VERSION" \
    https://github.com/openecos-projects/icsprout55-pdk.git "$PDK_ROOT"
fi
if [[ ! -f "$PDK_ROOT/IP/STD_cell/ics55_LLSC_H7C_V1p10C100/ics55_LLSC_H7CH/liberty/ics55_LLSC_H7CH_typ_tt_1p2_25_nldm.lib" ]]; then
  make -C "$PDK_ROOT" unzip RELEASE_TAG="$PDK_VERSION"
fi
test -f "$PDK_ROOT/prtech/techLEF/N551P6M_ecos.lef"

ENV_FILE="$QUICKSTART_ROOT/.ecc-release-env"
cat > "$ENV_FILE" <<EOF
export QUICKSTART_ROOT=$(printf '%q' "$QUICKSTART_ROOT")
export ECC_BIN=$(printf '%q' "$ECC_BIN")
export YOSYS_ROOT=$(printf '%q' "$YOSYS_ROOT")
export CHIPCOMPILER_OSS_CAD_DIR=\"\$YOSYS_ROOT\"
export YOSYS_PLUGINPATH=\"\$YOSYS_ROOT/share/yosys/plugins\"
export CHIPCOMPILER_ICS55_PDK_ROOT=$(printf '%q' "$PDK_ROOT")
export PATH=\"\$YOSYS_ROOT/bin:\$PATH\"
EOF

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

printf '\nECC:  %s\nYosys: %s\nPDK:   %s\n' "$ECC_BIN" "$YOSYS_ROOT" "$PDK_ROOT"
printf 'Environment file: %s\n' "$ENV_FILE"
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  printf 'Run `source %s` before invoking ECC.\n' "$ENV_FILE"
fi
