#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TASK_BUILD=$(mktemp -d "${TMPDIR:-/tmp}/himorning-core.XXXXXX")
trap 'rm -rf "$TASK_BUILD"' EXIT
swiftc -swift-version 6 -profile-generate -profile-coverage-mapping "$TASK_ROOT"/apps/ios/HiMorningCore/Sources/HiMorningCore/*.swift "$TASK_ROOT"/apps/ios/HiMorningCore/TestsPortable/main.swift -o "$TASK_BUILD/tests"
LLVM_PROFILE_FILE="$TASK_BUILD/core.profraw" "$TASK_BUILD/tests" "$TASK_ROOT/shared/contracts/v1"
xcrun llvm-profdata merge -sparse "$TASK_BUILD/core.profraw" -o "$TASK_BUILD/core.profdata"
xcrun llvm-cov report "$TASK_BUILD/tests" -instr-profile="$TASK_BUILD/core.profdata" "$TASK_ROOT"/apps/ios/HiMorningCore/Sources/HiMorningCore/*.swift
