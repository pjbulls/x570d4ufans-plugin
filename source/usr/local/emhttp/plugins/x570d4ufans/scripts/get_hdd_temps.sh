#!/bin/bash
# get_hdd_temps.sh - print per-disk temperatures.
#
# Output: one tab-separated line per disk:
#   <unraid_name>  <device>  <type>  <temp_c_or_empty>  <state>
#
# PRIMARY SOURCE: Unraid's /var/local/emhttp/disks.ini, which emhttp
# keeps updated for the Main tab. Reading its cache means this script
# never causes a disk to spin up just to be measured.
#
# FALLBACK / HDD_TEMP_SOURCE=smartctl: polls smartctl directly against
# /dev/sdX with `-n standby`, which also skips the read (and therefore
# spin-up) for disks in standby/sleep. Used automatically if disks.ini
# is missing/empty or explicitly if you set HDD_TEMP_SOURCE in fans.cfg.

get_hdd_temps_emhttp() {
  local ini="/var/local/emhttp/disks.ini"
  [[ -f "$ini" ]] || return 1
  
  awk -v include_ssd="${HDD_INCLUDE_NONROTATIONAL:-no}" -v exclude=" ${HDD_EXCLUDE} " '
    function reset() { name=device=type=temp=status=rotational="" }
    function flush() {
      if (name == "") { reset(); return }
      if (rotational != "1" && include_ssd != "yes") { reset(); return }
      if (index(exclude, " " name " ") > 0 || index(exclude, " " device " ") > 0) { reset(); return }
      state = "unknown"; t = ""
      if (temp != "" && temp+0 > 0) { t = temp; state = "active" }
      else if (status == "DISK_OK") { state = "standby" }
      print name "|" device "|" type "|" t "|" state
      reset()
    }
    BEGIN { reset(); sections = 0 }
    /^\[/ { flush(); next }
    /^name="/       { gsub(/^name="|"$/, "", $0); name=$0 }
    /^device="/     { gsub(/^device="|"$/, "", $0); device=$0 }
    /^type="/       { gsub(/^type="|"$/, "", $0); type=$0 }
    /^temp="/       { gsub(/^temp="|"$/, "", $0); temp=$0 }
    /^status="/     { gsub(/^status="|"$/, "", $0); status=$0 }
    /^rotational="/ { gsub(/^rotational="|"$/, "", $0); rotational=$0 }
    END { flush(); if (sections == 0) exit 2 }
  ' "$ini"
  local rc=$?
  (( rc == 2 )) && return 1
  return 0
}

get_hdd_temps_smartctl() {
  local boot_dev
  boot_dev=$(findmnt -no SOURCE /boot 2>/dev/null | sed -E 's#^/dev/##; s/[0-9]+$//')
  
  local path dev out
  for path in /sys/block/sd*; do
    [[ -e "$path" ]] || continue
    dev="$(basename "$path")"
    [[ -n "$boot_dev" && "$dev" == "$boot_dev" ]] && continue
    [[ " $HDD_EXCLUDE " == *" $dev "* ]] && continue
    
    out=$(smartctl -n standby -A "/dev/$dev" 2>/dev/null)
    if grep -qiE 'STANDBY|SLEEP' <<<"$out"; then
      printf '%s|%s|%s|%s|%s\n' "$dev" "$dev" "Data" "" "standby"
      continue
    fi
    local t
    t=$(awk '
      /^194 Temperature_Celsius/ { print $10; found=1; exit }
      /^190 Airflow_Temperature_Cel/ { print $10; found=1; exit }
      /^Temperature:/ { print $2; found=1; exit }
    ' <<<"$out")
    if [[ -n "$t" ]]; then
      printf '%s|%s|%s|%s|%s\n' "$dev" "$dev" "Data" "$t" "active"
    else
      printf '%s|%s|%s|%s|%s\n' "$dev" "$dev" "Data" "" "unknown"
    fi
  done
}

get_hdd_temps() {
  case "${HDD_TEMP_SOURCE:-emhttp}" in
    smartctl) get_hdd_temps_smartctl ;;
    *)        get_hdd_temps_emhttp || get_hdd_temps_smartctl ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  X570D4UFANS_CFG="/boot/config/plugins/x570d4ufans/fans.cfg"
  [[ -f "$X570D4UFANS_CFG" ]] && source "$X570D4UFANS_CFG"
  get_hdd_temps
fi
