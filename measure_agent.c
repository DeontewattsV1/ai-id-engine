Two real bugs: the root seed was read from a hardcoded address, and _stext was used for a driver measurement that means nothing. Fixed with a linker section and a driver accessor.
