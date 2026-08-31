#!/bin/bash
# get_fan_rpm.sh - print current fan tachometer readings via IPMI.

find_ipmi_binary() {
  local name="$1" override="$2"
  if [[ -n "$override" ]]; then
    [[ -x "$override" ]] && { echo "$override"; return 0; }
    return 1
  fi
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi
  local p
  for p in "/usr/sbin/$name" "/usr/local/sbin/$name" \
           "/usr/local/emhttp/plugins/ipmi/bin/$name" \
           "/usr/local/emhttp/plugins/ipmi/$name"; do
    [[ -x "$p" ]] && { echo "$p"; return 0; }
  done
  return 1
}

get_fan_rpm() {
  local bin
  bin=$(find_ipmi_binary "ipmi-sensors" "$IPMI_SENSORS_BIN") || return 1
  
  local out
  out=$("$bin" --sensor-types=fan --comma-separated-output --no-header-output --interpret-oem-data 2>/dev/null)
  [[ -z "$out" ]] && return 0
  
  awk -F',' -v q="'" -v dq='"' '
    {
      name = $2
      gsub(/^ +| +$/, "", name); gsub(q, "", name); gsub(dq, "", name)
      if (name == "") next
      
      is_fan = 0; rpm = ""; status = ""
      for (i = 3; i <= NF; i++) {
        v = $i
        gsub(/^ +| +$/, "", v); gsub(q, "", v); gsub(dq, "", v)
        if (v == "") continue
        if (v == "Fan")           { is_fan = 1; continue }
        if (v == "RPM")           { continue }
        if (v ~ /^[Nn]\/?[Aa]$/)  { continue }
        if (v ~ /^[0-9]+([.][0-9]+)?[ \t]*RPM$/) {
          split(v, a, /[ \t]/); rpm = a[1]; continue
        }
        if (v ~ /^[0-9]+([.][0-9]+)?$/ && rpm == "") { rpm = v + 0; continue }
        if (status == "") status = v
      }
      if (!is_fan) next
      if (status == "") status = (rpm != "" ? "ok" : "ns")
      print name "|" rpm "|" status
    }
  ' <<< "$out"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  X570D4UFANS_CFG="/boot/config/plugins/x570d4ufans/fans.cfg"
  [[ -f "$X570D4UFANS_CFG" ]] && source "$X570D4UFANS_CFG"
  get_fan_rpm
fi
