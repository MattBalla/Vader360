# Building

Vader360 is built with [OpenXeChain](https://github.com/OpenXeChain), an open-source
Xbox 360 toolchain: an LLVM/clang fork targeting `ppc32-xbox360`, lld-link, Newlib,
xecorelib (kernel import stubs and headers) and SynthXEX (PE -> XEX2). No Microsoft XDK
is used.

## GitHub Actions (recommended)

`.github/workflows/build.yml` does everything:

1. builds OpenXeChain from source at a pinned `buildscript` commit (the first run takes
   about 2-3 hours; the result is cached);
2. builds `synthxex-patched`, SynthXEX with the system-DLL patch from
   [Jacckii/Xbox360-Series-Controllers-Bridge](https://github.com/Jacckii/Xbox360-Series-Controllers-Bridge/tree/main/toolchain)
   (GPL-3.0, downloaded at a pinned commit and only run in CI);
3. runs `build.sh` and uploads `vader360.xex` as an artifact;
4. on a `v*` tag, publishes a release with the zip, the `.xex` and `SHA256SUMS.txt`.

## Local build (Linux)

1. Build OpenXeChain as described in its `buildscript` repository (or follow the steps of the
   workflow), installing it to a prefix such as `/opt/openxechain`.
2. Build `synthxex-patched`:

   ```bash
   cp -r <buildscript>/synthxex /tmp/sx
   (cd /tmp/sx/src && python3 /path/to/synthxex_dll_patch.py)
   (cd /tmp/sx && gcc -O2 -Iinclude $(find src include -name '*.c') -o /opt/openxechain/bin/synthxex-patched)
   ```

3. Build the plugin:

   ```bash
   OXC=/opt/openxechain bash build.sh
   ```

   `build.sh` links the plugin as a system DLL at 0x91660000 (`/entry:DllMain`, 4 KB alignment),
   converts it with `synthxex-patched -t sysdll` and runs `tools/check_xex.py`, which fails the
   build if the XEX is not a DLL, if any floating-point instruction slipped in, or if the patch
   table is missing.

## Toolchain notes

- Never pass `-g`: the toolchain's clang crashes while emitting DWARF into COFF.
- `lld-link: warning: /align specified without /driver` is expected.
- Keep at least one initialised, non-const global (`g_vader360_state`): SynthXEX 0.0.5 fails when
  the last PE section has no raw data, and `-fno-zero-initialized-in-bss` keeps zeroed data inside
  the image.
