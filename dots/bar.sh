#!/bin/sh

function get_date() {
    echo `date +"%A %d %B, %I:%M:%S %p"`
}

function get_tag() {
    total=$(xdotool get_num_desktops)
    current=$(xdotool get_desktop)
    desktops=""

    for i in $(seq 0 $(($total - 1))); do
        if [ $i == $current ]; then
            desktops+=" ■"
        else
            desktops+=" □"
        fi
    done

    echo $desktops
}

while true
do
    printf "%s %s%s\n" \
            "%{l} $(get_tag)" \
            "%{c} $(get_date)" \
            "%{B- F-}" # Cleanup to prevent colors from mixing up
    sleep 0.1
done | \

lemonbar -d \
         -b \
         -f "Iosevka Term" \
         -n lemonbar \
         -B "#15151500" \
         -F "#d8d0d5" \

