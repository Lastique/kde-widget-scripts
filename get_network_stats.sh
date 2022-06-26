#!/bin/bash
#
# Displays network utilization for interfaces passed in command line arguments.
# Multiple interfaces will be added together. Use -B to show in bytes per second.

STATE_FILE="/run/user/${UID}/network_stats_state.txt"

declare -i NOW=${EPOCHREALTIME/./}
declare -i PREV_TIME=$NOW

declare -i DISPLAY_BYTES_PER_SECOND=0
declare -a INTERFACES
declare -a INTERFACES_RX
declare -a INTERFACES_TX
declare -A PREV_INTERFACES_RX
declare -A PREV_INTERFACES_TX

declare -i TOTAL_BYTES_RX=0
declare -i TOTAL_BYTES_TX=0

read_interface_stats()
{
    local interface
    local -i interface_rx=0
    local -i interface_tx=0

    for interface in ${INTERFACES[@]}
    do
        if ! read -r interface_rx < "/sys/class/net/${interface}/statistics/rx_bytes"
        then
            interface_rx=0
        fi
        INTERFACES_RX+=($interface_rx)
        if ! read -r interface_tx < "/sys/class/net/${interface}/statistics/tx_bytes"
        then
            interface_tx=0
        fi
        INTERFACES_TX+=($interface_tx)
    done
}

read_state_file()
{
    local interface
    local line
    local -i prev_time_parsed=0
    local -a fields
    while read -r line
    do
        if [ $prev_time_parsed -eq 0 ]
        then
            read -r PREV_TIME <<<"$line"
            prev_time_parsed=1
        else
            read -ra fields <<<"$line"
            if [ "${#fields[@]}" -ge 3 ]
            then
                interface="${fields[0]}"
                PREV_INTERFACES_RX[$interface]="${fields[1]}"
                PREV_INTERFACES_TX[$interface]="${fields[2]}"
            fi
        fi
    done < "$STATE_FILE"
}

write_state_file()
{
    local -i i

    echo "$NOW" > "$STATE_FILE"

    for ((i=0; i<${#INTERFACES[@]}; ++i))
    do
        echo "${INTERFACES[$i]} ${INTERFACES_RX[$i]} ${INTERFACES_TX[$i]}" >> "$STATE_FILE"
    done
}

accumulate_totals()
{
    local -i i
    local -i value
    local -i prev_value
    for ((i=0; i<${#INTERFACES[@]}; ++i))
    do
        interface="${INTERFACES[$i]}"
        if [ -n "${PREV_INTERFACES_RX[$interface]}" ]
        then
            value=${INTERFACES_RX[$i]}
            prev_value=${PREV_INTERFACES_RX[$interface]}
            TOTAL_BYTES_RX+=$((value - prev_value))

            value=${INTERFACES_TX[$i]}
            prev_value=${PREV_INTERFACES_TX[$interface]}
            TOTAL_BYTES_TX+=$((value - prev_value))
        fi
    done
}

format_rate()
{
    local -i value=$(($1))
    local unit
    if [ $DISPLAY_BYTES_PER_SECOND -eq 0 ]
    then
        value=$((value * 8))
        unit="bps"
        if [ "$value" -gt 10000 ]
        then
            value=$((value / 1000))
            unit="Kbps"
        fi
        if [ "$value" -gt 10000 ]
        then
            value=$((value / 1000))
            unit="Mbps"
        fi
        if [ "$value" -gt 10000 ]
        then
            value=$((value / 1000))
            unit="Gbps"
        fi
    else
        unit="B/s"
        if [ "$value" -gt 10240 ]
        then
            value=$((value / 1024))
            unit="KiB/s"
        fi
        if [ "$value" -gt 10240 ]
        then
            value=$((value / 1024))
            unit="MiB/s"
        fi
        if [ "$value" -gt 10240 ]
        then
            value=$((value / 1024))
            unit="GiB/s"
        fi
    fi

    local -i value_sig=$((value / 10))
    local -i value_frac=$((value % 10))
    FORMATTED_RATE="${value_sig}.${value_frac} $unit"
}

while [ $# -gt 0 ]
do
    case $1 in
        -B)
            DISPLAY_BYTES_PER_SECOND=1
            shift
            ;;
        -*)
            echo "Unsupported option: $1" >2
            exit 1
            ;;
        *)
            INTERFACES+=("$1")
            shift
            ;;
    esac
done

read_interface_stats

if [ -f "$STATE_FILE" ]
then
    read_state_file
    accumulate_totals
fi

declare -i RX_BYTES_PER_10SEC=0
declare -i TX_BYTES_PER_10SEC=0

declare -i TIME_ELAPSED=0
TIME_ELAPSED=$((NOW - PREV_TIME))
if [ $TIME_ELAPSED -gt 0 ]
then
    RX_BYTES_PER_10SEC=$((TOTAL_BYTES_RX * 10000000 / TIME_ELAPSED))
    TX_BYTES_PER_10SEC=$((TOTAL_BYTES_TX * 10000000 / TIME_ELAPSED))
fi

format_rate $RX_BYTES_PER_10SEC
RX_STR="$FORMATTED_RATE"

format_rate $TX_BYTES_PER_10SEC
TX_STR="$FORMATTED_RATE"

printf "↓ ${RX_STR}\n↑ ${TX_STR}\n"

write_state_file
