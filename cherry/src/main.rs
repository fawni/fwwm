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

const fn clap_style() -> Styles {
    Styles::styled()
        .header(AnsiColor::Yellow.on_default())
        .usage(AnsiColor::Yellow.on_default())
        .literal(AnsiColor::Green.on_default())
        .placeholder(AnsiColor::Green.on_default())
}

/// A client for communicating with fwwm
#[derive(Parser)]
#[clap(version, author, styles = clap_style())]
struct CherryArgs {
    /// The command to send to fwwm
    #[command(subcommand)]
    command: IPCCommand,

    /// The window to perform the command on
    #[arg(short, long, global = true)]
    window: Option<i64>,
}

#[derive(Subcommand, Clone, Copy)]
enum IPCCommand {
    /// Close the current window
    Close,

    /// Kill the current window, terminating the process
    Kill,

    /// Move the current window to an absolute position
    Move {
        /// The window's starting horizontal position
        x: i64,
        /// The window's starting vertical position
        y: i64,
    },

    /// Resize the current window
    Resize {
        /// The width to resize to
        width: i64,
        /// The height to resize to
        height: i64,
    },

    /// Maximize the current window
    Maximize {
        /// Set a value or leave empty to toggle
        state: Option<bool>,
    },

    /// Make the current window fullscreen, removing any decorations
    Fullscreen {
        /// Set a value or leave empty to toggle
        state: Option<bool>,
    },

    /// Hide the current window
    Hide,

    /// Unhide the current window
    Show,
}

// sadly #[repr(i64)] doesn't work with non-unit enum variants
impl From<IPCCommand> for i64 {
    fn from(cmd: IPCCommand) -> Self {
        match cmd {
            IPCCommand::Close => 0,
            IPCCommand::Kill => 1,
            IPCCommand::Move { .. } => 2,
            IPCCommand::Resize { .. } => 3,
            IPCCommand::Maximize { .. } => 4,
            IPCCommand::Fullscreen { .. } => 5,
            IPCCommand::Hide => 6,
            IPCCommand::Show => 7,
        }
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = CherryArgs::parse();

    unsafe {
        send_command(args.command, args.window)?;
    }

    Ok(())
}

unsafe fn send_command(
    command: IPCCommand,
    window: Option<i64>,
) -> Result<(), Box<dyn std::error::Error>> {
    let xlib = Xlib::open()?;

    let display = (xlib.XOpenDisplay)(ptr::null());
    assert!(!display.is_null(), "XOpenDisplay failed.");

    let root = (xlib.XDefaultRootWindow)(display);

    let mut msg_data = ClientMessageData::new();
    msg_data.set_long(0, command.into());

    match command {
        IPCCommand::Move { x, y } => {
            msg_data.set_long(1, x);
            msg_data.set_long(2, y);
        }
        IPCCommand::Resize { width, height } => {
            msg_data.set_long(1, width);
            msg_data.set_long(2, height);
        }
        IPCCommand::Maximize { state } | IPCCommand::Fullscreen { state } => {
            let value = match state {
                Some(false) => 0,
                Some(true) => 1,
                None => 2,
            };
            msg_data.set_long(1, value);
        }
        _ => (),
    }

    if let Some(window) = window {
        msg_data.set_long(4, window);
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
