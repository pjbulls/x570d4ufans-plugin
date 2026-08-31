#!/bin/bash
# apply_fan_speed.sh - turn PWM into ipmi raw commands.

# Scales 20-100 (%) to 15-64 (ipmi-raw). Does not allow fans to stop.
scale() {
	local v="$1"
	(( v < 20 )) && v=20
	(( v > 100 )) && v=100
	echo $(( 15 + (v - 20) * 49 / 80 ))
}

## Value for non-mapped fans (in ipmi-raw scale)
idle=19

set_fans_to_manual() {
	ipmi-raw 00 3a d8 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 > /dev/null
}

set_fans_to_auto() {
	ipmi-raw 00 3a d8 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 > /dev/null
}

get_fan_speed() {
	ipmi-raw 00 3a d7
}

fan_vals_have=()
FAN_SLOT_NAMES=(FAN1 FAN2 FAN3 FAN4_1 FAN5_1 FAN6_1)
declare -A FAN_CATEGORY=()

fan_map_register() {
	local category="$1" names="$2" n
	local IFS=','
	local names_arr
	read -ra names_arr <<< "$names"
	for n in "${names_arr[@]}"; do
		n="${n#"${n%%[![:space:]]*}"}"
		n="${n%"${n##*[![:space:]]}"}"
		[[ -z "$n" ]] && continue
		FAN_CATEGORY["$n"]="$category"
	done
}

build_fan_category_map() {
	FAN_CATEGORY=()
	fan_map_register "cpu" "$FAN_MAP_CPU"
	fan_map_register "gpu" "$FAN_MAP_GPU"
	fan_map_register "hdd" "$FAN_MAP_HDD"
	fan_map_register "sys" "$FAN_MAP_SYS"
}

fan_slot_value() {
	local slot="$1" cpu="$2" gpu="$3" hdd="$4" sys="$5"
	case "${FAN_CATEGORY[$slot]:-}" in
		cpu) echo "$cpu"  ;;
		gpu) echo "$gpu"  ;;
		hdd) echo "$hdd"  ;;
		sys) echo "$sys"  ;;
		*)   echo "$idle" ;;
	esac
}

build_fan_vals() {
	local cpu="$1" gpu="$2" hdd="$3" sys="$4" slot
	fan_vals=()
	for slot in "${FAN_SLOT_NAMES[@]}"; do
		fan_vals+=("$(fan_slot_value "$slot" "$cpu" "$gpu" "$hdd" "$sys")")
	done
}

apply_fan_speeds() {
	local cpu gpu hdd sys
	
	cpu=$(scale "$1")
	gpu=$(scale "$2")
	hdd=$(scale "$3")
	sys=$(scale "$4")
	
	build_fan_category_map
	
	local fan_vals
	build_fan_vals "$cpu" "$gpu" "$hdd" "$sys"
	
	if [[ "${fan_vals[*]}" != "${fan_vals_have[*]}" ]]; then
		set_fans_to_manual || return 2
		ipmi-raw 00 3a d6 "${fan_vals[@]}" "$idle" "$idle" "$idle" "$idle" "$idle" "$idle" "$idle" "$idle" "$idle" "$idle" >/dev/null 2>&1
		fan_vals_have=("${fan_vals[@]}")
	fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  X570D4UFANS_CFG="/boot/config/plugins/x570d4ufans/fans.cfg"
  [[ -f "$X570D4UFANS_CFG" ]] && source "$X570D4UFANS_CFG"
  apply_fan_speeds
fi
