#!/bin/bash
# Sourced by other scripts; not meant to be run directly.

X570D4UFANS_LOGFILE="/var/log/x570d4ufans.log"
X570D4UFANS_CFG="/boot/config/plugins/x570d4ufans/fans.cfg"
X570D4UFANS_STATE_DIR="/var/local/x570d4ufans"
X570D4UFANS_STATE_FILE="$X570D4UFANS_STATE_DIR/state.json"
X570D4UFANS_LOGTAG="x570d4ufans"

# Defaults used if fans.cfg is missing or doesn't set a value.
POLL_INTERVAL=15
CPU_CURVE="0:20,40:20,55:35,65:55,75:80,85:100"
HDD_CURVE="0:20,30:20,38:40,40:60,42:80,43:100"
GPU_CURVE="0:20,50:20,55:40,60:65,80:100"
CPU_HWMON_NAME=""
GPU_HWMON_NAME=""
HDD_TEMP_SOURCE="emhttp"
HDD_EXCLUDE=""
HDD_INCLUDE_NONROTATIONAL="no"
COMBINE_STRATEGY="avg"
IPMI_SENSORS_BIN=""
FAN_MAP_CPU="FAN3"
FAN_MAP_GPU="FAN2"
FAN_MAP_HDD="FAN4_1"
FAN_MAP_SYS="FAN5_1"

load_config() {
  mkdir -p "$X570D4UFANS_STATE_DIR"
  if [[ -f "$X570D4UFANS_CFG" ]]; then
    source "$X570D4UFANS_CFG"
  fi
}

log() {
  logger -t "$X570D4UFANS_LOGTAG" -- "$*"
  echo "[$(date "+%Y-%m-%d %H:%M:%S")] $*" >> "$X570D4UFANS_LOGFILE"
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  
  # Escape control characters
  local out="" c ord i len=${#s}
  for (( i = 0; i < len; i++ )); do
    c="${s:i:1}"
    case "$c" in
      $'\n') out+='\n' ;;
      $'\r') out+='\r' ;;
      $'\t') out+='\t' ;;
      *)
        printf -v ord '%d' "'$c"
        if (( ord < 0x20 )); then
          printf -v c '\\u%04x' "$ord"
        fi
        out+="$c"
        ;;
    esac
  done
  
  printf '%s' "$out"
}
