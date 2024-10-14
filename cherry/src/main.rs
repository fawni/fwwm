use std::{ffi::CString, ptr};

use clap::{
    builder::{styling::AnsiColor, Styles},
    Parser, Subcommand,
};
use x11_dl::xlib::{
    self, ClientMessageData, False, SubstructureRedirectMask, XClientMessageEvent, XEvent, Xlib,
    XA_VISUALID,
};

const CLIENT_MESSAGE: i32 = 33;

fn clap_style() -> Styles {
    Styles::styled()
        .header(AnsiColor::Yellow.on_default())
        .usage(AnsiColor::Yellow.on_default())
        .literal(AnsiColor::Green.on_default())
        .placeholder(AnsiColor::Green.on_default())
}

/// Client for controlling fwwm
#[derive(Parser)]
#[clap(version, author, styles = clap_style())]
struct CherryArgs {
    /// Command to run
    #[command(subcommand)]
    command: IPCCommand,
}

#[derive(Subcommand, Clone, Copy)]
enum IPCCommand {
    /// Closes the current window
    Close,

    /// Kills the current window, this terminates the process
    Kill,

    /// Moves the current window to an absolute position
    Move { x: i64, y: i64 },
}

// sadly #[repr(i64)] doesn't work with non-unit enum variants
impl From<IPCCommand> for i64 {
    fn from(cmd: IPCCommand) -> Self {
        match cmd {
            IPCCommand::Close => 0,
            IPCCommand::Kill => 1,
            IPCCommand::Move { .. } => 2,
        }
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    unsafe {
        send_command(CherryArgs::parse().command)?;
    }

    Ok(())
}

unsafe fn send_command(command: IPCCommand) -> Result<(), Box<dyn std::error::Error>> {
    let xlib = Xlib::open()?;

    let display = (xlib.XOpenDisplay)(ptr::null());
    if display.is_null() {
        panic!("XOpenDisplay failed.");
    }

    let root = (xlib.XDefaultRootWindow)(display);

    let mut msg_data = ClientMessageData::new();
    msg_data.set_long(0, command.into());

    if let IPCCommand::Move { x, y } = command {
        msg_data.set_long(1, x);
        msg_data.set_long(2, y);
    }

    let atom_str = CString::new("FWWM_CHERRY_EVENT")?;
    let atom = (xlib.XInternAtom)(display, atom_str.as_ptr(), xlib::False);

    let msg = XClientMessageEvent {
        type_: CLIENT_MESSAGE,
        data: msg_data,
        window: root,
        message_type: atom,
        format: XA_VISUALID as i32,
        display,
        send_event: False,
        serial: 0,
    };

    let mut event: XEvent = XEvent {
        client_message: msg,
    };

    _ = (xlib.XSendEvent)(display, root, False, SubstructureRedirectMask, &mut event);

    (xlib.XSync)(display, False);
    (xlib.XCloseDisplay)(display);

    Ok(())
}
