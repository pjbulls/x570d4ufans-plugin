# x570d4ufans-plugin

#### Background

The [ASRock Rack X570D4U](https://www.asrockrack.com/general/productdetail.asp?Model=X570D4U) series does
not expose fan control to the OS, but rather to the BMC / IPMI. While it is possible to set relatively simple
fan curves there, I wanted more control -- not in the least for a manual fix to the mess that is the Sparkle
Arc A310's built-in fan control.

This plugin queries temperatures of the CPU, **Intel** GPU, and hottest HDD, runs them through PWM curves,
and additionaly combines (via average or maximum) those PWMs. These four values are handed to a fan control
script where each of the PWMs can be mapped to one or more of the six fan headers. A Dashboard tile summarizes
the relevant temperatures, PWMs, and fan speeds.

#### Dependencies

This plugin requires `freeipmi` (or another package that provides `ipmi-raw` and some form of sensor monitoring),
which is not included in the install script. I'd recommend installing Simon Fair's [IPMI](https://github.com/SimonFair/IPMI-unRAID) plugin.

#### Configuration

Settings are not exposed in the UI, so need to be manually configured in `/boot/config/plugins/x570d4ufans/fans.cfg`.
Should that file not exist default values are also defined in [`common.sh`](source/usr/local/emhttp/plugins/x570d4ufans/scripts/common.sh),
they are:

```
# x570d4ufan fans.cfg
# --- Polling -----------------------------------------------------------------
# Seconds between temperature / fan curve evaluations.
POLL_INTERVAL=15

# --- Fan curves --------------------------------------------------------------
# Comma-separated "temp:speed%" breakpoints, ascending by temperature (!).
CPU_CURVE="0:20,40:20,55:35,65:55,75:80,85:100"
HDD_CURVE="0:20,30:20,38:40,40:60,42:80,43:100"
GPU_CURVE="0:20,50:20,55:40,60:65,80:100"

# --- Sensor discovery --------------------------------------------------------
# hwmon chip name to use for CPU & GPU temps. Leave blank to auto-detect (Intel GPU).
CPU_HWMON_NAME=""
GPU_HWMON_NAME=""

# --- HDD temperatures --------------------------------------------------------
# Source: "emhttp" (default) reads Unraid's cached disk state.
#         "smartctl" polls /dev/sdX directly with `smartctl -n standby`.
HDD_TEMP_SOURCE="emhttp"

# Space-separated disk (e.g. "disk1") or device (e.g. "sdb") names to exclude.
HDD_EXCLUDE=""

# By default only rotational (spinning) disks feed HDD_CURVE.
# Set "yes" to also include SSD/cache pool devices.
HDD_INCLUDE_NONROTATIONAL="no"

# --- Combining curves into a system fan target -------------------------------
# How CPU / GPU / HDD curve outputs are combined [max/avg] into a single value.
COMBINE_STRATEGY="avg"

# --- Fan RPM measurement -----------------------------------------------------
# Location of the ipmi-sensors binary. Leave blank to auto-detect common values.
IPMI_SENSORS_BIN=""

# --- PWM-to-header mapping ---------------------------------------------------
# Associate sensor names with PWMs and rows on the Dashboard tile.
FAN_MAP_CPU="FAN3"
FAN_MAP_GPU="FAN2"
FAN_MAP_HDD="FAN4_1"
FAN_MAP_SYS="FAN5_1"
```

In particular the `FAN_MAP`s are very specific to the wiring of your system!

In my case (a Fractal Node 804) I have:
- the GPU fan plugged into FAN2,
- the CPU cooler in FAN3,
- the "right" (non-motherboard, HDD cage/PSU) side of the case into FAN4, and
- the left side (motherboard case fans) into FAN5.

A few non-PWM fans for the chipset and ethernet are also on FAN6 but these are
not mapped, controlled or reported since they run at fixed RPM. You can map the
second sensor of 6-pin headers (e.g. FAN4_2) to show them in the Dashboard, but
PWM only looks at & goes to the first name (FAN4_1).
