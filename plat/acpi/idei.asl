(x86)
Device (IDEI)
{
    Name (_HID, "VNC0001")
    Name (_UID, 0)
    Name (_CRS, ResourceTemplate () {
        Memory32Fixed (ReadWrite, 0xFE010000, 0x00001000)
        Interrupt (ResourceConsumer, Level, ActiveLow, Exclusive) { 0x2F }
    })
    Method (_STA, 0) { Return (0x0F) }
    Method (TMPR, 0) { Return (Read (0xFE0100F0)) }
}
