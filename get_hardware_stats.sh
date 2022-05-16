#!/bin/bash

declare -i CPU_TEMP=0
declare -i CPU_FREQ=0
declare -i GPU_TEMP=0
declare -i GPU_FREQ=0

get_cpu_temp()
{
    local file
    local line
    local temp
    for file in /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input
    do
        while IFS= read -r line; do
            if [ -z "$temp" ]
            then
                temp="$line"
                break
            fi
        done < "$file"
        break
    done
    CPU_TEMP="${temp::-3}"
}

get_cpu_freq()
{
    local core
    local line
    local freq=0
    local accum_freq=0
    local core_count=0
    for ((core=0; 1; core+=2))
    do
        local file="/sys/devices/system/cpu/cpu${core}/cpufreq/scaling_cur_freq"
        if [ ! -f "$file" ]
        then
            break
        fi
        while IFS= read -r line; do
            accum_freq=$((accum_freq+line))
            ((++core_count))
            break
        done < "$file"
    done
    if [ "$core_count" -gt 0 ]
    then
        freq=$((accum_freq/core_count))
    fi
    CPU_FREQ="${freq::-3}"
}

get_gpu_stats()
{
    local nvidia_smi_output=$(nvidia-smi --query-gpu=temperature.gpu,clocks.current.sm --format=csv,noheader,nounits)

    GPU_TEMP="${nvidia_smi_output%%,*}"
    GPU_TEMP="${GPU_TEMP#"${GPU_TEMP%%[![:space:]]*}"}"
    GPU_TEMP="${GPU_TEMP%"${GPU_TEMP##*[![:space:]]}"}"

    GPU_FREQ="${nvidia_smi_output##*,}"
    GPU_FREQ="${GPU_FREQ#"${GPU_FREQ%%[![:space:]]*}"}"
    GPU_FREQ="${GPU_FREQ%"${GPU_FREQ##*[![:space:]]}"}"
}

get_cpu_temp
get_cpu_freq
get_gpu_stats

printf "CPU: ${CPU_TEMP}°, ${CPU_FREQ} MHz\nGPU: ${GPU_TEMP}°, ${GPU_FREQ} MHz\n"
