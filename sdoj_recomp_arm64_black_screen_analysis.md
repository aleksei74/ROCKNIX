# SDOJ-Recomp (DoDonPachi Saidaioujou) ARM64 Black Screen Issue - Technical Summary & Analysis Report

## 1. System & Environment Context
- **Target Device / SoC**: Snapdragon 8 Gen 2 (SM8550) / Qualcomm Adreno 740 GPU
- **Operating System**: ROCKNIX (Linux ARM64, kernel 6.x)
- **Display Server & Window Manager**: Wayland with Sway compositor (Portrait DSI panel rotated 270 degrees to 1920x1080)
- **Target Application**: `sdoj-recomp` (DoDonPachi Saidaioujou Recompiled, based on Xenia / ReXGlue runtime)
- **Vulkan Driver**: Turnip (freedreno) Vulkan driver (`libvulkan_freedreno.so`, Vulkan API 1.4.354)

---

## 2. Symptom Summary
- **Audio**: Plays perfectly with full sound effects and BGM.
- **Game Logic**: Executes normally in background (inputs registered, game state progresses).
- **Video Output**: **Black screen (No display on physical panel)**.
- **Log Behavior**: Log continuously prints frame presentations:
  ```log
  [info] [gpu] XELOG_GPU PRESENT: swap_texture_view=0xffff2cafe130 packet_size=1280x720 src_size=1280x720 guest_output_size=1280x720 format=6
  ```
  despite `XELOG_GPU PRESENT` ticking at 60 FPS, the screen remains completely black.

---

## 3. Work Done & Technical Investigations

### A. GTK3 to SDL3 Migration (birabittoh `rexglue-sdk-0.8.1.112`)
- **Reasoning**: Older ReXGlue used GTK3 (`GTKWindowedAppContext`), which has known Wayland/X11 double-buffering surface clearing issues on rotated handheld displays under XWayland. Upstream author `birabittoh` created `rexglue-sdk-0.8.1.112` replacing GTK3 with **SDL3** (`SDLWindowedAppContext`).
- **SDK Modifications & API Fixes**:
  - Replaced `windowed_app_main_posix.cpp` entry point with SDL3 windowing engine.
  - Resolved C++23 header/source signature mismatches for ARM64 build:
    - `HostPathDevice` / `HostPathEntry` (`allow_share_delete` & `RenameEntryInternal` return type `X_STATUS`).
    - `ImGuiDrawer` constructor (`StyleSetupCallback style_setup`).
    - `SettingsDialog` constructor (`InputSystem* input_system`).
    - `MnkInputDriver` (`OnActiveStateChanged` deprecation).
    - `PacketDisassembler` (`DisasmPacketType3` `guest_memory` parameter).
    - `Runtime` & `KernelState` (`metadata_root` parameter & `DynamicLibrary::GetSymbol<T>` template fix).

### B. Vulkan Instance & Surface Creation Observations
- **Vulkan Instance Extensions Enabled**:
  ```log
  [info] [core] Vulkan instance API version 1.4.347. Enabled layers and extensions:
  * VK_KHR_surface
  * VK_KHR_xcb_surface
  ```
- **Issue Discovered**:
  - Even though Sway/Wayland is active, ReXGlue's Vulkan presenter defaults to `VK_KHR_xcb_surface` (`XcbWindowSurface`) via XCB/XWayland rather than native Wayland surfaces (`VK_KHR_wayland_surface` / `SDL_Vulkan_CreateSurface`).
  - Added `VK_KHR_wayland_surface` to requested Vulkan instance extensions in `vulkan_instance.cpp`.

### C. Sway Compositor & Window Management Behavior
- **Sway Window Tree Inspection (`swaymsg -t get_tree`)**:
  - EmulationStation runs on Workspace 1 in fullscreen (`fullscreen_mode: 1`).
  - `start_sdoj_recomp.sh` contains:
    ```bash
    swaymsg '[class="Sdoj-recomp"] focus'
    swaymsg '[class="Sdoj-recomp"] fullscreen enable'
    ```
  - However, native Wayland or SDL3 applications use `app_id` (e.g. `saidaioujou_recomp_tu1`) instead of X11 `class`. Sway does not match `[class="Sdoj-recomp"]`, so EmulationStation remains focused on top of the viewport.

---

## 4. Key Questions for Further Diagnosis

1. **Vulkan Surface Creation Mechanism**:
   - In ReXGlue `vulkan_presenter.cpp`, `vkCreateXcbSurfaceKHR` is explicitly called when `Surface::kTypeIndex_XcbWindow` is used on GNU/Linux. Does SDL3 require replacing XCB surface creation with `SDL_Vulkan_CreateSurface` to properly hook Wayland/DRM surfaces on Linux handhelds?

2. **Handheld Display Rotation (Portrait DSI 1080x1920 -> 1920x1080)**:
   - NocturneRecomp had the exact same sound-only/black-screen issue on ARM64 handhelds initially. What specific presentation mode or Vulkan swapchain transform (`VK_SURFACE_TRANSFORM_ROTATE_270_BIT_KHR` / `VK_PRESENT_MODE_IMMEDIATE_KHR` vs `VK_PRESENT_MODE_FIFO_KHR`) was required to resolve it?

3. **Wayland Window Focus & Compositor Z-Order**:
   - Is EmulationStation holding exclusive DRM display lock or Wayland top-level focus, requiring explicit `killall -STOP emulationstation` or Sway workspace switching prior to launching the port?

---
*Generated for SDOJ-Recomp ARM64 Porting Analysis*
