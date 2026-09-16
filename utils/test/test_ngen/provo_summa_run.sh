#!/bin/bash
# Run the Provo domain through standalone SUMMA, without NextGen.
#
# The bundled file manager holds paths relative to the ngen directory, so this rewrites
# them for a standalone run and sends output to a work directory beside the domain.
set -euo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
SUMMA_ROOT="$(cd "${TEST_DIR}/../../.." && pwd)"
DOMAIN="${TEST_DIR}/domain_provo"
WORK="${DOMAIN}/standalone_run"

SUMMA_EXE="${SUMMA_ROOT}/bin/summa_sundials.exe"
[ -x "${SUMMA_EXE}" ] || SUMMA_EXE="${SUMMA_ROOT}/bin/summa.exe"
if [ ! -x "${SUMMA_EXE}" ]; then
  echo "ERROR: no SUMMA executable in ${SUMMA_ROOT}/bin -- build one first"
  exit 1
fi

mkdir -p "${WORK}"
sed -e "s|^settingsPath .*|settingsPath         '${DOMAIN}/settings/SUMMA/'|" \
    -e "s|^forcingPath .*|forcingPath          '${DOMAIN}/forcing/SUMMA_input/'|" \
    -e "s|^outputPath .*|outputPath           '${WORK}/'|" \
    "${DOMAIN}/settings/SUMMA/fileManager.txt" > "${WORK}/fileManager.txt"

"${SUMMA_EXE}" -p m -m "${WORK}/fileManager.txt"
echo "output written to ${WORK}"
