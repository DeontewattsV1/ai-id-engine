// SPDX-License-Identifier: MIT
//! Privacy-preserving machine hardware ID.
//!
//! Components are read from the OS (Linux: /etc/machine-id, /sys/class/dmi,
//! /proc/cpuinfo, /sys/block, /sys/class/net, dmidecode when run as root;
//! Windows: CIM/WMI via PowerShell and the MachineGuid registry value;
//! macOS: ioreg, sysctl, ifconfig). Every value is normalised and hashed with
//! a caller-chosen salt:
//!
//!   comp_hash_i = SHA-256("aiid-hwid-v1" || 0 || salt || 0 || name_i || 0 || value_i)
//!   HWID        = SHA-256("aiid-hwid-v1" || 0 || salt || 0 || sorted(name_i || comp_hash_i))
//!
//! Raw identifiers are never printed or stored unless `reveal` is requested,
//! and different salts (one per product/vendor) give unlinkable IDs for the
//! same machine. This module only *reads* identifiers; it never changes them.

use crate::sha256;
use serde::{Deserialize, Serialize};
use std::process::Command;

pub const DOMAIN: &[u8] = b"aiid-hwid-v1";
pub const DEFAULT_SALT: &str = "ai-id-engine/default";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Component {
    /// Stable component name, e.g. "dmi.product_uuid", "disk.serial[0]".
    pub name: String,
    /// Where the value was read from.
    pub source: String,
    /// Salted SHA-256 of the normalised value (hex).
    pub hash: String,
    /// Raw value, only when explicitly revealed.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub value: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Hwid {
    pub version: u32,
    pub os: String,
    pub salt_id: String,
    /// Full 256-bit HWID (hex).
    pub hwid: String,
    /// Short display form (first 80 bits, Crockford base32 with check).
    pub short: String,
    pub components: Vec<Component>,
}

fn norm(v: &str) -> Option<String> {
    let t = v.trim().trim_matches(char::from(0)).to_ascii_lowercase();
    let junk = [
        "",
        "none",
        "n/a",
        "na",
        "default string",
        "to be filled by o.e.m.",
        "not specified",
        "not applicable",
        "system serial number",
        "0",
        "00000000-0000-0000-0000-000000000000",
        "ffffffff-ffff-ffff-ffff-ffffffffffff",
        "03000200-0400-0500-0006-000700080009",
        "00:00:00:00:00:00",
        "123456789",
        "0123456789",
    ];
    if junk.contains(&t.as_str()) {
        None
    } else {
        Some(t)
    }
}

fn comp_hash(salt: &str, name: &str, value: &str) -> String {
    let mut m = DOMAIN.to_vec();
    m.push(0);
    m.extend_from_slice(salt.as_bytes());
    m.push(0);
    m.extend_from_slice(name.as_bytes());
    m.push(0);
    m.extend_from_slice(value.as_bytes());
    hex::encode(sha256(&m))
}

/// Raw (name, source, value) triples collected from the OS.
pub type RawComponents = Vec<(String, String, String)>;

#[allow(dead_code)]
fn read_trim(path: &str) -> Option<String> {
    std::fs::read_to_string(path).ok().and_then(|s| norm(&s))
}

#[allow(dead_code)]
fn run(cmd: &str, args: &[&str]) -> Option<String> {
    let out = Command::new(cmd).args(args).output().ok()?;
    if !out.status.success() {
        return None;
    }
    Some(String::from_utf8_lossy(&out.stdout).to_string())
}

#[cfg(target_os = "linux")]
fn collect_os() -> RawComponents {
    let mut c: RawComponents = Vec::new();
    fn add(c: &mut RawComponents, n: &str, src: &str, v: Option<String>) {
        if let Some(v) = v {
            c.push((n.to_string(), src.to_string(), v));
        }
    }
    for p in ["/etc/machine-id", "/var/lib/dbus/machine-id"] {
        if let Some(v) = read_trim(p) {
            add(&mut c, "os.machine_id", p, Some(v));
            break;
        }
    }
    for f in [
        "product_uuid",
        "product_serial",
        "board_serial",
        "chassis_serial",
    ] {
        let p = format!("/sys/class/dmi/id/{f}");
        add(&mut c, &format!("dmi.{f}"), &p, read_trim(&p));
    }
    // dmidecode needs root; used only if the sysfs value was not readable
    if !c.iter().any(|x| x.0 == "dmi.product_uuid") {
        add(
            &mut c,
            "dmi.product_uuid",
            "dmidecode -s system-uuid",
            run("dmidecode", &["-s", "system-uuid"]).and_then(|s| norm(&s)),
        );
    }
    let model = ["sys_vendor", "product_name", "board_vendor", "board_name"]
        .iter()
        .filter_map(|f| read_trim(&format!("/sys/class/dmi/id/{f}")))
        .collect::<Vec<_>>()
        .join("|");
    add(
        &mut c,
        "dmi.model",
        "/sys/class/dmi/id/{sys_vendor,product_name,board_*}",
        norm(&model),
    );
    if let Ok(ci) = std::fs::read_to_string("/proc/cpuinfo") {
        let get = |k: &str| {
            ci.lines()
                .find(|l| l.split(':').next().map(|x| x.trim()) == Some(k))
                .and_then(|l| l.split_once(':').map(|x| x.1.trim().to_string()))
        };
        let sig = [
            get("vendor_id"),
            get("cpu family"),
            get("model"),
            get("stepping"),
            get("model name"),
        ]
        .into_iter()
        .flatten()
        .collect::<Vec<_>>()
        .join("|");
        let ncpu = ci.lines().filter(|l| l.starts_with("processor")).count();
        add(
            &mut c,
            "cpu.signature",
            "/proc/cpuinfo",
            norm(&format!("{sig}|{ncpu}")),
        );
    }
    let mut disks: Vec<String> = Vec::new();
    if let Ok(rd) = std::fs::read_dir("/sys/block") {
        let mut names: Vec<String> = rd
            .flatten()
            .map(|e| e.file_name().to_string_lossy().to_string())
            .collect();
        names.sort();
        for n in names {
            if ["loop", "ram", "dm-", "sr", "zram", "md", "nbd"]
                .iter()
                .any(|p| n.starts_with(p))
            {
                continue;
            }
            if read_trim(&format!("/sys/block/{n}/removable")).as_deref() == Some("1") {
                continue;
            }
            let s = read_trim(&format!("/sys/block/{n}/device/serial"))
                .or_else(|| read_trim(&format!("/sys/block/{n}/device/wwid")))
                .or_else(|| read_trim(&format!("/sys/block/{n}/wwid")))
                .or_else(|| read_trim(&format!("/sys/block/{n}/serial")));
            if let Some(s) = s {
                disks.push(s);
            }
        }
    }
    for (i, d) in disks.into_iter().enumerate() {
        add(
            &mut c,
            &format!("disk.serial[{i}]"),
            "/sys/block/*/device/{serial,wwid}",
            Some(d),
        );
    }
    let mut macs: Vec<String> = Vec::new();
    if let Ok(rd) = std::fs::read_dir("/sys/class/net") {
        for e in rd.flatten() {
            let n = e.file_name().to_string_lossy().to_string();
            // physical NICs only: they have a backing device
            if !std::path::Path::new(&format!("/sys/class/net/{n}/device")).exists() {
                continue;
            }
            let mac = read_trim(&format!("/sys/class/net/{n}/address"))
                .or_else(|| read_trim(&format!("/sys/class/net/{n}/bonding_slave/perm_hwaddr")));
            if let Some(m) = mac {
                // skip locally administered (randomised) addresses
                let first = u8::from_str_radix(m.get(0..2).unwrap_or("02"), 16).unwrap_or(2);
                if first & 0x02 == 0 {
                    macs.push(m);
                }
            }
        }
    }
    macs.sort();
    for (i, m) in macs.into_iter().enumerate() {
        add(
            &mut c,
            &format!("net.mac[{i}]"),
            "/sys/class/net/*/address (physical)",
            Some(m),
        );
    }
    c
}

#[cfg(target_os = "windows")]
fn collect_os() -> RawComponents {
    let mut c: RawComponents = Vec::new();
    let ps = |q: &str| {
        run(
            "powershell",
            &["-NoProfile", "-NonInteractive", "-Command", q],
        )
    };
    let mut push_lines = |name: &str, src: &str, out: Option<String>| {
        if let Some(o) = out {
            let mut vals: Vec<String> = o.lines().filter_map(norm).collect();
            vals.sort();
            for (i, v) in vals.into_iter().enumerate() {
                let n = if i == 0 {
                    name.to_string()
                } else {
                    format!("{name}[{i}]")
                };
                c.push((n, src.to_string(), v));
            }
        }
    };
    push_lines(
        "os.machine_guid",
        "HKLM\\SOFTWARE\\Microsoft\\Cryptography MachineGuid",
        ps("(Get-ItemProperty 'HKLM:\\SOFTWARE\\Microsoft\\Cryptography').MachineGuid"),
    );
    push_lines(
        "dmi.product_uuid",
        "Win32_ComputerSystemProduct.UUID",
        ps("(Get-CimInstance Win32_ComputerSystemProduct).UUID"),
    );
    push_lines(
        "dmi.board_serial",
        "Win32_BaseBoard.SerialNumber",
        ps("(Get-CimInstance Win32_BaseBoard).SerialNumber"),
    );
    push_lines(
        "cpu.signature",
        "Win32_Processor.ProcessorId+Name",
        ps("Get-CimInstance Win32_Processor | ForEach-Object { $_.ProcessorId + '|' + $_.Name }"),
    );
    push_lines("disk.serial", "Win32_DiskDrive.SerialNumber",
        ps("(Get-CimInstance Win32_DiskDrive | Where-Object { $_.MediaType -notmatch 'Removable' }).SerialNumber"));
    push_lines(
        "net.mac",
        "Win32_NetworkAdapter (physical)",
        ps("(Get-CimInstance Win32_NetworkAdapter -Filter 'PhysicalAdapter=True').MACAddress"),
    );
    c
}

#[cfg(target_os = "macos")]
fn collect_os() -> RawComponents {
    let mut c: RawComponents = Vec::new();
    if let Some(io) = run("ioreg", &["-rd1", "-c", "IOPlatformExpertDevice"]) {
        for (key, name) in [
            ("IOPlatformUUID", "dmi.product_uuid"),
            ("IOPlatformSerialNumber", "dmi.product_serial"),
        ] {
            if let Some(l) = io.lines().find(|l| l.contains(&format!("\"{key}\""))) {
                if let Some(v) = l
                    .split('=')
                    .nth(1)
                    .map(|v| v.trim().trim_matches('"').to_string())
                {
                    if let Some(v) = norm(&v) {
                        c.push((
                            name.into(),
                            format!("ioreg IOPlatformExpertDevice {key}"),
                            v,
                        ));
                    }
                }
            }
        }
    }
    if let Some(v) = run("sysctl", &["-n", "machdep.cpu.brand_string"]).and_then(|s| norm(&s)) {
        c.push((
            "cpu.signature".into(),
            "sysctl machdep.cpu.brand_string".into(),
            v,
        ));
    }
    if let Some(o) = run("ifconfig", &["en0"]) {
        if let Some(m) = o
            .lines()
            .find(|l| l.trim_start().starts_with("ether"))
            .and_then(|l| l.split_whitespace().nth(1))
        {
            if let Some(v) = norm(m) {
                c.push(("net.mac[0]".into(), "ifconfig en0 ether".into(), v));
            }
        }
    }
    c
}

#[cfg(not(any(target_os = "linux", target_os = "windows", target_os = "macos")))]
fn collect_os() -> RawComponents {
    Vec::new()
}

/// Collects raw components from this machine.
pub fn collect() -> RawComponents {
    collect_os()
}

/// Computes the HWID from raw components (pure; unit-testable).
pub fn compute(raw: &RawComponents, salt: &str, reveal: bool) -> Hwid {
    let mut comps: Vec<Component> = raw
        .iter()
        .map(|(n, s, v)| Component {
            name: n.clone(),
            source: s.clone(),
            hash: comp_hash(salt, n, v),
            value: if reveal { Some(v.clone()) } else { None },
        })
        .collect();
    comps.sort_by(|a, b| a.name.cmp(&b.name));
    comps.dedup_by(|a, b| a.name == b.name);
    let mut m = DOMAIN.to_vec();
    m.push(0);
    m.extend_from_slice(salt.as_bytes());
    m.push(0);
    for c in &comps {
        m.extend_from_slice(c.name.as_bytes());
        m.push(b'=');
        m.extend_from_slice(c.hash.as_bytes());
        m.push(b'\n');
    }
    let id = sha256(&m);
    let salt_id = hex::encode(&sha256(salt.as_bytes())[..8]);
    Hwid {
        version: 1,
        os: std::env::consts::OS.to_string(),
        salt_id,
        hwid: hex::encode(id),
        short: crate::code::encode(&id[..10], 4),
        components: comps,
    }
}

/// HWID of this machine.
pub fn this_machine(salt: &str, reveal: bool) -> Result<Hwid, String> {
    let raw = collect();
    if raw.is_empty() {
        return Err("no hardware identifiers could be read on this system".into());
    }
    Ok(compute(&raw, salt, reveal))
}

/// Fuzzy comparison of two HWID records made with the same salt: returns
/// (matching components, components in the reference). Tolerates hardware
/// changes such as a replaced NIC or disk, like OS activation does.
pub fn similarity(reference: &Hwid, current: &Hwid) -> (usize, usize) {
    let matches = reference
        .components
        .iter()
        .filter(|r| {
            current
                .components
                .iter()
                .any(|c| c.name == r.name && c.hash == r.hash)
        })
        .count();
    (matches, reference.components.len())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn raw() -> RawComponents {
        vec![
            ("os.machine_id".into(), "t".into(), "abc123".into()),
            (
                "dmi.product_uuid".into(),
                "t".into(),
                "4c4c4544-0042-3510-8051-b2c04f4e3732".into(),
            ),
            ("net.mac[0]".into(), "t".into(), "3c:22:fb:01:02:03".into()),
        ]
    }

    #[test]
    fn deterministic_and_order_independent() {
        let a = compute(&raw(), DEFAULT_SALT, false);
        let mut r = raw();
        r.reverse();
        let b = compute(&r, DEFAULT_SALT, false);
        assert_eq!(a.hwid, b.hwid);
        assert!(a.components.iter().all(|c| c.value.is_none()));
    }

    #[test]
    fn salts_give_unlinkable_ids() {
        let a = compute(&raw(), "vendor-a", false);
        let b = compute(&raw(), "vendor-b", false);
        assert_ne!(a.hwid, b.hwid);
        assert!(a
            .components
            .iter()
            .zip(&b.components)
            .all(|(x, y)| x.hash != y.hash));
    }

    #[test]
    fn raw_values_never_leak_in_hash_output() {
        let a = compute(&raw(), DEFAULT_SALT, false);
        let js = serde_json::to_string(&a).unwrap();
        assert!(!js.contains("abc123") && !js.contains("3c:22:fb"));
    }

    #[test]
    fn similarity_tolerates_one_change() {
        let a = compute(&raw(), DEFAULT_SALT, false);
        let mut r = raw();
        r[2].2 = "3c:22:fb:09:09:09".into();
        let b = compute(&r, DEFAULT_SALT, false);
        assert_ne!(a.hwid, b.hwid);
        assert_eq!(similarity(&a, &b), (2, 3));
    }

    #[test]
    fn placeholder_values_are_ignored() {
        assert_eq!(norm("To Be Filled By O.E.M."), None);
        assert_eq!(norm("  ABC \n"), Some("abc".into()));
    }

    #[test]
    fn this_machine_reads_something() {
        // CI runners and developer machines always expose at least one ID
        let h = this_machine(DEFAULT_SALT, false).unwrap();
        assert_eq!(h.hwid.len(), 64);
        assert!(!h.components.is_empty());
    }
}
