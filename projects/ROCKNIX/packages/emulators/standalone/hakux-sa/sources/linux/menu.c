#include "linux/menu.h"
#include "native/app/app.h"

#include <SDL3/SDL.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

static struct {
    bool visible;
    bool fxaa;
    int cursor;
    int aspect;
    int upscale;
    uint32_t revision;
    void *pixels;
    SDL_Surface *surface;
    SDL_Renderer *renderer;
} g_menu;

static void changed(void)
{
    ++g_menu.revision;
}

void hakux_menu_configure(int aspect, bool fxaa, int upscale)
{
    g_menu.aspect = aspect >= NC_ASPECT_AUTO && aspect <= NC_ASPECT_STRETCH
                    ? aspect : NC_ASPECT_AUTO;
    g_menu.fxaa = fxaa;
    g_menu.upscale = upscale == NC_UPSCALE_SGSR ? NC_UPSCALE_SGSR : NC_UPSCALE_BILINEAR;
    changed();
}

void hakux_menu_toggle(void)
{
    g_menu.visible = !g_menu.visible;
    g_menu.cursor = 0;
    changed();
}

bool hakux_menu_visible(void)
{
    return g_menu.visible;
}

uint32_t hakux_menu_revision(void)
{
    return g_menu.revision;
}

HakuxMenuResult hakux_menu_press(HakuxMenuAction action)
{
    if (!g_menu.visible) {
        return HAKUX_MENU_NO_ACTION;
    }
    if (action == HAKUX_MENU_BACK) {
        hakux_menu_toggle();
        return HAKUX_MENU_RESUME;
    }
    if (action == HAKUX_MENU_UP || action == HAKUX_MENU_DOWN) {
        g_menu.cursor = (g_menu.cursor + (action == HAKUX_MENU_UP ? 4 : 1)) % 5;
        changed();
        return HAKUX_MENU_NO_ACTION;
    }
    if (g_menu.cursor == 3 && action == HAKUX_MENU_SELECT) {
        hakux_menu_toggle();
        return HAKUX_MENU_RESUME;
    }
    if (g_menu.cursor == 4 && action == HAKUX_MENU_SELECT) {
        return HAKUX_MENU_EXIT;
    }
    if (action != HAKUX_MENU_SELECT &&
        action != HAKUX_MENU_LEFT && action != HAKUX_MENU_RIGHT) {
        return HAKUX_MENU_NO_ACTION;
    }
    const int dir = action == HAKUX_MENU_LEFT ? -1 : 1;
    switch (g_menu.cursor) {
    case 0:
        g_menu.aspect = (g_menu.aspect + dir + 4) % 4;
        nc_present_set_aspect(g_menu.aspect);
        break;
    case 1:
        g_menu.fxaa = !g_menu.fxaa;
        nc_present_set_fxaa(g_menu.fxaa);
        break;
    case 2:
        g_menu.upscale = g_menu.upscale == NC_UPSCALE_SGSR ?
                         NC_UPSCALE_BILINEAR : NC_UPSCALE_SGSR;
        nc_present_set_upscale(g_menu.upscale);
        break;
    default:
        return HAKUX_MENU_NO_ACTION;
    }
    changed();
    return HAKUX_MENU_NO_ACTION;
}

static void rect(float x, float y, float w, float h,
                 uint8_t r, uint8_t g, uint8_t b, uint8_t a)
{
    const SDL_FRect box = {x, y, w, h};
    SDL_SetRenderDrawColor(g_menu.renderer, r, g, b, a);
    SDL_RenderFillRect(g_menu.renderer, &box);
}

static void label(float x, float y, const char *str,
                  uint8_t r, uint8_t g, uint8_t b)
{
    SDL_SetRenderDrawColor(g_menu.renderer, r, g, b, 255);
    SDL_SetRenderScale(g_menu.renderer, 2.0f, 2.0f);
    SDL_RenderDebugText(g_menu.renderer, x / 2.0f, y / 2.0f, str);
    SDL_SetRenderScale(g_menu.renderer, 1.0f, 1.0f);
}

bool hakux_menu_render(void *rgba)
{
    if (!g_menu.visible || !rgba) {
        return false;
    }
    if (g_menu.pixels != rgba || !g_menu.renderer) {
        if (g_menu.renderer) SDL_DestroyRenderer(g_menu.renderer);
        if (g_menu.surface) SDL_DestroySurface(g_menu.surface);
        g_menu.pixels = rgba;
        g_menu.surface = SDL_CreateSurfaceFrom(HAKUX_MENU_WIDTH, HAKUX_MENU_HEIGHT,
                                                SDL_PIXELFORMAT_RGBA32, rgba,
                                                HAKUX_MENU_WIDTH * 4);
        if (!g_menu.surface) return false;
        g_menu.renderer = SDL_CreateSoftwareRenderer(g_menu.surface);
        if (!g_menu.renderer) return false;
    }
    SDL_SetRenderDrawBlendMode(g_menu.renderer, SDL_BLENDMODE_NONE);
    SDL_SetRenderDrawColor(g_menu.renderer, 0, 0, 0, 0);
    SDL_RenderClear(g_menu.renderer);
    SDL_SetRenderDrawBlendMode(g_menu.renderer, SDL_BLENDMODE_BLEND);

    rect(120, 48, 720, 448, 12, 18, 29, 239);
    rect(120, 48, 720, 6, 54, 168, 241, 255);
    label(176, 78, "HAKUX  -  QUICK SETTINGS", 255, 255, 255);
    label(176, 127, "L3 + R3  /  F1  :  TOGGLE MENU", 165, 194, 216);

    static const int y[5] = {183, 230, 277, 365, 411};
    for (int i = 0; i < 5; i++) {
        if (i == g_menu.cursor) {
            rect(154, (float)y[i] - 10, 654, 38, 39, 95, 128, 245);
        }
    }

    static const char *const aspect[] = {"AUTO", "4:3", "16:9", "STRETCH"};
    label(176, y[0], "ASPECT RATIO", 255, 255, 255);
    label(655, y[0], aspect[g_menu.aspect], 255, 255, 255);
    label(176, y[1], "FXAA", 255, 255, 255);
    label(655, y[1], g_menu.fxaa ? "ON" : "OFF", 255, 255, 255);
    label(176, y[2], "UPSCALING", 255, 255, 255);
    label(655, y[2], g_menu.upscale == NC_UPSCALE_SGSR ? "SGSR" : "BILINEAR",
          255, 255, 255);

    label(176, 321, "SCALE / SHADERS: CHANGE IN ES (RESTART)", 165, 194, 216);
    label(176, y[3], "RESUME GAME", 255, 255, 255);
    label(176, y[4], "EXIT GAME", 255, 255, 255);
    label(176, 460, "D-PAD: MOVE / CHANGE   A: OK   B: BACK", 166, 194, 216);

    return SDL_RenderPresent(g_menu.renderer);
}
