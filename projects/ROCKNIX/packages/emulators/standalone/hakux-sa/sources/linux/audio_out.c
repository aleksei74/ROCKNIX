#include "native/dev/apu/apu_int.h"
#include <SDL3/SDL.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define OUT_RATE 48000
#define FRAME_BYTES 4

static struct {
    uint8_t *buf;
    uint32_t cap;
    uint64_t head, tail;
    pthread_cond_t *wake;
    SDL_AudioStream *stream;
    uint32_t callbacks, short_callbacks;
    bool paused;
} g_out;

int apu_out_queued(void)
{
    return (int)(__atomic_load_n(&g_out.head, __ATOMIC_ACQUIRE) -
                 __atomic_load_n(&g_out.tail, __ATOMIC_ACQUIRE));
}

void apu_out_push(const void *frame, int bytes)
{
    if (!g_out.buf || bytes <= 0) {
        return;
    }
    uint64_t head = g_out.head;
    uint64_t tail = __atomic_load_n(&g_out.tail, __ATOMIC_ACQUIRE);
    if (head + (uint64_t)bytes - tail > g_out.cap) {
        fprintf(stderr, "hakuX audio: output ring full\n");
        return;
    }
    uint32_t at = (uint32_t)(head % g_out.cap);
    uint32_t first = (uint32_t)bytes;
    if (first > g_out.cap - at) {
        first = g_out.cap - at;
    }
    memcpy(g_out.buf + at, frame, first);
    memcpy(g_out.buf, (const uint8_t *)frame + first, (size_t)bytes - first);
    __atomic_store_n(&g_out.head, head + (uint64_t)bytes, __ATOMIC_RELEASE);
}

static int pop(void *out, int bytes)
{
    uint64_t tail = g_out.tail;
    uint64_t head = __atomic_load_n(&g_out.head, __ATOMIC_ACQUIRE);
    int available = (int)(head - tail);
    int count = bytes < available ? bytes : available;
    if (count <= 0) {
        return 0;
    }
    uint32_t at = (uint32_t)(tail % g_out.cap);
    uint32_t first = (uint32_t)count;
    if (first > g_out.cap - at) {
        first = g_out.cap - at;
    }
    memcpy(out, g_out.buf + at, first);
    memcpy((uint8_t *)out + first, g_out.buf, (size_t)count - first);
    __atomic_store_n(&g_out.tail, tail + (uint64_t)count, __ATOMIC_RELEASE);
    if (g_out.wake) {
        pthread_cond_broadcast(g_out.wake);
    }
    return count;
}

void apu_out_stats(uint32_t *callbacks, uint32_t *short_callbacks)
{
    *callbacks = __atomic_exchange_n(&g_out.callbacks, 0, __ATOMIC_ACQ_REL);
    *short_callbacks = __atomic_exchange_n(&g_out.short_callbacks, 0, __ATOMIC_ACQ_REL);
}

static void audio_callback(void *userdata, SDL_AudioStream *stream,
                           int additional_amount, int total_amount)
{
    (void)userdata;
    (void)total_amount;
    uint8_t data[4096];
    while (additional_amount > 0) {
        int bytes = additional_amount < (int)sizeof(data) ? additional_amount : (int)sizeof(data);
        int got = g_out.paused ? 0 : pop(data, bytes);
        if (got < bytes) {
            memset(data + got, 0, (size_t)(bytes - got));
            __atomic_add_fetch(&g_out.short_callbacks, 1, __ATOMIC_RELAXED);
        }
        __atomic_add_fetch(&g_out.callbacks, 1, __ATOMIC_RELAXED);
        SDL_PutAudioStreamData(stream, data, bytes);
        additional_amount -= bytes;
    }
}

static void *silent_thread(void *unused)
{
    (void)unused;
    uint8_t data[1024];
    struct timespec ts = {0, 5333333};
    for (;;) {
        if (!g_out.paused) {
            pop(data, sizeof(data));
        }
        nanosleep(&ts, NULL);
    }
    return NULL;
}

int apu_out_open(int capacity_bytes, int samples, pthread_cond_t *wake)
{
    g_out.buf = calloc(1, (size_t)capacity_bytes);
    if (!g_out.buf || capacity_bytes <= 0) {
        return 0;
    }
    g_out.cap = (uint32_t)capacity_bytes;
    g_out.wake = wake;
    SDL_AudioSpec spec = {
        .format = SDL_AUDIO_S16,
        .channels = 2,
        .freq = OUT_RATE
    };
    g_out.stream = SDL_OpenAudioDeviceStream(
        SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec, audio_callback, NULL);
    if (!g_out.stream || !SDL_ResumeAudioStreamDevice(g_out.stream)) {
        fprintf(stderr, "hakuX audio: no playback device, draining without sound: %s\n",
                SDL_GetError());
        if (g_out.stream) {
            SDL_DestroyAudioStream(g_out.stream);
            g_out.stream = NULL;
        }
        pthread_t th;
        if (pthread_create(&th, NULL, silent_thread, NULL) == 0) {
            pthread_detach(th);
        }
    }
    return samples * FRAME_BYTES;
}

void nc_audio_set_paused(bool on)
{
    g_out.paused = on;
    if (g_out.stream) {
        if (on) {
            SDL_PauseAudioStreamDevice(g_out.stream);
        } else {
            SDL_ResumeAudioStreamDevice(g_out.stream);
        }
    }
}
