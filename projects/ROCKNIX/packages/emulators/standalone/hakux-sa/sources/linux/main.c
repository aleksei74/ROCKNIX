#define _GNU_SOURCE
#include "native/app/app.h"
#include "native/core/core.h"
#include "native/core/options.h"
#include "native/core/irq.h"
#include "native/dev/usb.h"
#include "native/kernel/kernel.h"
#include "native/hle/hle_native.h"
#include <SDL3/SDL.h>
#include <SDL3/SDL_vulkan.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <unistd.h>

static NcCore g_core;
static int g_disc_fd = -1;
static SDL_AtomicInt g_core_state;
/* SIGSEGV/SIGBUS: the core's own faults first (MMIO, dirty tracking, the
 * call-ret stack, a title's pager), anything else to whoever handled them
 * before (ART's handlers, then the crash reporter).
 *
 * The handler goes to the kernel directly (rt_sigaction), in front of ART's
 * signal chain, which would take every guest device-register access first
 * and add two sigprocmask calls to each (a tenth of the guest thread with
 * DirectSound at work). Faults that aren't the core's go to the handler the
 * kernel had, ART's chain, as the kernel would have called it. */
struct k_sigaction {
    void (*handler)(int, siginfo_t *, void *);
    unsigned long flags;
    void (*restorer)(void);
    uint64_t mask;
};
static struct k_sigaction g_old_segv, g_old_bus;

static void on_fault(int sig, siginfo_t *info, void *ctx)
{
    if (nc_core_fault(&g_core, sig, info, ctx)) {
        return;
    }
    struct k_sigaction *old = sig == SIGBUS ? &g_old_bus : &g_old_segv;
    void (*h)(int, siginfo_t *, void *) = old->handler;
    if (h == (void *)SIG_DFL || h == (void *)SIG_IGN) {
        struct k_sigaction dfl = {0};
        syscall(__NR_rt_sigaction, sig, &dfl, NULL, sizeof(uint64_t)); /* the fault repeats: default action */
        return;
    }
    if (old->flags & SA_SIGINFO) {
        h(sig, info, ctx);
    } else {
        ((void (*)(int))(void *)h)(sig);
    }
}

static void install_fault_handler(void)
{
    struct k_sigaction sa = {0};
    sa.handler = on_fault;
    sa.flags = SA_SIGINFO | SA_ONSTACK;
    syscall(__NR_rt_sigaction, SIGSEGV, &sa, &g_old_segv, sizeof(uint64_t));
    syscall(__NR_rt_sigaction, SIGBUS, &sa, &g_old_bus, sizeof(uint64_t));
}

static void *core_thread(void *arg)
{
    if (!nc_core_boot(&g_core, g_disc_fd)) {
        nc_log("hakuX-app", "core: boot failed");
        if (!nc_hle_fatal()) {
            nc_hle_set_fatal(NC_FATAL_BOOT, "The game stopped while starting.");
        }
        SDL_SetAtomicInt(&g_core_state, -1);
        return NULL;
    }
    SDL_SetAtomicInt(&g_core_state, 1);
    nc_dev_ohci_set_pads(1);
    nc_core_run(&g_core);
    nc_log("hakuX-app", "core: stopped");
    SDL_SetAtomicInt(&g_core_state, -1);
    return NULL;
}
static int16_t clamp16(int v)
{
    return (int16_t)(v > 32767 ? 32767 : v < -32767 ? -32767 : v);
}

/* The Duke from a modern gamepad: face buttons and black/white (the shoulder
 * buttons) are analog on the Xbox, fully pressed here; stick Y points up. */
static void read_gamepad(SDL_Gamepad *p, NcPadState *s)
{
    static const SDL_GamepadButton k_analog[6] = {
        SDL_GAMEPAD_BUTTON_SOUTH, SDL_GAMEPAD_BUTTON_EAST, SDL_GAMEPAD_BUTTON_WEST,
        SDL_GAMEPAD_BUTTON_NORTH, SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER, SDL_GAMEPAD_BUTTON_LEFT_SHOULDER,
    };
    static const struct {
        SDL_GamepadButton b;
        uint16_t bit;
    } k_digital[] = {
        {SDL_GAMEPAD_BUTTON_DPAD_UP, NC_PAD_DPAD_UP},     {SDL_GAMEPAD_BUTTON_DPAD_DOWN, NC_PAD_DPAD_DOWN},
        {SDL_GAMEPAD_BUTTON_DPAD_LEFT, NC_PAD_DPAD_LEFT}, {SDL_GAMEPAD_BUTTON_DPAD_RIGHT, NC_PAD_DPAD_RIGHT},
        {SDL_GAMEPAD_BUTTON_START, NC_PAD_START},         {SDL_GAMEPAD_BUTTON_BACK, NC_PAD_BACK},
        {SDL_GAMEPAD_BUTTON_LEFT_STICK, NC_PAD_LTHUMB},   {SDL_GAMEPAD_BUTTON_RIGHT_STICK, NC_PAD_RTHUMB},
    };
    for (unsigned i = 0; i < 6; i++) {
        if (SDL_GetGamepadButton(p, k_analog[i])) {
            s->analog[i] = 0xFF;
        }
    }
    for (unsigned i = 0; i < sizeof(k_digital) / sizeof(k_digital[0]); i++) {
        if (SDL_GetGamepadButton(p, k_digital[i].b)) {
            s->buttons |= k_digital[i].bit;
        }
    }
    const int lt = SDL_GetGamepadAxis(p, SDL_GAMEPAD_AXIS_LEFT_TRIGGER) >> 7;
    const int rt = SDL_GetGamepadAxis(p, SDL_GAMEPAD_AXIS_RIGHT_TRIGGER) >> 7;
    if (lt > s->analog[6]) {
        s->analog[6] = (uint8_t)lt;
    }
    if (rt > s->analog[7]) {
        s->analog[7] = (uint8_t)rt;
    }
    const int lx = SDL_GetGamepadAxis(p, SDL_GAMEPAD_AXIS_LEFTX), ly = -SDL_GetGamepadAxis(p, SDL_GAMEPAD_AXIS_LEFTY);
    const int rx = SDL_GetGamepadAxis(p, SDL_GAMEPAD_AXIS_RIGHTX), ry = -SDL_GetGamepadAxis(p, SDL_GAMEPAD_AXIS_RIGHTY);
    /* The stick pushed furthest wins between the pad and the overlay. */
    if (abs(lx) + abs(ly) > abs(s->lx) + abs(s->ly)) {
        s->lx = clamp16(lx);
        s->ly = clamp16(ly);
    }
    if (abs(rx) + abs(ry) > abs(s->rx) + abs(s->ry)) {
        s->rx = clamp16(rx);
        s->ry = clamp16(ry);
    }
}
static void make_hdd(const char *root)
{
    char p[512];
    mkdir(root, 0775);
    for (int i = 0; i <= 5; i++) {
        snprintf(p, sizeof(p), "%s/Partition%d", root, i);
        mkdir(p, 0775);
    }
}


int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "usage: hakux-sa <xiso> <hdd-dir> [options...]\n");
        return 2;
    }
    g_disc_fd = open(argv[1], O_RDONLY | O_CLOEXEC);
    if (g_disc_fd < 0) {
        perror(argv[1]);
        return 2;
    }
    make_hdd(argv[2]);
    nc_io_set_hdd_root(argv[2]);
    setenv("HAKUX_HLE_MODE", "replace", 0);
    NcOptions opt;
    nc_options_init(&opt);
    for (int i = 3; i < argc; i++) {
        if (nc_option(&opt, argv[i])) {
            continue;
        }
        if (!strncmp(argv[i], "aspect=", 7)) {
            const char *v = argv[i] + 7;
            nc_present_set_aspect(!strcmp(v, "4:3") ? NC_ASPECT_4_3 :
                                  !strcmp(v, "16:9") ? NC_ASPECT_16_9 :
                                  !strcmp(v, "stretch") ? NC_ASPECT_STRETCH : NC_ASPECT_AUTO);
        } else if (!strncmp(argv[i], "fxaa=", 5)) {
            nc_present_set_fxaa(atoi(argv[i] + 5) != 0);
        } else if (!strncmp(argv[i], "upscale=", 8)) {
            nc_present_set_upscale(!strcmp(argv[i] + 8, "sgsr") ? NC_UPSCALE_SGSR : NC_UPSCALE_BILINEAR);
        } else {
            fprintf(stderr, "hakuX: unrecognized argument: %s\n", argv[i]);
        }
    }
    nc_options_apply(&opt);
    nc_present_set_widescreen(opt.video >= 0 && (opt.video & NC_VIDEO_WIDESCREEN));

    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD | SDL_INIT_AUDIO)) {
        fprintf(stderr, "hakuX: SDL init: %s\n", SDL_GetError());
        return 1;
    }
    if (!SDL_Vulkan_LoadLibrary(NULL)) {
        fprintf(stderr, "hakuX: SDL Vulkan load: %s\n", SDL_GetError());
        return 1;
    }
    SDL_Window *win = SDL_CreateWindow("hakuX (ROCKNIX)", 1280, 720,
                                       SDL_WINDOW_VULKAN | SDL_WINDOW_FULLSCREEN);
    if (!win || !nc_present_init()) {
        fprintf(stderr, "hakuX: window: %s\n", SDL_GetError());
        return 1;
    }
    nc_vsync_start();
    install_fault_handler();
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setstacksize(&attr, 16u << 20);
    pthread_t worker;
    if (pthread_create(&worker, &attr, core_thread, NULL) != 0) {
        fprintf(stderr, "hakuX: cannot start emulation thread\n");
        return 1;
    }
    pthread_attr_destroy(&attr);

    SDL_Gamepad *pad = NULL;
    uint16_t last_l = 0, last_r = 0;
    bool quit = false;
    while (!quit) {
        SDL_Event ev;
        while (SDL_PollEvent(&ev)) {
            if (ev.type == SDL_EVENT_QUIT ||
                (ev.type == SDL_EVENT_KEY_DOWN && ev.key.key == SDLK_ESCAPE)) {
                quit = true;
            } else if (ev.type == SDL_EVENT_GAMEPAD_ADDED && !pad) {
                pad = SDL_OpenGamepad(ev.gdevice.which);
                if (pad) {
                    nc_log("hakuX-rocknix", "gamepad: %s", SDL_GetGamepadName(pad));
                }
            } else if (ev.type == SDL_EVENT_GAMEPAD_REMOVED && pad &&
                       SDL_GetGamepadID(pad) == ev.gdevice.which) {
                SDL_CloseGamepad(pad);
                pad = NULL;
            }
        }
        if (SDL_GetAtomicInt(&g_core_state) == 1) {
            NcPadState state = {0};
            if (pad) {
                read_gamepad(pad, &state);
            }
            nc_pad_set(0, &state);
            uint16_t l = 0, r = 0;
            nc_pad_rumble(0, &l, &r);
            if (pad && (l != last_l || r != last_r)) {
                SDL_RumbleGamepad(pad, l, r, l || r ? 1000 : 0);
                last_l = l;
                last_r = r;
            }
        }
        if (!nc_present_frame(win)) {
            SDL_Delay(8);
        }
        if (SDL_GetAtomicInt(&g_core_state) < 0) {
            nc_log("hakuX-rocknix", "emulation stopped: %s", nc_hle_fatal() ? nc_hle_fatal() : "normal");
            break;
        }
    }
    _exit(nc_hle_fatal() ? 1 : 0);
}
