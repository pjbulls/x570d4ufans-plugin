#!/bin/bash
# poll.sh - main x570d4ufans loop.
#
# Every POLL_INTERVAL seconds:
#   1. Reads CPU / GPU / HDD temperatures
#   2. Evaluates each against its configured curve
#   3. Combines targets into one overall system PWM value
#   4. Hands the target PWMs to apply_fan_speed.sh
#   5. Writes /var/local/x570d4ufans/state.json for the dashboard tile
#
# Normally started/stopped via: /etc/rc.d/rc.x570d4ufans {start|stop}
# Run a single cycle for testing:  poll.sh --once

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/fan_curve.sh"
source "$SCRIPT_DIR/get_cpu_temp.sh"
source "$SCRIPT_DIR/get_gpu_temp.sh"
source "$SCRIPT_DIR/get_hdd_temps.sh"
source "$SCRIPT_DIR/get_fan_rpm.sh"
source "$SCRIPT_DIR/apply_fan_speed.sh"

combine_pwm_avg() {
  local vals=() v
  for v in "$@"; do
    [[ -n "$v" ]] && vals+=("$v")
  done
  [[ ${#vals[@]} -eq 0 ]] && return 0

  local sum=0
  for v in "${vals[@]}"; do sum=$((sum + v)); done
  echo $(( sum / ${#vals[@]} ))
}

combine_pwm_max() {
  local vals=() v
  for v in "$@"; do
    [[ -n "$v" ]] && vals+=("$v")
  done
  [[ ${#vals[@]} -eq 0 ]] && return 0
  
  local max=0
  for v in "${vals[@]}"; do (( v > max )) && max=$v; done
  echo "$max"
}

combine_pwm() {
  case "${COMBINE_STRATEGY:-max}" in
    avg) combine_pwm_avg "$@" ;;
    *)   combine_pwm_max "$@" ;;
  esac
}

map_fans() {
  local names="$1"
  local IFS=','
  local n out="" nfans=0
  
  read -ra fan_names <<< "$names"
  
  for n in "${fan_names[@]}"; do
    n="${n#"${n%%[![:space:]]*}"}"
    n="${n%"${n##*[![:space:]]}"}"
    
    [[ -z "$n" ]] && continue
    [[ -z "${FAN_RPM_BY_NAME[$n]+x}" ]] && continue
    
    local rpm="${FAN_RPM_BY_NAME[$n]%%|*}"
    local status="${FAN_RPM_BY_NAME[$n]#*|}"
    
    [[ $nfans -gt 0 ]] && out+=","
    
    out+=$(printf '{"name":"%s","rpm":%s,"status":"%s"}' \
      "$(json_escape "$n")" \
      "${rpm:-null}" \
      "$(json_escape "$status")")
    
    nfans+=1
  done
  
  printf '%s' "$out"
}

run_once() {
  local cpu_temp gpu_temp cpu_pwm gpu_pwm hdd_pwm hdd_hottest_temp hdd_hottest_name sys_pwm
  local disks_json="" nhdd=0 hdd_lines
  
  hdd_lines=$(get_hdd_temps)
  while IFS='|' read -r d_name d_dev d_type d_temp d_state; do
    [[ -z "$d_name" ]] && continue
    if [[ -n "$d_temp" ]]; then
      if [[ -z "$hdd_hottest_temp" ]] || awk -v a="$d_temp" -v b="$hdd_hottest_temp" 'BEGIN{exit !(a>b)}'; then
        hdd_hottest_temp="$d_temp"
        hdd_hottest_name="$d_name"
      fi
    fi
    [[ $nhdd -gt 0 ]] && disks_json+=","
    disks_json+=$(printf '{"name":"%s","device":"%s","type":"%s","temp":%s,"state":"%s"}' \
      "$(json_escape "$d_name")" "$(json_escape "$d_dev")" "$(json_escape "$d_type")" \
      "${d_temp:-null}" "$(json_escape "$d_state")")
    nhdd+=1
  done <<< "$hdd_lines"
  
  # Blank HDD temperature is likely due to all standby (so don't run fans too fast then?)
  [[ -n "$hdd_hottest_temp" ]] && hdd_pwm=$(curve_pwm "$hdd_hottest_temp" "$HDD_CURVE") || hdd_pwm=30
  local hottest_name_json="null"
  [[ -n "$hdd_hottest_name" ]] && hottest_name_json="\"$(json_escape "$hdd_hottest_name")\"" || hottest_name_json="\"unknown\""
  
  cpu_temp=$(get_cpu_temp)
  gpu_temp=$(get_gpu_temp)
  # For missing CPU/GPU we're a bit more conservative (but this really shouldn't happen)
  [[ -n "$cpu_temp" ]] && cpu_pwm=$(curve_pwm "$cpu_temp" "$CPU_CURVE") || cpu_pwm=50
  [[ -n "$gpu_temp" ]] && gpu_pwm=$(curve_pwm "$gpu_temp" "$GPU_CURVE") || gpu_pwm=50
  
  sys_pwm=$(combine_pwm "$cpu_pwm" "$gpu_pwm" "$hdd_pwm")
  # Cannot happen since all were caught above, better safe than sorry
  [[ -z "$sys_pwm" ]] && sys_pwm=50
  
  apply_fan_speeds "$cpu_pwm" "$gpu_pwm" "$hdd_pwm" "$sys_pwm"
  
  # Enough to have the RPM sensors update?
  sleep 2
  
  local fans_json="" nfans=0 fan_lines
  fan_lines=$(get_fan_rpm)
  declare -A FAN_RPM_BY_NAME=()
  while IFS='|' read -r f_name f_rpm f_status; do
    [[ -z "$f_name" ]] && continue
    FAN_RPM_BY_NAME["$f_name"]="${f_rpm}|${f_status}"
    [[ $nfans -gt 0 ]] && fans_json+=","
    fans_json+=$(printf '{"name":"%s","rpm":%s,"status":"%s"}' \
      "$(json_escape "$f_name")" "${f_rpm:-null}" "$(json_escape "$f_status")")
    nfans+=1
  done <<< "$fan_lines"
  
  local cpu_fans_json gpu_fans_json hdd_fans_json sys_fans_json
  cpu_fans_json=$(map_fans "$FAN_MAP_CPU")
  gpu_fans_json=$(map_fans "$FAN_MAP_GPU")
  hdd_fans_json=$(map_fans "$FAN_MAP_HDD")
  sys_fans_json=$(map_fans "$FAN_MAP_SYS")
  
  cat > "$X570D4UFANS_STATE_FILE.tmp" <<EOF
{
  "updated": "$(date -Iseconds)",
  "system": {"pwm": ${sys_pwm:-null}, "fans": [${sys_fans_json}]},
  "cpu": {"temp": ${cpu_temp:-null}, "pwm": ${cpu_pwm:-null}, "fans": [${cpu_fans_json}]},
  "gpu": {"temp": ${gpu_temp:-null}, "pwm": ${gpu_pwm:-null}, "fans": [${gpu_fans_json}]},
  "hdd": {
    "hottest_name": ${hottest_name_json},
    "hottest_temp": ${hdd_hottest_temp:-null},
    "pwm": ${hdd_pwm:-null},
    "disks": [${disks_json}],
    "fans": [${hdd_fans_json}]
  },
  "fans": [${fans_json}]
}
EOF
  mv "$X570D4UFANS_STATE_FILE.tmp" "$X570D4UFANS_STATE_FILE"
}

load_config

if [[ "$1" == "--once" ]]; then
  run_once
  exit 0
fi

log "started (poll interval ${POLL_INTERVAL}s)"

# run_once already sleeps 2s, minimum actual POLL_INTERVAL is 3s
sleeptime=$((POLL_INTERVAL-2))
(( sleeptime < 1 )) && sleeptime=1

while true; do
  run_once
  sleep "$sleeptime"
done
