# Vader360

**Flydigi Vader 3 on a retail Xbox 360: a tiny DashLaunch plugin for Bad Update / XeUnshackle (kernel 17559).**

[Português (Brasil)](README.pt-BR.md)

The Flydigi Vader 3 receiver (XInput mode, white LED) enumerates as an Xbox 360
controller (`045E:028E`), but the 360 kernel still refuses it: its wired-gamepad
driver expects 32-byte interrupt endpoints and 20-byte input reports, and the
receiver uses 64-byte endpoints and 32-byte reports. XeUnshackle already lets
third-party XInput controllers past the USB security check; Vader360 fixes the
two remaining checks so the receiver works.

The plugin is a separate `vader360.xex`. You keep the official XeUnshackle (or
XeUnshackle Max) build and nothing else has to be modified.

## Features

- Two single-instruction kernel patches, in RAM only (gone after power-off, like the exploit).
- Checks the code around every patch site first, and changes **nothing** if anything
  differs from kernel 2.0.17559.0 or if the console is already patched.
- No floating point, no threads, no hooks: it patches, logs to the debug output and stays idle.
- Built with the open-source [OpenXeChain](https://github.com/OpenXeChain) toolchain,
  with no Microsoft XDK, by GitHub Actions.

## Requirements

- Xbox 360 on dashboard **2.0.17559.0**, running **Bad Update** or **ABadAvatar** with
  **XeUnshackle** or **[XeUnshackle Max](https://github.com/klofi/XeUnshackle-Max)**
  (they load DashLaunch plugins from `launch.ini`).
- Flydigi Vader 3 with its 2.4 GHz receiver in **XInput mode (white LED)**.

## Installation

1. Download `Vader360-<version>.zip` from the [latest release](../../releases/latest).
2. Copy `Plugins\vader360.xex` to your internal HDD (`Hdd:\Plugins\`) or your USB stick (`Usb:\Plugins\`).
3. Add it to a free slot of the `[Plugins]` section of `launch.ini` (root of the USB stick):

   ```ini
   [Plugins]
   plugin1 = Usb:\Xbdm.xex
   plugin2 = Hdd:\Plugins\vader360.xex
   ```

4. Run the exploit as usual. DashLaunch loads the plugin when you leave XeUnshackle.
5. Plug in the receiver **after** you reach the dashboard (or re-plug it): the kernel only
   evaluates a controller when it is connected.

## Checking that it worked

With `Xbdm.xex` loaded, from a Windows PC:

```powershell
powershell -ExecutionPolicy Bypass -File vader360-check.ps1 -Ip <console IP>
```

It reports whether both patches are active. `-Apply` writes them over XBDM instead,
which is useful to test without the plugin. The plugin also prints `[Vader360] ...` lines
to the debug output (visible in any XBDM debug-output viewer).

## Limitations

- Kernel 2.0.17559.0 only. On any other kernel the plugin detects the difference and does nothing.
- Tested with the Flydigi Vader 3 receiver. Other receivers with the same 64/32-byte layout
  may work, but they are untested.
- Wired (USB-C cable) mode is untested.
- The plugin does not re-enumerate devices. Connect or re-plug the receiver after the plugin has loaded.

## FAQ

**Is this permanent?** No. Bad Update is not persistent, and neither is this. A power cycle
restores the stock kernel.

**Do I still need a patched XeUnshackle?** No. Use the official XeUnshackle or XeUnshackle
Max `default.xex` and add this plugin.

**Can it brick the console?** It only writes two instructions in RAM after verifying them.
As with any homebrew, use it at your own risk.

## Building

See [docs/BUILDING.md](docs/BUILDING.md). In short, on a Linux machine with OpenXeChain and
`synthxex-patched`:

```bash
OXC=/opt/openxechain bash build.sh   # -> out/vader360.xex
```

## How it works

See [docs/INTERNALS.md](docs/INTERNALS.md) for the two kernel checks, the exact patches
and their signatures.

## Credits

- [Byrom90](https://github.com/Byrom90/XeUnshackle) for XeUnshackle and the Usbdsec patches,
  and [klofi](https://github.com/klofi/XeUnshackle-Max) for XeUnshackle Max.
- The Bad Update / ABadAvatar authors.
- [OpenXeChain](https://github.com/OpenXeChain) (LLVM fork, xecorelib, SynthXEX).
- [Jacckii](https://github.com/Jacckii/Xbox360-Series-Controllers-Bridge) for the SynthXEX
  system-DLL patch and the OpenXeChain notes. The CI downloads and runs the patch; it is not
  included here.

- Developed with the help of [Claude](https://claude.ai) (Anthropic): reverse engineering of the
  kernel checks, the plugin code, the CI and this documentation.

Not affiliated with Microsoft or Flydigi. "Xbox 360" and "Vader 3" are trademarks of their owners.

## License

[MIT](LICENSE).
