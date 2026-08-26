#!/usr/bin/env bash

# The installer can be sourced from Bash or Zsh. Resolve this file before
# running the installation in a separate Bash process.
if [[ -n "${BASH_VERSION:-}" ]]; then
  INSTALLER_SCRIPT=${BASH_SOURCE[0]}
  if [[ "$INSTALLER_SCRIPT" == "$0" ]]; then
    INSTALLER_IS_SOURCED=0
  else
    INSTALLER_IS_SOURCED=1
  fi
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  # Keep the Zsh-only expansion out of Bash's parser and ShellCheck.
  eval 'INSTALLER_SCRIPT=${(%):-%x}'
  if [[ "${ZSH_EVAL_CONTEXT:-}" == *:file ]]; then
    INSTALLER_IS_SOURCED=1
  else
    INSTALLER_IS_SOURCED=0
  fi
else
  printf 'This installer must be run or sourced from Bash or Zsh.\n' >&2
  return 2 2>/dev/null || exit 2
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "$INSTALLER_SCRIPT")" && pwd)
QUICKSTART_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
ENV_FILE="$QUICKSTART_ROOT/.ecc-release-env"

install_release_deps() {
  set -euo pipefail

  local deps_root=${ECC_DEPS_ROOT:-"$QUICKSTART_ROOT/.ecc-deps"}
  local download_source=${ECC_DOWNLOAD_SOURCE:-github}
  local gh_proxy_url=${GH_PROXY_URL:-https://gh-proxy.org/}
  local ecc_version=${ECC_VERSION:-v0.1.0-alpha.10}
  local yosys_release_tag=${YOSYS_RELEASE_TAG:-2026-08-08}
  local yosys_release_date=${YOSYS_RELEASE_DATE:-20260808}
  local pdk_version=${PDK_VERSION:-v1.10.102}
  local github_url_prefix
  local command_name

  while (($#)); do
    case "$1" in
      --download-source)
        if (($# < 2)); then
          printf 'Missing value for --download-source.\n' >&2
          return 2
        fi
        download_source=$2
        shift 2
        ;;
      --gh-proxy-url)
        if (($# < 2)); then
          printf 'Missing value for --gh-proxy-url.\n' >&2
          return 2
        fi
        gh_proxy_url=$2
        shift 2
        ;;
      *)
        printf 'Unknown installer option: %s\n' "$1" >&2
        return 2
        ;;
    esac
  done

  case "$download_source" in
    github)
      github_url_prefix=
      ;;
    gh-proxy)
      github_url_prefix="${gh_proxy_url%/}/"
      ;;
    *)
      printf 'Unsupported ECC_DOWNLOAD_SOURCE: %s (expected github or gh-proxy).\n' \
        "$download_source" >&2
      return 2
      ;;
  esac

  case "$(uname -s):$(uname -m)" in
    Linux:x86_64) ;;
    *)
      printf 'This quickstart installer supports Linux x86_64 only.\n' >&2
      return 2
      ;;
  esac

  for command_name in curl tar git make bzip2 sha256sum find cp mv; do
    command -v "$command_name" >/dev/null || {
      printf 'Missing required command: %s\n' "$command_name" >&2
      return 2
    }
  done

  mkdir -p "$deps_root/downloads" "$deps_root"

  download_file() {
    local url=$1
    local output=$2
    local expected_sha256=${3:-}
    local partial="${output}.part"

    if [[ ! -s "$output" ]]; then
      printf 'Downloading %s\n' "$(basename -- "$output")"
      curl -fL --retry 3 --continue-at - "$url" -o "$partial"
      mv -- "$partial" "$output"
    fi
    if [[ -n "$expected_sha256" ]]; then
      printf '%s  %s\n' "$expected_sha256" "$output" | sha256sum -c -
    fi
  }

  local ecc_archive="$deps_root/downloads/ecc-cli-linux-x86_64.tar.gz"
  local ecc_dir="$deps_root/ecc-${ecc_version#v}"
  local ecc_url="${github_url_prefix}https://github.com/openecos-projects/ecc/releases/download/${ecc_version}/ecc-cli-linux-x86_64.tar.gz"
  local ecc_sha256
  if [[ "$ecc_version" == "v0.1.0-alpha.10" ]]; then
    ecc_sha256=${ECC_SHA256:-fc3daaca24dddb04ba3490329042f52da05190da03c3831042293dd0cbffdca6}
  else
    ecc_sha256=${ECC_SHA256:-}
  fi

  if [[ -n "$ecc_sha256" ]]; then
    download_file "$ecc_url" "$ecc_archive" "$ecc_sha256"
  else
    printf 'Warning: ECC_SHA256 is not set; skipping ECC archive verification for %s.\n' \
      "$ecc_version" >&2
    download_file "$ecc_url" "$ecc_archive"
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
  local yosys_url="${github_url_prefix}https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${yosys_release_tag}/oss-cad-suite-linux-x64-${yosys_release_date}.tgz"
  local yosys_sha256
  if [[ "$yosys_release_tag:$yosys_release_date" == "2026-08-08:20260808" ]]; then
    yosys_sha256=${YOSYS_SHA256:-826f6ceb8d60126de48305078694bb9738091af78b3bbddd8332df9341bcdb94}
  else
    yosys_sha256=${YOSYS_SHA256:-}
  fi
  download_file "$yosys_url" "$yosys_archive" "$yosys_sha256"
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
  local pdk_repo_url="${github_url_prefix}https://github.com/openecos-projects/icsprout55-pdk.git"
  if [[ ! -d "$pdk_root/.git" ]]; then
    git clone --depth 1 --branch "$pdk_version" "$pdk_repo_url" "$pdk_root"
  fi
  if [[ ! -f "$pdk_root/IP/STD_cell/ics55_LLSC_H7C_V1p10C100/ics55_LLSC_H7CH/liberty/ics55_LLSC_H7CH_typ_tt_1p2_25_nldm.lib" ]]; then
    local pdk_download_dir="$deps_root/downloads/icsprout55-pdk-${pdk_version#v}"
    local pdk_asset
    local pdk_asset_url
    local pdk_asset_sha256
    local -a pdk_assets=(
      ics55_LLSC_H7CH_liberty.tar.bz2
      ics55_LLSC_H7CL_liberty.tar.bz2
      ics55_LLSC_H7CR_liberty.tar.bz2
      ics55_LLSC_H7CH_gds.tar.bz2
      ics55_LLSC_H7CL_gds.tar.bz2
      ics55_LLSC_H7CR_gds.tar.bz2
      ICsprout_55LLULP1233_IO_251013_gds.tar.bz2
    )
    local -A pdk_v1_10_102_sha256=(
      [ics55_LLSC_H7CH_liberty.tar.bz2]=bb79e74960dec7032295e621933410f51963b9cafbd956a196148d44fe27fb2c
      [ics55_LLSC_H7CL_liberty.tar.bz2]=c2e7a1eea77772582414108fce178a0f444a61bd4e3ce0a2811ef27caa719fa8
      [ics55_LLSC_H7CR_liberty.tar.bz2]=ef33eec4cd5f617d3dd0073122e556df06560dd65eebf805648640038dedc2b7
      [ics55_LLSC_H7CH_gds.tar.bz2]=6268684fdd0784087adc1a972125f9001bc9761c3142ab954d2a9eade53d5490
      [ics55_LLSC_H7CL_gds.tar.bz2]=9a643ae864d178f45fec4aa59dc98f0420894760d8a431ce0fd640b97e1c2f68
      [ics55_LLSC_H7CR_gds.tar.bz2]=525a7a486e15e36888e4ce08887c946cd16c60dc2c90819fb493d865ed38cc2b
      [ICsprout_55LLULP1233_IO_251013_gds.tar.bz2]=47d248be322a6f054a0ab11fe2f2ee83ad76f9ce15d6f4cd53a81c8d08c7693b
    )

    mkdir -p "$pdk_download_dir"
    for pdk_asset in "${pdk_assets[@]}"; do
      pdk_asset_url="${github_url_prefix}https://github.com/openecos-projects/icsprout55-pdk/releases/download/${pdk_version}/${pdk_asset}"
      if [[ "$pdk_version" == "v1.10.102" ]]; then
        pdk_asset_sha256=${pdk_v1_10_102_sha256[$pdk_asset]}
      else
        pdk_asset_sha256=
      fi
      download_file "$pdk_asset_url" "$pdk_download_dir/$pdk_asset" "$pdk_asset_sha256"
      cp -- "$pdk_download_dir/$pdk_asset" "$pdk_root/$pdk_asset"
    done
    make -C "$pdk_root" unzip RELEASE_TAG="$pdk_version"
  fi
  test -f "$pdk_root/prtech/techLEF/N551P6M_ecos.lef"

  cat > "$ENV_FILE" <<EOF
export QUICKSTART_ROOT=$(printf '%q' "$QUICKSTART_ROOT")
export ECC_BIN=$(printf '%q' "$ecc_bin")
export YOSYS_ROOT=$(printf '%q' "$yosys_root")
export CHIPCOMPILER_OSS_CAD_DIR="\$YOSYS_ROOT"
export YOSYS_PLUGINPATH="\$YOSYS_ROOT/share/yosys/plugins"
export CHIPCOMPILER_ICS55_PDK_ROOT=$(printf '%q' "$pdk_root")
export PATH="\$YOSYS_ROOT/bin:\$PATH"
EOF

  printf '\nECC:  %s\nYosys: %s\nPDK:   %s\n' "$ecc_bin" "$yosys_root" "$pdk_root"
  printf 'Environment file: %s\n' "$ENV_FILE"
}

if [[ "$INSTALLER_IS_SOURCED" == 0 ]]; then
  if [[ -n "${BASH_VERSION:-}" ]]; then
    install_release_deps "$@"
    printf 'Run `source %s` before invoking ECC.\n' "$ENV_FILE"
  else
    exec bash "$INSTALLER_SCRIPT" "$@"
  fi
else
  # Run a separate copy so strict options and failures cannot exit the
  # interactive shell that sourced this file. Load exports only on success.
  if command bash "$INSTALLER_SCRIPT" "$@"; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
  else
    installer_status=$?
    return "$installer_status"
  fi
fi
