// SPDX-License-Identifier: MIT
//! Tiny argument helpers shared by the `hwid` and `aiid` binaries.

/// Value following `--name`, if present.
pub fn opt(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1).cloned())
}

/// True if the bare flag is present.
pub fn flag(args: &[String], name: &str) -> bool {
    args.iter().any(|a| a == name)
}

/// Required option or a readable error.
pub fn req(args: &[String], name: &str) -> Result<String, String> {
    opt(args, name).ok_or_else(|| format!("missing required option {name}"))
}

/// Reads a file to string with the path in the error.
pub fn read(path: &str) -> Result<String, String> {
    std::fs::read_to_string(path).map_err(|e| format!("{path}: {e}"))
}
