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
    local siblings=""
    local -i cur_freq=0
    local -i base_freq=0
    local -i accum_freq=0
    local -i core_count=0
    local -i max_core_freq=0
    local -A core_freqs_above_base
    local -A core_freqs_below_base
    local -A base_freqs
    for ((core=0; 1; core+=1))
    do
        local siblings_file="/sys/devices/system/cpu/cpu${core}/topology/thread_siblings"
        local base_freq_file="/sys/devices/system/cpu/cpu${core}/cpufreq/base_frequency"
        local cur_freq_file="/sys/devices/system/cpu/cpu${core}/cpufreq/scaling_cur_freq"

        if [ ! -f "$siblings_file" ] || ! read -r siblings < "$siblings_file" 2>/dev/null
        then
            break
        fi
        if [ ! -f "$base_freq_file" ] || ! read -r base_freq < "$base_freq_file" 2>/dev/null
        then
            break
        fi
        if [ ! -f "$cur_freq_file" ] || ! read -r cur_freq < "$cur_freq_file" 2>/dev/null
        then
            break
        fi

        if [ "$cur_freq" -gt "$base_freq" ]
        then
            if [ -z "${core_freqs_above_base["$siblings"]}" ]
            then
                core_freqs_above_base["$siblings"]="$cur_freq"
            elif [ "$cur_freq" -gt "${core_freqs_above_base["$siblings"]}" ]
            then
                core_freqs_above_base["$siblings"]="$cur_freq"
            fi
        else
            if [ -z "${core_freqs_below_base["$siblings"]}" ]
            then
                core_freqs_below_base["$siblings"]="$cur_freq"
            elif [ "$cur_freq" -gt "${core_freqs_below_base["$siblings"]}" ]
            then
                core_freqs_below_base["$siblings"]="$cur_freq"
            fi
        fi
    done

    # Average frequencies either above or below base frequencies. This allows to display the average frequency
    # of either all cores that are currently under load, if there are ones, or otherwise of all cores that are idle.
    if [ "${#core_freqs_above_base[@]}" -gt 0 ]
    then
        for cur_freq in "${core_freqs_above_base[@]}"
        do
            accum_freq=$((accum_freq+cur_freq))
            ((++core_count))
        done
    else
        for cur_freq in "${core_freqs_below_base[@]}"
        do
            accum_freq=$((accum_freq+cur_freq))
            ((++core_count))
        done
    fi

    if [ "$core_count" -gt 0 ]
    then
        cur_freq=$((accum_freq/core_count))
    fi
    CPU_FREQ="${cur_freq::-3}"
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
