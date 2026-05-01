#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAVIO_CORE_DIR="${NAVIO_CORE_DIR:-/Users/alex/dev/navio-core}"
OUT_BIN="${OUT_BIN:-/tmp/pops_verify_bench}"
MIN_TOTAL_MS="${MIN_TOTAL_MS:-1000}"

CXX="${CXX:-c++}"
CXXFLAGS=(
  -std=c++20
  -O3
  -DNDEBUG
  -DHAVE_CONFIG_H
  -I"${NAVIO_CORE_DIR}/src"
  -I"${NAVIO_CORE_DIR}/src/config"
  -I"${NAVIO_CORE_DIR}/src/univalue/include"
  -I"${NAVIO_CORE_DIR}/src/minisketch/include"
  -I"${NAVIO_CORE_DIR}/src/secp256k1/include"
  -I"${NAVIO_CORE_DIR}/src/secp256k1/src"
  -I"${NAVIO_CORE_DIR}/src/leveldb/include"
  -I"${NAVIO_CORE_DIR}/src/crc32c/include"
  -I"${NAVIO_CORE_DIR}/src/bls/include"
  -I"${NAVIO_CORE_DIR}/src/bls/mcl/include"
)

LIBS=(
  "${NAVIO_CORE_DIR}/src/libblsct.a"
  "${NAVIO_CORE_DIR}/src/bls/lib/libbls384_256.a"
  "${NAVIO_CORE_DIR}/src/bls/mcl/lib/libmcl.a"
  "${NAVIO_CORE_DIR}/src/secp256k1/.libs/libsecp256k1.a"
)

LDFLAGS=(
  -pthread
)

"${CXX}" \
  "${SCRIPT_DIR}/pops_verify_bench.cpp" \
  "${NAVIO_CORE_DIR}/src/arith_uint256.cpp" \
  "${NAVIO_CORE_DIR}/src/blsct/pos/proof.cpp" \
  "${NAVIO_CORE_DIR}/src/blsct/pos/helpers.cpp" \
  "${CXXFLAGS[@]}" \
  "${LIBS[@]}" \
  "${LDFLAGS[@]}" \
  -o "${OUT_BIN}"

"${OUT_BIN}" --min-total-ms="${MIN_TOTAL_MS}" "$@"
