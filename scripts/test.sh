#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p build
xcrun swiftc -swift-version 5 -parse-as-library App/Core/*.swift Tests/PilotCoreTests.swift -o build/pilot-core-tests
./build/pilot-core-tests Tests/Fixtures/usb-session-a.txt Tests/Fixtures/usb-session-b.txt
