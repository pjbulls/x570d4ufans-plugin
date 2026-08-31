#!/bin/bash
# get_gpu_temp.sh - print current Intel GPU temperature in deg C.
#
# Auto-detects a GPU hwmon chip by name: "i915" (older kernels / iGPUs)
# or "xe" (newer kernel driver, recent platforms), then reads temp1_input.
#
# Override auto-detection by setting GPU_HWMON_NAME in fans.cfg.
#
# Prints a single number (one decimal) on success, nothing if no sensor found.

get_gpu_temp() {
  local filter="${GPU_HWMON_NAME:-i915|xe}"
  
  for hw in /sys/class/hwmon/hwmon*; do
    [[ -f "$hw/name" ]] || continue
    local name
    name=$(<"$hw/name")
    [[ "$name" =~ ^($filter)$ ]] || continue
    
    local f="$hw/temp1_input"
    if [[ -f "$f" ]]; then
      local v
      v=$(<"$f")
      [[ "$v" =~ ^-?[0-9]+$ ]] || continue
      awk -v val="$v" 'BEGIN{printf "%.1f\n", val/1000}'
      return 0
    fi
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  X570D4UFANS_CFG="/boot/config/plugins/x570d4ufans/fans.cfg"
  [[ -f "$X570D4UFANS_CFG" ]] && source "$X570D4UFANS_CFG"
  get_gpu_temp
fi
