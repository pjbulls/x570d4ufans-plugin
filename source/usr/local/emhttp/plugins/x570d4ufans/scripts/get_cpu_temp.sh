#!/bin/bash
# get_cpu_temp.sh - print current CPU package temperature in deg C.
#
# Auto-detects a CPU hwmon chip by name: coretemp (Intel), k10temp /
# zenpower (AMD), cpu_thermal (some ARM/embedded boards).
#
# Override auto-detection by setting CPU_HWMON_NAME in fans.cfg to the
# exact chip name shown in /sys/class/hwmon/hwmon*/name on your system.
#
# Prints a single number (one decimal) on success, nothing on failure.

get_cpu_temp() {
  local filter="${CPU_HWMON_NAME:-coretemp|k10temp|zenpower|cpu_thermal}"
  local best=""

  for hw in /sys/class/hwmon/hwmon*; do
    [[ -f "$hw/name" ]] || continue
    local name
    name=$(<"$hw/name")
    [[ "$name" =~ ^($filter)$ ]] || continue

    for f in "$hw"/temp*_input; do
      [[ -f "$f" ]] || continue
      local v
      v=$(<"$f")
      [[ "$v" =~ ^-?[0-9]+$ ]] || continue
      if [[ -z "$best" || "$v" -gt "$best" ]]; then
        best="$v"
      fi
    done
  done

  [[ -n "$best" ]] && awk -v v="$best" 'BEGIN{printf "%.1f\n", v/1000}'
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  X570D4UFANS_CFG="/boot/config/plugins/x570d4ufans/fans.cfg"
  [[ -f "$X570D4UFANS_CFG" ]] && source "$X570D4UFANS_CFG"
  get_cpu_temp
fi
