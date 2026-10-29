#define _GNU_SOURCE
#include "native/dev/dev.h"
#include <pthread.h>
#include <stdint.h>
#include <time.h>

static uint64_t now_ns(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

static void *vsync_thread(void *unused)
{
    (void)unused;
    const uint64_t period = 1000000000ull / 60u;
    uint64_t next = now_ns();
    for (;;) {
        next += period;
        struct timespec ts = {
            (time_t)(next / 1000000000ull),
            (long)(next % 1000000000ull)
        };
        clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &ts, NULL);
        uint64_t now = now_ns();
        nc_dev_nv2a_display_vsync(now);
        if (now > next + period * 3u) {
            next = now;
        }
    }
    return NULL;
}

void nc_vsync_start(void)
{
    pthread_t thread;
    if (pthread_create(&thread, NULL, vsync_thread, NULL) == 0) {
        pthread_detach(thread);
    }
}
