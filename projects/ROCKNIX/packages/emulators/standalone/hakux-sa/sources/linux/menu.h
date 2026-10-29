#ifndef HAKUX_ROCKNIX_MENU_H
#define HAKUX_ROCKNIX_MENU_H

#include <stdbool.h>
#include <stdint.h>

#define HAKUX_MENU_WIDTH 960
#define HAKUX_MENU_HEIGHT 540

typedef enum HakuxMenuAction {
    HAKUX_MENU_UP,
    HAKUX_MENU_DOWN,
    HAKUX_MENU_LEFT,
    HAKUX_MENU_RIGHT,
    HAKUX_MENU_SELECT,
    HAKUX_MENU_BACK
} HakuxMenuAction;

typedef enum HakuxMenuResult {
    HAKUX_MENU_NO_ACTION,
    HAKUX_MENU_RESUME,
    HAKUX_MENU_EXIT
} HakuxMenuResult;

void hakux_menu_configure(int aspect, bool fxaa, int upscale);
void hakux_menu_toggle(void);
bool hakux_menu_visible(void);
uint32_t hakux_menu_revision(void);
HakuxMenuResult hakux_menu_press(HakuxMenuAction action);
bool hakux_menu_render(void *rgba);

#endif
