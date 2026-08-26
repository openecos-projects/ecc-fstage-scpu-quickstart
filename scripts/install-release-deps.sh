#!/usr/bin/env bash

# The installer can be sourced. Keep its strict shell options inside the
# installer function so the caller's Bash session is not terminated or changed.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
QUICKSTART_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
ENV_FILE="$QUICKSTART_ROOT/.ecc-release-env"

install_release_deps() {
  set -euo pipefail

  local deps_root=${ECC_DEPS_ROOT:-"$QUICKSTART_ROOT/.ecc-deps"}
  local ecc_version=${ECC_VERSION:-v0.1.0-alpha.10}
  local yosys_release_tag=${YOSYS_RELEASE_TAG:-2026-08-08}
  local yosys_release_date=${YOSYS_RELEASE_DATE:-20260808}
  local pdk_version=${PDK_VERSION:-v1.10.102}
  local command_name

  case "$(uname -s):$(uname -m)" in
    Linux:x86_64) ;;
    *)
      printf 'This quickstart installer supports Linux x86_64 only.\n' >&2
      return 2
      ;;
  esac

  for command_name in curl tar git make bzip2 sha256sum find; do
    command -v "$command_name" >/dev/null || {
      printf 'Missing required command: %s\n' "$command_name" >&2
      return 2
    }
  done

  mkdir -p "$deps_root/downloads" "$deps_root"

  local ecc_archive="$deps_root/downloads/ecc-cli-linux-x86_64.tar.gz"
  local ecc_dir="$deps_root/ecc-${ecc_version#v}"
  local ecc_url="https://github.com/openecos-projects/ecc/releases/download/${ecc_version}/ecc-cli-linux-x86_64.tar.gz"
  local ecc_sha256
  if [[ "$ecc_version" == "v0.1.0-alpha.10" ]]; then
    ecc_sha256=${ECC_SHA256:-fc3daaca24dddb04ba3490329042f52da05190da03c3831042293dd0cbffdca6}
  else
    ecc_sha256=${ECC_SHA256:-}
  fi

  if [[ ! -s "$ecc_archive" ]]; then
    curl -fL --retry 3 "$ecc_url" -o "$ecc_archive"
  fi
  if [[ -n "$ecc_sha256" ]]; then
    printf '%s  %s\n' "$ecc_sha256" "$ecc_archive" | sha256sum -c -
  else
    printf 'Warning: ECC_SHA256 is not set; skipping ECC archive verification for %s.\n' \
      "$ecc_version" >&2
  fi
  mkdir -p "$ecc_dir"
  if [[ -z "$(find "$ecc_dir" -type f -name ecc -perm -111 -print -quit)" ]]; then
    tar -xzf "$ecc_archive" -C "$ecc_dir"
  fi
  local ecc_bin
  ecc_bin=$(find "$ecc_dir" -type f -name ecc -perm -111 -print -quit)
  test -x "$ecc_bin"

  local yosys_archive="$deps_root/downloads/oss-cad-suite-linux-x64-${yosys_release_date}.tgz"
  local yosys_dir="$deps_root/oss-cad-suite-${yosys_release_date}"
  local yosys_url="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${yosys_release_tag}/oss-cad-suite-linux-x64-${yosys_release_date}.tgz"
  if [[ ! -s "$yosys_archive" ]]; then
    curl -fL --retry 3 "$yosys_url" -o "$yosys_archive"
  fi
  mkdir -p "$yosys_dir"
  if [[ -z "$(find "$yosys_dir" -type f -path '*/bin/yosys' -perm -111 -print -quit)" ]]; then
    tar -xzf "$yosys_archive" -C "$yosys_dir"
  fi
  local yosys_bin
  yosys_bin=$(find "$yosys_dir" -type f -path '*/bin/yosys' -perm -111 -print -quit)
  test -x "$yosys_bin"
  local yosys_root
  yosys_root=$(cd -- "$(dirname -- "$yosys_bin")/.." && pwd)

  local pdk_root="$deps_root/icsprout55-pdk"
  if [[ ! -d "$pdk_root/.git" ]]; then
    git clone --depth 1 --branch "$pdk_version" \
      https://github.com/openecos-projects/icsprout55-pdk.git "$pdk_root"
  fi
  if [[ ! -f "$pdk_root/IP/STD_cell/ics55_LLSC_H7C_V1p10C100/ics55_LLSC_H7CH/liberty/ics55_LLSC_H7CH_typ_tt_1p2_25_nldm.lib" ]]; then
    make -C "$pdk_root" unzip RELEASE_TAG="$pdk_version"
  fi
  test -f "$pdk_root/prtech/techLEF/N551P6M_ecos.lef"

  cat > "$ENV_FILE" <<EOF
export QUICKSTART_ROOT=$(printf '%q' "$QUICKSTART_ROOT")
export ECC_BIN=$(printf '%q' "$ecc_bin")
export YOSYS_ROOT=$(printf '%q' "$yosys_root")
export CHIPCOMPILER_OSS_CAD_DIR=\"\$YOSYS_ROOT\"
export YOSYS_PLUGINPATH=\"\$YOSYS_ROOT/share/yosys/plugins\"
export CHIPCOMPILER_ICS55_PDK_ROOT=$(printf '%q' "$pdk_root")
export PATH=\"\$YOSYS_ROOT/bin:\$PATH\"
EOF

  printf '\nECC:  %s\nYosys: %s\nPDK:   %s\n' "$ecc_bin" "$yosys_root" "$pdk_root"
  printf 'Environment file: %s\n' "$ENV_FILE"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  install_release_deps "$@"
  printf 'Run `source %s` before invoking ECC.\n' "$ENV_FILE"
else
  # Run a separate copy so strict options and failures cannot exit the
  # interactive shell that sourced this file. Load exports only on success.
  if "$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")" "$@"; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
  else
    installer_status=$?
    return "$installer_status"
  fi
fi
