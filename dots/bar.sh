#!/bin/sh

function get_date() {
    echo `date +"%A %d %B, %I:%M:%S %p"`
}

function get_tag() {
    total=$(xdotool get_num_desktops)
    current=$(xdotool get_desktop)
    desktops=""
    previous=$(($current - 1))
    next=$(($current + 1))

    if [ $previous -lt 0 ]; then
        previous=$(($total - 1))
    fi

    if [ $next -gt $(($total - 1)) ]; then
        next=0
    fi


    for i in $(seq 0 $(($total - 1))); do
        if [ $i == $current ]; then
            desktops+="%{A:cherry switch-workspace $i:} ■%{A}"
        else
            desktops+="%{A:cherry switch-workspace $i:} □%{A}"
        fi
    done

    echo "%{A4:cherry switch-workspace $previous:}%{A5:cherry switch-workspace $next:}$desktops%{A}%{A}"
}

while true
do
    printf "%s %s%s\n" \
            "%{Sf}%{l}$(get_tag)" \
            "%{c} $(get_date)" \
            "%{B- F-}"
done | \

lemonbar -b \
         -f "Iosevka Term" \
         -a 12 \
         -n lemonbar \
         -B "#15151500" \
         -F "#d8d0d5" | sh
