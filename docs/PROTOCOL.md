# Observed USB input protocol

Device: Hanvon ugee Pilot Pro, vendor `0x28bd`, product `0x0203`.

The device exposes vendor-defined (`ff0a/1`), mouse/keyboard (`0001/2`) and digitizer (`000d/2`) HID interfaces. The app monitors only the vendor-defined interface until shortcut output is enabled, when it requires exclusive access to all three interfaces to avoid duplicate native events.

The vendor interface advertises 12-byte input reports and 20-byte output reports. The app decodes only input reports:

| Prefix | Meaning | Observed fields (zero-based byte offsets) |
| --- | --- | --- |
| `02 f3 01` | Joystick | Signed little-endian X/Y at offsets 4–7; observed range −511 to +511 |
| `02 f3 02` | Wheel | Direction code 1 or 2 at offset 3; hardware wheel ID 1, 2 or 4 at offset 4 |
| `02 f3 03` | Buttons | Independent pressed-bit groups at offsets 4–7 |
| `02 f2 01` | Periodic status | Ignored for action generation |

Physical labels are learned from individual gestures rather than assumed from bit ordering. Button edges are deduplicated, simultaneous presses remain independent, and neutral input is required before output is armed after reset. A wheel's direction codes are not interpreted as signed increments.

The official controller has been observed sending separate speed levels to each wheel. Matching the effect of those output commands requires further physical validation. This project does not currently send them or change firmware.
