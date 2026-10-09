#!/usr/bin/env bash

CACHE_DIR="${QS_CACHE_SYSDATA:-/tmp/qs_sysdata}"
mkdir -p "$CACHE_DIR" 2>/dev/null
NOW=$(date +%s)

u2=0; n2=0; s2=0; i2=0; io2=0; ir2=0; so2=0; st2=0
while read -r cpu_id u n s i io ir so st _rest; do
    if [ "$cpu_id" = "cpu" ]; then
        u2=$u; n2=$n; s2=$s; i2=$i; io2=$io; ir2=$ir; so2=$so; st2=$st
        break
    fi
done < /proc/stat

rx2=0
tx2=0
while read -r line; do
    case "$line" in
        *[ew]*:*)
            stats="${line#*:}"
            read -r r _ _ _ _ _ _ _ t _rest <<< "$stats"
            rx2=$((rx2 + r))
            tx2=$((tx2 + t))
            ;;
    esac
done < /proc/net/dev

PREV_STAT_FILE="$CACHE_DIR/prev_stat"
CPU_USAGE=0
RX_RATE=0
TX_RATE=0

if [ -f "$PREV_STAT_FILE" ]; then
    read -r prev_time u1 n1 s1 i1 io1 ir1 so1 st1 rx1 tx1 < "$PREV_STAT_FILE"
    if [ -n "$st1" ]; then
        IDLE1=$i1
        TOTAL1=$((u1 + n1 + s1 + i1 + io1 + ir1 + so1 + st1))
        IDLE2=$i2
        TOTAL2=$((u2 + n2 + s2 + i2 + io2 + ir2 + so2 + st2))
        DIFF_IDLE=$((IDLE2 - IDLE1))
        DIFF_TOTAL=$((TOTAL2 - TOTAL1))
        if [ "$DIFF_TOTAL" -gt 0 ]; then
            CPU_USAGE=$(( 100 * (DIFF_TOTAL - DIFF_IDLE) / DIFF_TOTAL ))
        fi
        dt=$((NOW - prev_time))
        [ "$dt" -le 0 ] && dt=1
        if [ -n "$rx1" ] && [ "$rx2" -ge "$rx1" ] 2>/dev/null; then
            RX_RATE=$(( (rx2 - rx1) / dt ))
        fi
        if [ -n "$tx1" ] && [ "$tx2" -ge "$tx1" ] 2>/dev/null; then
            TX_RATE=$(( (tx2 - tx1) / dt ))
        fi
    fi
fi

echo "$NOW $u2 $n2 $s2 $i2 $io2 $ir2 $so2 $st2 $rx2 $tx2" > "$PREV_STAT_FILE"

TOTAL_MEM=0
AVAIL_MEM=0
while IFS=":" read -r key val; do
    case "$key" in
        MemTotal)
            val="${val% kB}"
            val="${val//[[:space:]]/}"
            TOTAL_MEM=$val
            ;;
        MemAvailable)
            val="${val% kB}"
            val="${val//[[:space:]]/}"
            AVAIL_MEM=$val
            ;;
    esac
    [ "$TOTAL_MEM" -gt 0 ] && [ "$AVAIL_MEM" -gt 0 ] && break
done < /proc/meminfo

USED_MEM=$((TOTAL_MEM - AVAIL_MEM))
if [ "$TOTAL_MEM" -gt 0 ]; then
    RAM_PCT=$(( 100 * USED_MEM / TOTAL_MEM ))
    RAM_GB_INT=$(( USED_MEM / 1048576 ))
    RAM_GB_FRAC=$(( (USED_MEM % 1048576) * 10 / 1048576 ))
    RAM_GB="${RAM_GB_INT}.${RAM_GB_FRAC}"
else
    RAM_PCT=0
    RAM_GB="0.0"
fi

TEMP_FILE="$CACHE_DIR/temp"
TEMP_TIME_FILE="$CACHE_DIR/temp_time"
LAST_TEMP_TIME=0
[ -f "$TEMP_TIME_FILE" ] && read -r LAST_TEMP_TIME < "$TEMP_TIME_FILE" 2>/dev/null
LAST_TEMP_TIME=${LAST_TEMP_TIME:-0}

if [ -f "$TEMP_FILE" ] && [ $((NOW - LAST_TEMP_TIME)) -lt 6 ]; then
    read -r TEMP < "$TEMP_FILE" 2>/dev/null
    TEMP=${TEMP:-0}
else
    TEMP_RAW=""
    for hwmon in /sys/class/hwmon/hwmon*; do
        if [ -f "$hwmon/name" ]; then
            read -r hwmon_name < "$hwmon/name" 2>/dev/null
            case "$hwmon_name" in
                coretemp|k10temp|zenpower|cpu_thermal|bcm2835_thermal)
                    if [ -f "$hwmon/temp1_input" ]; then
                        read -r TEMP_RAW < "$hwmon/temp1_input" 2>/dev/null
                        break
                    fi
                    ;;
            esac
        fi
    done

    if [ -z "$TEMP_RAW" ]; then
        for tz in /sys/class/thermal/thermal_zone*; do
            if [ -f "$tz/type" ]; then
                read -r tz_type < "$tz/type" 2>/dev/null
                case "$tz_type" in
                    x86_pkg_temp|cpu_thermal|cpu-thermal)
                        read -r TEMP_RAW < "$tz/temp" 2>/dev/null
                        break
                        ;;
                esac
            fi
        done
    fi

    if [ -z "$TEMP_RAW" ]; then
        read -r TEMP_RAW < /sys/class/hwmon/hwmon0/temp1_input 2>/dev/null || read -r TEMP_RAW < /sys/class/thermal/thermal_zone0/temp 2>/dev/null || TEMP_RAW=0
    fi

    if [ "${TEMP_RAW:-0}" -gt 1000 ] 2>/dev/null; then
        TEMP=$((TEMP_RAW / 1000))
    else
        TEMP=${TEMP_RAW:-0}
    fi

    echo "$TEMP" > "$TEMP_FILE"
    echo "$NOW" > "$TEMP_TIME_FILE"
fi

DISK_FILE="$CACHE_DIR/disk"
DISK_TIME_FILE="$CACHE_DIR/disk_time"
LAST_DISK_TIME=0
[ -f "$DISK_TIME_FILE" ] && read -r LAST_DISK_TIME < "$DISK_TIME_FILE" 2>/dev/null
LAST_DISK_TIME=${LAST_DISK_TIME:-0}

if [ -f "$DISK_FILE" ] && [ $((NOW - LAST_DISK_TIME)) -lt 60 ]; then
    read -r DISK_PCT DISK_USED_GB DISK_TOTAL_GB < "$DISK_FILE" 2>/dev/null
else
    read -r DISK_PCT DISK_USED_GB DISK_TOTAL_GB <<< "$(df -Plk -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs -x iso9660 2>/dev/null | awk '
    NR > 1 && $1 !~ /^\/dev\/loop/ && $1 != "udev" && $1 != "none" {
        if (!seen[$1]++) {
            total += $2
            used += $3
        }
    }
    END {
        if (total > 0) {
            pct = int((used / total) * 100 + 0.5)
            printf "%d %.1f %.1f\n", pct, used / 1048576, total / 1048576
        } else {
            print "0 0.0 0.0"
        }
    }')"
    DISK_PCT=${DISK_PCT:-0}
    DISK_USED_GB=${DISK_USED_GB:-0.0}
    DISK_TOTAL_GB=${DISK_TOTAL_GB:-0.0}
    echo "$DISK_PCT $DISK_USED_GB $DISK_TOTAL_GB" > "$DISK_FILE"
    echo "$NOW" > "$DISK_TIME_FILE"
fi

echo "$CPU_USAGE|$RAM_PCT|$RAM_GB|$TEMP|$RX_RATE|$TX_RATE|$DISK_PCT|$DISK_USED_GB|$DISK_TOTAL_GB"
