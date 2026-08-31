#!/bin/bash
# fan_curve.sh - piecewise linear fan curve evaluation.
#
#   curve_pwm <temp_c> <curve>
#
#     curve is a comma-separated list of "temp:pwm" breakpoints, ascending
#     by temperature, e.g. "40:20,55:35,65:55,75:80,85:100".
#     - Below the first breakpoint: the first pwm value is returned.
#     - Above the last breakpoint:  the last pwm value is returned.
#     - Between two breakpoints:    linearly interpolated.
#
#     Prints an integer 0-100 to stdout. Prints nothing and returns 1 if
#     temp or curve is empty.

curve_pwm() {
  local temp="$1" curve="$2"
  [[ -z "$temp" || -z "$curve" ]] && return 1
  
  local IFS=','
  local -a points=($curve)
  local prev_t="" prev_p=""
  local point t p
  
  for point in "${points[@]}"; do
    t="${point%%:*}"
    p="${point##*:}"
    
    if awk -v a="$temp" -v b="$t" 'BEGIN{exit !(a<=b)}'; then
      if [[ -z "$prev_t" ]]; then
        printf '%d\n' "$p"
      else
        awk -v temp="$temp" -v t0="$prev_t" -v p0="$prev_p" -v t1="$t" -v p1="$p" \
          'BEGIN {
             if (t1 == t0) { printf "%d\n", p1; exit }
             v = p0 + (p1 - p0) * (temp - t0) / (t1 - t0);
             if (v < 0) v = 0;
             if (v > 100) v = 100;
             printf "%d\n", v
           }'
      fi
      return 0
    fi
    prev_t="$t"; prev_p="$p"
  done
  
  # Hotter than every breakpoint -> hold at the last (highest) pwm.
  printf '%d\n' "$prev_p"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Standalone test: ./fan_curve.sh 62.2 "40:20,55:35,65:55,75:80,85:100"  -->  49
  curve_pwm "$1" "$2"
fi
