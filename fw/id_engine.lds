SECTIONS
{
    .id_engine_text : ALIGN(8) {
        __id_engine_text_start = .;
        *id_engine*.o(.text .text.*)
        __id_engine_text_end = .;
    }
    .id_engine_rodata : ALIGN(8) {
        __id_engine_rodata_start = .;
        *id_engine*.o(.rodata .rodata.*)
        __id_engine_rodata_end = .;
    }
}
INSERT AFTER .text;
