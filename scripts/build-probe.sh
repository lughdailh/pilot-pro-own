#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p Diagnostics
xcrun swiftc Sources/PilotProbe.swift -o Diagnostics/pilot-probe -framework IOKit -framework Foundation
