#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2022-present JELOS (https://github.com/JustEnoughLinuxOS)

. /etc/profile

#Check if ARMSX2 exists in .config
if [ ! -d "/storage/.config/ARMSX2" ]; then
    mkdir -p "/storage/.config/ARMSX2"
        cp -r "/usr/config/ARMSX2" "/storage/.config/"
fi

#Check if ARMSX2 ini exists in .config
if [ ! -f "/storage/.config/ARMSX2/inis/PCSX2.ini" ]; then
        cp -r "/usr/config/ARMSX2/inis/PCSX2.ini" "/storage/.config/ARMSX2/inis/"
fi

#Check if secrets ini exists in .config
if [ ! -f "/storage/.config/ARMSX2/inis/secrets.ini" ]; then
        cp -r "/usr/config/ARMSX2/inis/secrets.ini" "/storage/.config/ARMSX2/inis/"
fi

#Make ARMSX2 bios folder
if [ ! -d "/storage/roms/bios/armsx2" ]; then
    mkdir -p "/storage/roms/bios/armsx2"
fi
sed -i '/^Bios =/c\Bios = /storage/roms/bios/armsx2' /storage/.config/ARMSX2/inis/PCSX2.ini

#Create PS2 savestates folder
if [ ! -d "/storage/roms/savestates/ps2" ]; then
    mkdir -p "/storage/roms/savestates/ps2"
fi

#Emulation Station Features
GAME=$(echo "${1}"| sed "s#^/.*/##")
PLATFORM=$(echo "${2}"| sed "s#^/.*/##")
ASPECT=$(get_setting aspect_ratio "${PLATFORM}" "${GAME}")
FILTER=$(get_setting bilinear_filtering "${PLATFORM}" "${GAME}")
FPS=$(get_setting show_fps "${PLATFORM}" "${GAME}")
RATE=$(get_setting ee_cycle_rate "${PLATFORM}" "${GAME}")
SKIP=$(get_setting ee_cycle_skip "${PLATFORM}" "${GAME}")
HWDOWNLOAD=$(get_setting hw_download_mode "${PLATFORM}" "${GAME}")
GRENDERER=$(get_setting graphics_backend "${PLATFORM}" "${GAME}")
IRES=$(get_setting internal_resolution "${PLATFORM}" "${GAME}")
VSYNC=$(get_setting vsync "${PLATFORM}" "${GAME}")
ENABLE_WIDESCREEN_PATCHES=$(get_setting enable_widescreen_patches "${PLATFORM}" "${GAME}")
LSFG_ENABLE=$(get_setting lsfg_enable "${PLATFORM}" "${GAME}")
LSFG_ENABLE=${LSFG_ENABLE:-0}
LSFG_MULTIPLIER=$(get_setting lsfg_multiplier "${PLATFORM}" "${GAME}")
LSFG_MULTIPLIER=${LSFG_MULTIPLIER:-2}
LSFG_FLOW_SCALE=$(get_setting lsfg_flow_scale "${PLATFORM}" "${GAME}")
LSFG_FLOW_SCALE=${LSFG_FLOW_SCALE:-0.30}
LSFG_PERFORMANCE_MODE=$(get_setting lsfg_performance_mode "${PLATFORM}" "${GAME}")
LSFG_PERFORMANCE_MODE=${LSFG_PERFORMANCE_MODE:-1}

#Set the cores to use
CORES=$(get_setting "cores" "${PLATFORM}" "${GAME}")
if [ "${CORES}" = "little" ]
then
  EMUPERF="${SLOW_CORES}"
elif [ "${CORES}" = "big" ]
then
  EMUPERF="${FAST_CORES}"
else
  #All..
  unset EMUPERF
fi

  #Aspect Ratio
	if [ "$ASPECT" = "0" ]
	then
  		sed -i '/^AspectRatio =/c\AspectRatio = 4:3' /storage/.config/ARMSX2/inis/PCSX2.ini
	fi
	if [ "$ASPECT" = "1" ]
	then
  		sed -i '/^AspectRatio =/c\AspectRatio = 16:9' /storage/.config/ARMSX2/inis/PCSX2.ini
	fi
	if [ "$ASPECT" = "2" ]
	then
  		sed -i '/^AspectRatio =/c\AspectRatio = Stretch' /storage/.config/ARMSX2/inis/PCSX2.ini
	fi

  #Bilinear Filtering
        if [ "$FILTER" = "0" ]
        then
                sed -i '/^filter =/c\filter = 0' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi
        if [ "$FILTER" = "1" ]
        then
                sed -i '/^filter =/c\filter = 1' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi
        if [ "$FILTER" = "2" ]
        then
                sed -i '/^filter =/c\filter = 2' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi
        if [ "$FILTER" = "3" ]
        then
                sed -i '/^filter =/c\filter = 3' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi

  #Graphics Backend
	if [ "$GRENDERER" = "0" ]
	then
  		sed -i '/^Renderer =/c\Renderer = -1' /storage/.config/ARMSX2/inis/PCSX2.ini
	fi
	if [ "$GRENDERER" = "1" ]
	then
  		sed -i '/^Renderer =/c\Renderer = 12' /storage/.config/ARMSX2/inis/PCSX2.ini
	fi
	if [ "$GRENDERER" = "2" ]
	then
  		sed -i '/^Renderer =/c\Renderer = 14' /storage/.config/ARMSX2/inis/PCSX2.ini
	fi
        if [ "$GRENDERER" = "3" ]
        then
                sed -i '/^Renderer =/c\Renderer = 13' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi

  #Internal Resolution
        if [ "$IRES" > "0" ]
        then
                sed -i "/^upscale_multiplier =/c\upscale_multiplier = $IRES" /storage/.config/ARMSX2/inis/PCSX2.ini
        else
                sed -i '/^upscale_multiplier =/c\upscale_multiplier = 1' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi

  #Show FPS
	if [ "$FPS" = "false" ]
	then
  		sed -i '/^OsdShowFPS =/c\OsdShowFPS = false' /storage/.config/ARMSX2/inis/PCSX2.ini
	fi
	if [ "$FPS" = "true" ]
	then
  		sed -i '/^OsdShowFPS =/c\OsdShowFPS = true' /storage/.config/ARMSX2/inis/PCSX2.ini
	fi

  #EE Cycle Rate
        sed -i '/^EECycleRate =/c\EECycleRate = 0' /storage/.config/ARMSX2/inis/PCSX2.ini
        if [ "$RATE" = "0" ]
        then
                sed -i '/^EECycleRate =/c\EECycleRate = -3' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi
        if [ "$RATE" = "1" ]
        then
                sed -i '/^EECycleRate =/c\EECycleRate = -2' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi
        if [ "$RATE" = "2" ]
        then
                sed -i '/^EECycleRate =/c\EECycleRate = -1' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi
        if [ "$RATE" = "3" ]
        then
                sed -i '/^EECycleRate =/c\EECycleRate = 0' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi
        if [ "$RATE" = "4" ]
        then
                sed -i '/^EECycleRate =/c\EECycleRate = 1' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi
        if [ "$RATE" = "5" ]
        then
                sed -i '/^EECycleRate =/c\EECycleRate = 2' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi
        if [ "$RATE" = "6" ]
        then
                sed -i '/^EECycleRate =/c\EECycleRate = 3' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi

  #EE Cycle Skip
        sed -i '/^EECycleSkip =/c\EECycleSkip = 0' /storage/.config/ARMSX2/inis/PCSX2.ini
        if [ "$SKIP" = "0" ]
        then
                sed -i '/^EECycleSkip =/c\EECycleSkip = 0' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi
        if [ "$SKIP" = "1" ]
        then
                sed -i '/^EECycleSkip =/c\EECycleSkip = 1' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi
        if [ "$SKIP" = "2" ]
        then
                sed -i '/^EECycleSkip =/c\EECycleSkip = 2' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi
        if [ "$SKIP" = "3" ]
        then
                sed -i '/^EECycleSkip =/c\EECycleSkip = 3' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi

#HW download mode
        sed -i '/^HWDownloadMode =/c\HWDownloadMode = 0' /storage/.config/ARMSX2/inis/PCSX2.ini
        if [ "$HWDOWNLOAD" = "0" ]
        then
                sed -i '/^HWDownloadMode =/c\HWDownloadMode = 0' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi
        if [ "$HWDOWNLOAD" = "1" ]
        then
                sed -i '/^HWDownloadMode =/c\HWDownloadMode = 1' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi
        if [ "$HWDOWNLOAD" = "2" ]
        then
                sed -i '/^HWDownloadMode =/c\HWDownloadMode = 2' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi
        if [ "$HWDOWNLOAD" = "3" ]
        then
                sed -i '/^HWDownloadMode =/c\HWDownloadMode = 3' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi

#Widescreen patches
	if [ "$ENABLE_WIDESCREEN_PATCHES" = "true" ]
	then
  		sed -i '/^EnableWideScreenPatches =/c\EnableWideScreenPatches = true' /storage/.config/ARMSX2/inis/PCSX2.ini
        else
                sed -i '/^EnableWideScreenPatches =/c\EnableWideScreenPatches = false' /storage/.config/ARMSX2/inis/PCSX2.ini
        fi

#Retroachievements
  /usr/bin/cheevos_armsx2.sh

#Graphic driver fixes
@GRAPHICS@

#Lossless Scaling frame generation
  LSFG_DLL_PATH="/storage/roms/bios/armsx2/Lossless.dll"
  if [ ! -f "${LSFG_DLL_PATH}" ] && [ -f "/storage/games-internal/roms/steam/steamapps/common/Lossless Scaling/Lossless.dll" ]; then
    LSFG_DLL_PATH="/storage/games-internal/roms/steam/steamapps/common/Lossless Scaling/Lossless.dll"
  elif [ ! -f "${LSFG_DLL_PATH}" ] && [ -f "/storage/.local/share/Steam/steamapps/common/Lossless Scaling/Lossless.dll" ]; then
    LSFG_DLL_PATH="/storage/.local/share/Steam/steamapps/common/Lossless Scaling/Lossless.dll"
  elif [ ! -f "${LSFG_DLL_PATH}" ] && [ -f "/storage/roms/steam/steamapps/common/Lossless Scaling/Lossless.dll" ]; then
    LSFG_DLL_PATH="/storage/roms/steam/steamapps/common/Lossless Scaling/Lossless.dll"
  fi

  if [ "${LSFG_ENABLE}" = "1" ] && [ -f "${LSFG_DLL_PATH}" ]; then
    unset DISABLE_LSFGVK
    export LSFGVK_ENV=1
    export LSFGVK_DLL_PATH="${LSFG_DLL_PATH}"
    export LSFGVK_MULTIPLIER="${LSFG_MULTIPLIER}"
    export LSFGVK_FLOW_SCALE="${LSFG_FLOW_SCALE}"
    export LSFGVK_PERFORMANCE_MODE="${LSFG_PERFORMANCE_MODE}"
    export LSFGVK_PACING=none
    sed -i '/^Renderer =/c\Renderer = 14' /storage/.config/ARMSX2/inis/PCSX2.ini
    sed -i '/^VsyncEnable =/c\VsyncEnable = true' /storage/.config/ARMSX2/inis/PCSX2.ini
  else
    export DISABLE_LSFGVK=1
    unset LSFGVK_ENV LSFGVK_DLL_PATH LSFGVK_MULTIPLIER LSFGVK_FLOW_SCALE LSFGVK_PERFORMANCE_MODE LSFGVK_PACING
    sed -i '/^VsyncEnable =/c\VsyncEnable = false' /storage/.config/ARMSX2/inis/PCSX2.ini
    if [ "${LSFG_ENABLE}" = "1" ]; then
      echo "LSFG disabled: Lossless.dll not found in the ARMSX2 BIOS or Steam directories."
    fi
  fi

#Set QT enviornment to wayland
  export QT_QPA_PLATFORM=wayland

#Run ARMSX2 emulator
  export SDL_AUDIODRIVER=pulseaudio
  set_kill set "-9 armsx2-qt"
  ${EMUPERF} /usr/share/armsx2-sa/armsx2-qt -bigpicture -fullscreen "${1}"
