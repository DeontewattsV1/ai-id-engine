// SPDX-License-Identifier: MIT
//! Runtime environment record and its digest.
//!
//! digest = SHA-256 of the canonical JSON (sorted keys, no whitespace) of
//! every field except `digest` itself.

use std::collections::BTreeMap;
use std::process::Command;

fn first_line(cmd: &str, args: &[&str]) -> Option<String> {
    let o = Command::new(cmd).args(args).output().ok()?;
    let s = if o.stdout.is_empty() {
        o.stderr
    } else {
        o.stdout
    };
    let l = String::from_utf8_lossy(&s)
        .lines()
        .next()?
        .trim()
        .to_string();
    if l.is_empty() {
        None
    } else {
        Some(l)
    }
}

fn os_name() -> String {
    if let Ok(s) = std::fs::read_to_string("/etc/os-release") {
        if let Some(l) = s.lines().find(|l| l.starts_with("PRETTY_NAME=")) {
            return l[12..].trim_matches('"').to_string();
        }
    }
    std::env::consts::OS.to_string()
}

fn container() -> (bool, String) {
    let markers = [
        std::path::Path::new("/.dockerenv"),
        std::path::Path::new("/run/.containerenv"),
    ];
    if markers.iter().any(|p| p.exists()) {
        return (true, "marker file".into());
    }
    if let Ok(cg) = std::fs::read_to_string("/proc/1/cgroup") {
        for k in ["docker", "kubepods", "containerd", "libpod", "lxc"] {
            if cg.contains(k) {
                return (true, format!("cgroup:{k}"));
            }
        }
    }
    (false, String::new())
}

/// Collects the environment. `container_digest` comes from the CLI or
/// `AIID_CONTAINER_DIGEST` (e.g. an OCI image digest `sha256:...`).
pub fn collect(container_digest: Option<String>) -> BTreeMap<String, serde_json::Value> {
    use serde_json::Value as V;
    let mut m = BTreeMap::new();
    m.insert("os".into(), V::String(os_name()));
    m.insert("arch".into(), V::String(std::env::consts::ARCH.into()));
    if let Ok(k) = std::fs::read_to_string("/proc/sys/kernel/osrelease") {
        m.insert("kernel".into(), V::String(k.trim().into()));
    }
    if let Some(l) = first_line("ldd", &["--version"]) {
        m.insert("libc".into(), V::String(l));
    }
    if let Some(p) = first_line("python3", &["--version"]) {
        m.insert("python".into(), V::String(p));
    }
    let mut libs = BTreeMap::new();
    let probe = "import importlib.metadata as m\nfor p in ['torch','transformers','safetensors','numpy','onnxruntime']:\n  try: print(p, m.version(p))\n  except Exception: pass";
    if let Ok(o) = Command::new("python3").args(["-c", probe]).output() {
        for l in String::from_utf8_lossy(&o.stdout).lines() {
            if let Some((k, v)) = l.split_once(' ') {
                libs.insert(k.to_string(), V::String(v.to_string()));
            }
        }
    }
    m.insert(
        "python_packages".into(),
        V::Object(libs.into_iter().collect()),
    );
    let (inside, how) = container();
    m.insert("in_container".into(), V::Bool(inside));
    if inside {
        m.insert("container_detected_by".into(), V::String(how));
    }
    let cd = container_digest.or_else(|| std::env::var("AIID_CONTAINER_DIGEST").ok());
    m.insert(
        "container_digest".into(),
        cd.map(V::String).unwrap_or(V::Null),
    );
    m.insert(
        "aiid_version".into(),
        V::String(env!("CARGO_PKG_VERSION").into()),
    );
    let d = digest(&m);
    m.insert("digest".into(), V::String(d));
    m
}

/// Canonical digest of an environment record (ignores any `digest` key).
pub fn digest(m: &BTreeMap<String, serde_json::Value>) -> String {
    let mut c = m.clone();
    c.remove("digest");
    let canon = serde_json::to_string(&c).unwrap_or_default();
    format!("sha256:{}", hex::encode(crate::sha256(canon.as_bytes())))
}
