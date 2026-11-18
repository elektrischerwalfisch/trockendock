#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Trockendock — interactive menu entry point
# Author: elektrischerwalfisch
#
# See LICENSE and VERSION at repository root.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config/load-paths.sh
source "${ROOT}/config/load-paths.sh"
exec bash "${ROOT}/bin/menu.sh"
