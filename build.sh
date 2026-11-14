#!/bin/bash
# SPDX-License-Identifier: MIT
# Builds out/vader360.xex with OpenXeChain (no Microsoft XDK).
#
#   OXC=/path/to/openxechain/prefix bash build.sh
#
# Needs $OXC/bin/clang, $OXC/bin/llvm-objdump and $OXC/bin/synthxex-patched
# (SynthXEX with the system-DLL patch, see docs/BUILDING.md).
set -euo pipefail
cd "$(dirname "$0")"
TC=${OXC:-/opt/openxechain}
unset C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH

# System DLLs load only at their own base. 0x91660000-0x91680000 sits in the gap
# between hud.xex and ximecore.xex that system modules and known plugins leave free.
BASE=0x91660000

# -fno-zero-initialized-in-bss: SynthXEX maps only the bytes stored in the PE file.
# -msoft-float: DllMain runs without an FP context; no FP instruction may appear.
# Never -g: the toolchain's clang crashes emitting DWARF into COFF.
CFLAGS="-O2 -Wall -Wextra -fno-zero-initialized-in-bss -msoft-float"
LDFLAGS="-Wl,/entry:DllMain,/base:$BASE,/align:0x1000"

mkdir -p out
"$TC/bin/clang" $CFLAGS $LDFLAGS src/entry.S src/vader360.c -o out/vader360.exe
"$TC/bin/synthxex-patched" -i out/vader360.exe -o out/vader360.xex -t sysdll

python3 tools/check_xex.py "$TC/bin/llvm-objdump" out/vader360.exe out/vader360.xex
sha256sum out/vader360.xex | tee out/vader360.xex.sha256
