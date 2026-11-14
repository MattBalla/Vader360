# SPDX-License-Identifier: MIT
#
# DllMain entry thunk.
#
# OpenXeChain's clang follows the 32-bit SVR4 ABI: it saves the non-volatile
# registers r14-r31 with 32-bit stw/lwz. The Xbox 360 kernel is 64-bit code and
# expects all 64 bits of r14-r31 to survive a call, so every function the kernel
# calls directly goes through this thunk, which saves and restores them as
# 64-bit values around the C code.

        .text
        .globl  DllMain
        .type   DllMain, @function
DllMain:
        stwu    1, -176(1)          # 16-byte header + 18 * 8 bytes, 16-aligned
        mflr    0
        stw     0, 180(1)           # LR save word in the caller's frame
        std     14, 16(1)
        std     15, 24(1)
        std     16, 32(1)
        std     17, 40(1)
        std     18, 48(1)
        std     19, 56(1)
        std     20, 64(1)
        std     21, 72(1)
        std     22, 80(1)
        std     23, 88(1)
        std     24, 96(1)
        std     25, 104(1)
        std     26, 112(1)
        std     27, 120(1)
        std     28, 128(1)
        std     29, 136(1)
        std     30, 144(1)
        std     31, 152(1)

        bl      vader360_dllmain    # r3-r5 (handle, reason, reserved) pass through

        ld      14, 16(1)
        ld      15, 24(1)
        ld      16, 32(1)
        ld      17, 40(1)
        ld      18, 48(1)
        ld      19, 56(1)
        ld      20, 64(1)
        ld      21, 72(1)
        ld      22, 80(1)
        ld      23, 88(1)
        ld      24, 96(1)
        ld      25, 104(1)
        ld      26, 112(1)
        ld      27, 120(1)
        ld      28, 128(1)
        ld      29, 136(1)
        ld      30, 144(1)
        ld      31, 152(1)
        lwz     0, 180(1)
        mtlr    0
        addi    1, 1, 176
        blr
        .size   DllMain, .-DllMain
