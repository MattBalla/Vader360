# Internals

Everything here is for kernel **2.0.17559.0**. Addresses are kernel virtual addresses.

## Why the receiver is rejected

In XInput mode the Flydigi Vader 3 receiver reports VID/PID `045E:028E` (a wired Xbox 360
controller), but its interface differs from Microsoft's:

| | Microsoft wired controller | Vader 3 receiver |
|---|---|---|
| Interrupt endpoint max packet size | 32 bytes | **64 bytes** |
| Input report length | 20 bytes | **32 bytes** |

The kernel's wired-gamepad class driver checks both values. Before those checks,
`UsbdIsDeviceAuthenticated` and an interface-descriptor check in `WgcAddDevice` also
reject third-party devices; XeUnshackle / XeUnshackle Max already patch those two
(the "Usbdsec" patches).

## The patches

### 1. `WgcAddDevice`: endpoint size (0x800F98F8)

```
800F98F4  2B030001  cmplwi  r3, 1
800F98F8  39400020  li      r10, 0x20      <- patched to 39400040 (li r10, 0x40)
800F98FC  419A0008  beq     +8
800F9900  39400040  li      r10, 0x40
```

For full-speed devices the driver used a 32-byte limit for the interrupt endpoint;
the patch makes both paths allow 64 bytes.

### 2. Input report length (0x800F9490)

```
800F9488  2B0B0014  cmplwi  r11, 0x14
800F948C  995F0098  stb     r10, 0x98(r31)
800F9490  409A0164  bne     +0x164         <- patched to 41980164 (blt +0x164)
800F9494  897D0000  lbz     r11, 0(r29)
```

Reports whose length is not exactly 20 bytes were dropped. With `blt` the parser accepts
reports of **20 bytes or more** and reads the standard 20-byte layout from the start of the
32-byte report.

## Safety checks

For each site the plugin compares the word before and after the patch site with the values
above, and requires the site itself to hold either the stock or the patched instruction. Both
sites are verified before anything is written. Then each write is followed by
`dcbst / sync / icbi / sync / isync` and read back.

The result is kept in a small block in the plugin's `.data`, so it can be inspected over XBDM:

| Offset | Meaning |
|---|---|
| +0 | magic `VDR3` (0x56445233) |
| +4 | status: 0 not run, 1 applied, 2 already patched, 3 signature mismatch, 4 write failed |
| +8 | number of sites written |
| +12 | address of the site that failed, if any |

## Calling convention

OpenXeChain's clang uses the 32-bit SVR4 ABI and saves r14-r31 with 32-bit stores, while the
kernel expects the full 64-bit registers preserved. `src/entry.S` provides `DllMain` as a
thunk that saves and restores r14-r31 with `std`/`ld` and calls the C code.

## Load address

System DLLs only load at their own base. Vader360 links at **0x91660000**, inside the
0x91429000-0x91680000 gap between `hud.xex` and `ximecore.xex`, which the system modules and
known plugins leave free. The image is much smaller than the 128 KB available there.
