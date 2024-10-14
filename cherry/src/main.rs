use std::{ffi::CString, ptr};

use x11_dl::xlib::{
    self, ClientMessageData, False, SubstructureRedirectMask, XClientMessageEvent, XEvent, Xlib,
    XA_VISUALID,
};

fn main() {
    unsafe {
        send_command();
    }
}

unsafe fn send_command() {
    let xlib = Xlib::open().unwrap();

    let display = (xlib.XOpenDisplay)(ptr::null());

    if display.is_null() {
        panic!("XOpenDisplay failed.");
    }

    let root = (xlib.XDefaultRootWindow)(display);

    let mut msg_data = ClientMessageData::new();
    msg_data.set_long(1, 1);
    msg_data.set_long(2, 1);

    let atom_str = CString::new("FWWM_CLIENT_EVENT").unwrap();

    let atom = (xlib.XInternAtom)(display, atom_str.as_ptr(), xlib::False);

    let msg = XClientMessageEvent {
        type_: 33,
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

    println!("sent a message!");
}
