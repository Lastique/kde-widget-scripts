#!/bin/bash

declare -i CPU_TEMP=0
declare -i CPU_FREQ=0
declare -i GPU_TEMP=0
declare -i GPU_FREQ=0

get_cpu_temp()
{
    local file
    local -i temp
    for file in /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input
    do
        read -r temp < "$file"
        break
    done
    CPU_TEMP="${temp::-3}"
}

get_cpu_freq()
{
    local -i core
    local -i freq0=0
    local -i freq1=0
    local -i accum_freq=0
    local -i core_count=0
    local -i max_core_freq=0
    local -a core_freqs
    for ((core=0; 1; core+=2))
    do
        local file0="/sys/devices/system/cpu/cpu${core}/cpufreq/scaling_cur_freq"
        local file1="/sys/devices/system/cpu/cpu$((core+1))/cpufreq/scaling_cur_freq"
        if [ ! -f "$file0" ] || ! read -r freq0 < "$file0"
        then
            break
        fi
        if [ ! -f "$file1" ] || ! read -r freq1 < "$file1" 2>/dev/null
        then
            break
        fi
        if [ "$freq0" -lt "$freq1" ]
        then
            freq0="$freq1"
        fi
        core_freqs+=("$freq0")
        if [ "$max_core_freq" -lt "$freq0" ]
        then
            max_core_freq="$freq0"
        fi
    done

    # Discard core frequencies that are (nearly) idle. This allows to display the average frequency
    # of the cores that are currently under load, which is more meaningful.
    freq1=$((max_core_freq*3/4))
    for freq0 in "${core_freqs[@]}"
    do
        if [ "$freq0" -ge "$freq1" ]
        then
            accum_freq=$((accum_freq+freq0))
            ((++core_count))
        fi
    done

    if [ "$core_count" -gt 0 ]
    then
        freq0=$((accum_freq/core_count))
    fi
    CPU_FREQ="${freq0::-3}"
}

get_gpu_stats()
{
    local nvidia_smi_output="$(nvidia-smi --query-gpu=temperature.gpu,clocks.current.sm --format=csv,noheader,nounits)"

    GPU_TEMP="${nvidia_smi_output%%,*}"
    GPU_TEMP="${GPU_TEMP#"${GPU_TEMP%%[![:space:]]*}"}"
    GPU_TEMP="${GPU_TEMP%"${GPU_TEMP##*[![:space:]]}"}"

    local freq="${nvidia_smi_output##*,}"
    freq="${freq#"${freq%%[![:space:]]*}"}"
    freq="${freq%"${freq##*[![:space:]]}"}"
    if [[ "$freq" == +([0-9]) ]]
    then
        GPU_FREQ="$freq"
    fi
}

get_cpu_temp
get_cpu_freq
get_gpu_stats

printf "CPU: ${CPU_TEMP}°, ${CPU_FREQ} MHz\nGPU: ${GPU_TEMP}°, ${GPU_FREQ} MHz\n"
