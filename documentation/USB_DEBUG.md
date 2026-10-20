# USB serial debugging

On devices with a USB peripheral controller, `Disabled` (or `None`) in USB
Gadget Function provides a CDC ACM serial root shell. It does not start Android
ADB. Connect a data cable to the device's OTG/data port and open the resulting
COM port on Windows or `/dev/ttyACM*` on Linux with a serial terminal. Press
Enter to display the shell prompt. The shell runs as root without a login.

`Network` and `File Transfer` use the existing USB networking and MTP functions;
switching to either stops the serial shell. Returning to `Disabled` restores it.
Host roles reported by USB ID or Type-C, and host roles without external VBUS,
remain available for OTG peripherals. Devices without a peripheral controller
cannot provide USB debugging.

The shared `usbgadget` script manages `rocknix-usb-shell.service` and selects the
actual `ttyGS` port reported by configfs. The service is not independently enabled
at boot. T618 and SDM845 use this service instead of separate USB shell services.
Device quirks can opt out with `DEVICE_USB_CONFIGFS_DEBUG="false"`.

The device kernel must enable `CONFIG_USB_CONFIGFS_ACM`. Kernel configurations
that previously disabled it now enable it; existing T618, SDM845, RK3588 and
AMD64 support is retained. These changes require rebuilding and installing the
image. Cross-device hardware operation has not been verified.
