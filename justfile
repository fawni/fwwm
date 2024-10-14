_default:
    @just --list

@set-version:
    zvm use 0.13.0

@build: (set-version)
    zig build

release: (set-version)
    zig build --release=safe

width := "1280"
height := "720"

@dev: (build) (cherry)
    startx ./dots/xinitrc -- $(which Xephyr) -ac -screen {{width}}x{{height}} -reset

cherry:
    cargo install --path cherry

install: (release) && (cherry)
    sudo cp ./zig-out/bin/fwwm /usr/bin/fwwm
    sudo cp ./contrib/fwwm.desktop /usr/share/xsessions/fwwm.desktop
