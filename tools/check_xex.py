#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Sanity checks for the built plugin.

usage: check_xex.py <llvm-objdump> <plugin.exe> <plugin.xex>

- the XEX starts with the XEX2 magic and is a DLL;
- the PE has the expected base and its entry point lands on code;
- no floating-point instruction anywhere in the code (DllMain has no FP context);
- the patch table and the "VDR3" state block are in the image.
"""
import re
import struct
import subprocess
import sys

# Match only the mnemonic column of llvm-objdump output
# ("91661014: fa 01 00 20  \tstd 16, 32(1)"); the raw bytes column can contain
# hex like "fa"/"fc" that must not be mistaken for FP mnemonics.
INSN = re.compile(r"^\s*[0-9a-f]+:\s+(?:[0-9a-f]{2}\s){4}\s*([a-z][\w.+-]*)", re.I)
FP = re.compile(r"(lf[sd]u?x?|stf[sd]u?x?|stfiwx|f[a-z]+\.?|mtfsf\w*|mffs\.?)", re.I)


def is_fp(line):
    m = INSN.match(line)
    return bool(m and FP.fullmatch(m.group(1)))


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
    fp = [l for l in dis.splitlines() if is_fp(l)]
    if fp:
        fail("floating-point instructions found:\n" + "\n".join(fp[:10]))
    # The linked image has no symbol table, so check the PE header instead:
    # expected base, and an entry point that lands on disassembled code.
    pe = open(exe, "rb").read()
    if pe[:2] != b"MZ":
        fail("PE image missing MZ header")
    nt = struct.unpack_from("<I", pe, 0x3C)[0]
    if pe[nt:nt + 4] != b"PE\0\0":
        fail("PE signature missing")
    opt = nt + 4 + 20
    if struct.unpack_from("<H", pe, opt)[0] != 0x10B:
        fail("not a PE32 image")
    entry_rva = struct.unpack_from("<I", pe, opt + 16)[0]
    image_base = struct.unpack_from("<I", pe, opt + 28)[0]
    if image_base != 0x91660000:
        fail(f"unexpected image base {image_base:#x} (want 0x91660000)")
    entry = image_base + entry_rva
    if not entry_rva or not re.search(rf"^\s*{entry:08x}:", dis, re.M | re.I):
        fail(f"entry point {entry:#x} is not on disassembled code")

    if b"VDR3"[::-1] not in pe and b"VDR3" not in pe:
        fail("state block (VDR3) missing")
    if struct.pack(">I", 0x39400040) not in pe or struct.pack(">I", 0x41980164) not in pe:
        fail("patch table missing")

    print(f"check_xex: OK ({len(data)} bytes, module flags {module_flags:#x}, "
          f"entry {entry:#x}, no FP)")


if __name__ == "__main__":
    main()
