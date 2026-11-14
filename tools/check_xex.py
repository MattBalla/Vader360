#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Sanity checks for the built plugin.

usage: check_xex.py <llvm-objdump> <plugin.exe> <plugin.xex>

- the XEX starts with the XEX2 magic and is a DLL with the expected entry point;
- no floating-point instruction anywhere in the code (DllMain has no FP context);
- the patch table and the "VDR3" state block are in the image.
"""
import re
import struct
import subprocess
import sys

FP = re.compile(r"\s(lf[sd]u?x?|stf[sd]u?x?|stfiwx|f[a-z]+\.?|mtfsf\w*|mffs\.?)\s", re.I)


def fail(msg):
    print(f"check_xex: FAIL: {msg}")
    sys.exit(1)


def main():
    if len(sys.argv) != 4:
        fail(__doc__)
    objdump, exe, xex = sys.argv[1:]

    data = open(xex, "rb").read()
    if data[:4] != b"XEX2":
        fail("missing XEX2 magic")
    module_flags = struct.unpack(">I", data[4:8])[0]
    if not module_flags & 0x8:  # XEX_MOD_FLAG_DLL
        fail(f"not a DLL (module flags {module_flags:#x})")

    dis = subprocess.run([objdump, "-d", exe], capture_output=True, text=True, check=True).stdout
    fp = [l for l in dis.splitlines() if FP.search(l + " ")]
    if fp:
        fail("floating-point instructions found:\n" + "\n".join(fp[:10]))
    if "<DllMain>" not in dis or "<vader360_dllmain>" not in dis:
        fail("DllMain / vader360_dllmain not found in the image")

    pe = open(exe, "rb").read()
    if b"VDR3"[::-1] not in pe and b"VDR3" not in pe:
        fail("state block (VDR3) missing")
    if struct.pack(">I", 0x39400040) not in pe or struct.pack(">I", 0x41980164) not in pe:
        fail("patch table missing")

    print(f"check_xex: OK ({len(data)} bytes, module flags {module_flags:#x}, no FP)")


if __name__ == "__main__":
    main()
