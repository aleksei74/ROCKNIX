#!/bin/bash

rocknix_malisx2_apply() {
  [ "$1" = "malisx2" ] || return 0

  local icd="/usr/share/malisx2/0.5.0/malisx2_icd.aarch64.json"
  if [ -c /dev/mali0 ] && [ -r "$icd" ]; then
    export VK_DRIVER_FILES="$icd"
    export VK_ICD_FILENAMES="$icd"
    unset VK_ADD_DRIVER_FILES
  else
    echo "maliSX2: Mali kbase device or ICD unavailable; keeping the current Vulkan driver" >&2
  fi
}
