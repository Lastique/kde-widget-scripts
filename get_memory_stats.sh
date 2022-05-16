#!/bin/bash

# The amount of memory/swap, in percents, to consider "high usage". High usage will be indicated with red text color.
declare -i HIGH_THRESHOLD=90

declare -i MEM_TOTAL=0
declare -i MEM_FREE=0
declare -i BUFFERS=0
declare -i CACHED=0
declare -i SWAP_TOTAL=0
declare -i SWAP_FREE=0
declare -i SLAB_RECLAIMABLE=0

read_meminfo()
{
    local line
    local -a columns
    while IFS= read -r line
    do
        read -r -a columns <<< "$line"
        case "${columns[0]}" in
            MemTotal:)
                MEM_TOTAL="${columns[1]}"
                ;;
            MemFree:)
                MEM_FREE="${columns[1]}"
                ;;
            Buffers:)
                BUFFERS="${columns[1]}"
                ;;
            Cached:)
                CACHED="${columns[1]}"
                ;;
            SwapTotal:)
                SWAP_TOTAL="${columns[1]}"
                ;;
            SwapFree:)
                SWAP_FREE="${columns[1]}"
                ;;
            SReclaimable:)
                SLAB_RECLAIMABLE="${columns[1]}"
                ;;
        esac
    done < "/proc/meminfo"
}

format_mem_size()
{
    local -i value=$(($1 * 10))
    local unit="KiB"
    if [ "$value" -gt 1024 ]
    then
        value=$((value / 1024))
        unit="MiB"
    fi
    if [ "$value" -gt 1024 ]
    then
        value=$((value / 1024))
        unit="GiB"
    fi
    local -i value_sig=$((value / 10))
    local -i value_frac=$((value % 10))
    FORMATTED_MEM_SIZE="${value_sig}.${value_frac} $unit"
}

read_meminfo

declare -i MEM_USED=$((MEM_TOTAL - MEM_FREE - BUFFERS - CACHED - SLAB_RECLAIMABLE))
declare -i SWAP_USED=$((SWAP_TOTAL - SWAP_FREE))

format_mem_size "$MEM_USED"
MEM_USED_STR="$FORMATTED_MEM_SIZE"

format_mem_size "$SWAP_USED"
SWAP_USED_STR="$FORMATTED_MEM_SIZE"

if [ $((MEM_USED * 100 / MEM_TOTAL)) -gt $HIGH_THRESHOLD ]
then
    MEM_HIGH=1
else
    MEM_HIGH=0
fi

if [ $((SWAP_USED * 100 / SWAP_TOTAL)) -gt $HIGH_THRESHOLD ]
then
    SWAP_HIGH=1
else
    SWAP_HIGH=0
fi

if [ "$MEM_HIGH" -ne 0 ]
then
    printf "\e[0;31m"
fi
printf "RAM: $MEM_USED_STR"
if [ "$MEM_HIGH" -ne 0 ]
then
    printf "\e[0m"
fi

printf "\n"

if [ "$SWAP_HIGH" -ne 0 ]
then
    printf "\e[0;31m"
fi
printf "Swap: $SWAP_USED_STR"
if [ "$SWAP_HIGH" -ne 0 ]
then
    printf "\e[0m"
fi

printf "\n"
