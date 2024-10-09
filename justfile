_default:
    @just --list

build:
    zig build

# width := "800"
# height := "600"
width := "1280"
height := "720"

dev: (build)
    @startx ./xinitrc -- /usr/bin/Xephyr -ac -screen {{width}}x{{height}} -reset
