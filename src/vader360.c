// SPDX-License-Identifier: MIT
//
// Vader360 - DashLaunch plugin that lets the Flydigi Vader 3 (and other XInput
// receivers with 64-byte endpoints / 32-byte reports) work on a retail Xbox 360
// running Bad Update + XeUnshackle (kernel 2.0.17559.0).
//
// The stock kernel rejects the receiver in two places of its wired-gamepad driver:
//   1. WgcAddDevice caps the interrupt endpoint's max packet size at 32 bytes for
//      full-speed devices; the receiver uses 64.
//   2. The input-report parser only accepts reports of exactly 20 bytes; the
//      receiver sends 32.
// Each fix is a single instruction. The plugin checks the surrounding code first
// and changes nothing unless every word matches kernel 17559, so on any other
// kernel (or an already-patched one) it is a no-op.
//
// XeUnshackle itself must still apply its Usbdsec patches (UsbdIsDeviceAuthenticated
// and the WgcAddDevice interface check), as XeUnshackle and XeUnshackle Max do.

#include <stdint.h>
#include <xecore/xboxkrnl.h>

#define VADER360_VERSION "1.0.0"

typedef struct {
    uint32_t addr;      // instruction to patch
    uint32_t before;    // word at addr - 4 (signature)
    uint32_t original;  // stock instruction
    uint32_t patched;   // replacement
    uint32_t after;     // word at addr + 4 (signature)
    const char *what;
} patch_site_t;

static const patch_site_t k_sites[] = {
    // cmplwi r3,1 / li r10,0x20 -> li r10,0x40 / beq +8
    { 0x800F98F8, 0x2B030001, 0x39400020, 0x39400040, 0x419A0008,
      "WgcAddDevice: full-speed max packet 32 -> 64" },
    // stb r10,0x98(r31) / bne +0x164 -> blt +0x164 / lbz r11,0(r29)
    // (report length: "== 20" becomes ">= 20")
    { 0x800F9490, 0x995F0098, 0x409A0164, 0x41980164, 0x897D0000,
      "input report length == 20 -> >= 20" },
};
#define SITE_COUNT (sizeof(k_sites) / sizeof(k_sites[0]))

// XeUnshackle's own Usbdsec patch (UsbdIsDeviceAuthenticated -> return 1).
// Only reported, not required, so the plugin also works with other payloads.
#define USBDSEC_ADDR 0x800D8748u
#define USBDSEC_WORD0 0x38600001u // li r3,1
#define USBDSEC_WORD1 0x4E800020u // blr

enum {
    VADER_STATUS_NOT_RUN  = 0,
    VADER_STATUS_APPLIED  = 1, // at least one site written
    VADER_STATUS_ALREADY  = 2, // both sites already patched
    VADER_STATUS_MISMATCH = 3, // signature mismatch: nothing written
    VADER_STATUS_VERIFY   = 4, // write did not stick
};

// Readable over xbdm (search memory for "VDR3"): magic, status, sites written,
// first mismatching address. Initialised and non-const so it lives in .data
// (SynthXEX also needs the last PE section to carry raw data).
__attribute__((used)) volatile uint32_t g_vader360_state[4] = { 0x56445233 /* VDR3 */, 0, 0, 0 };

static inline uint32_t rd(uint32_t addr) { return *(volatile uint32_t *)addr; }

static inline void wr_code(uint32_t addr, uint32_t value)
{
    *(volatile uint32_t *)addr = value;
    // write back the data cache line, then drop the stale instruction cache line
    __asm__ volatile("dcbst 0,%0\n\tsync\n\ticbi 0,%0\n\tsync\n\tisync" : : "r"(addr) : "memory");
}

static int site_matches(const patch_site_t *s, int *already)
{
    uint32_t cur = rd(s->addr);
    if (rd(s->addr - 4) != s->before || rd(s->addr + 4) != s->after)
        return 0;
    if (cur == s->patched) { *already = 1; return 1; }
    *already = 0;
    return cur == s->original;
}

static void vader360_attach(void)
{
    int already[SITE_COUNT];
    unsigned i, written = 0;

    DbgPrint("[Vader360] v" VADER360_VERSION " loaded\n");

    if (rd(USBDSEC_ADDR) != USBDSEC_WORD0 || rd(USBDSEC_ADDR + 4) != USBDSEC_WORD1)
        DbgPrint("[Vader360] warning: XeUnshackle Usbdsec patch not found; "
                 "third-party controllers may still be rejected\n");

    // verify every site before touching anything
    for (i = 0; i < SITE_COUNT; i++) {
        if (!site_matches(&k_sites[i], &already[i])) {
            g_vader360_state[1] = VADER_STATUS_MISMATCH;
            g_vader360_state[3] = k_sites[i].addr;
            DbgPrint("[Vader360] unexpected code at %08X (not kernel 17559?): nothing changed\n",
                     k_sites[i].addr);
            return;
        }
    }

    for (i = 0; i < SITE_COUNT; i++) {
        if (already[i])
            continue;
        wr_code(k_sites[i].addr, k_sites[i].patched);
        if (rd(k_sites[i].addr) != k_sites[i].patched) {
            g_vader360_state[1] = VADER_STATUS_VERIFY;
            g_vader360_state[3] = k_sites[i].addr;
            DbgPrint("[Vader360] write to %08X did not stick\n", k_sites[i].addr);
            return;
        }
        written++;
        DbgPrint("[Vader360] patched %08X: %s\n", k_sites[i].addr, k_sites[i].what);
    }

    g_vader360_state[2] = written;
    g_vader360_state[1] = written ? VADER_STATUS_APPLIED : VADER_STATUS_ALREADY;
    DbgPrint(written ? "[Vader360] done - re-plug the receiver if it was already connected\n"
                     : "[Vader360] kernel already patched - nothing to do\n");
}

// Called by the 64-bit-safe DllMain thunk in entry.S
int vader360_dllmain(uint32_t handle, uint32_t reason, uint32_t reserved)
{
    (void)handle;
    (void)reserved;
    if (reason == 1 /* DLL_PROCESS_ATTACH */)
        vader360_attach();
    return 1;
}
