// SPDX-License-Identifier: MIT
//! SVG rendering of an AI Birth Certificate (certificate-style layout).

use serde_json::Value;

fn esc(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

fn split_hex(s: &str, n: usize) -> Vec<String> {
    s.as_bytes()
        .chunks(n)
        .map(|c| String::from_utf8_lossy(c).to_string())
        .collect()
}

/// Renders the statement of a verified certificate. `status` is printed on
/// the seal (e.g. "VERIFIED" after `aiid cert verify`, else "UNVERIFIED").
pub fn svg(statement: &Value, keyid: &str, status: &str) -> String {
    let p = &statement["predicate"];
    let s = |v: &Value| v.as_str().unwrap_or("—").to_string();
    let model = &p["model"];
    let hw = &p["hardware"];
    let att = &hw["attestation"];
    let wsha = s(&model["weights_sha256"]);
    let env = s(&p["environment"]["digest"]);
    let att_kind = match (
        att["kind"].as_str(),
        att["hardware_backed"].as_bool() == Some(true),
        att["tpm"]["simulated"].as_bool() == Some(true),
    ) {
        (Some("tpm2-quote"), true, _) => "TPM 2.0 quote (hardware-backed)",
        (Some("tpm2-quote"), _, true) => "TPM 2.0 quote (SIMULATED swtpm, not hardware-backed)",
        _ => "software fallback (not hardware-backed)",
    };
    let engine = if p["engine_quote"].is_null() {
        "—".to_string()
    } else {
        format!(
            "AIQ2 rev {} · device {}…",
            s(&p["engine_quote"]["quote"]["hw_rev"]),
            s(&p["engine_quote"]["quote"]["device_id"])
                .get(..16)
                .unwrap_or("")
        )
    };
    let rows: Vec<(&str, Vec<String>)> = vec![
        ("Model", vec![s(&model["name"])]),
        ("Model architecture", vec![s(&model["architecture"])]),
        ("Weight SHA-256 fingerprint", split_hex(&wsha, 32)),
        (
            "Training checkpoint version",
            vec![s(&model["checkpoint_version"])],
        ),
        (
            "Deployment instance ID",
            vec![s(&p["deployment"]["instance_id"])],
        ),
        ("Environment digest", split_hex(&env, 40)),
        ("Hardware ID (salted)", vec![s(&hw["hwid_short"])]),
        ("Host attestation", vec![att_kind.to_string()]),
        ("Identity engine quote", vec![engine]),
    ];
    let mut y = 300;
    let mut body = String::new();
    for (label, lines) in rows {
        body += &format!(
            r##"<text x="110" y="{y}" class="lbl">{}</text>"##,
            esc(label)
        );
        for (i, l) in lines.iter().enumerate() {
            body += &format!(
                r##"<text x="430" y="{}" class="val">{}</text>"##,
                y + i as i32 * 24,
                esc(l)
            );
        }
        y += 24 * lines.len().max(1) as i32 + 22;
    }
    let seal_col = if status == "VERIFIED" {
        "#1f6f43"
    } else {
        "#8a6d1d"
    };
    format!(
        r##"<svg xmlns="http://www.w3.org/2000/svg" width="1100" height="1000" viewBox="0 0 1100 1000">
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fbf7ec"/><stop offset="1" stop-color="#f1e8d2"/></linearGradient>
  <pattern id="guil" width="24" height="24" patternUnits="userSpaceOnUse"><circle cx="12" cy="12" r="9" fill="none" stroke="#c9a94a" stroke-width="0.8" opacity="0.45"/></pattern>
  <style>
    .t{{font-family:Georgia,'Times New Roman',serif;fill:#3b2f12}}
    .lbl{{font-family:Georgia,serif;font-size:19px;fill:#6b5622;font-weight:bold}}
    .val{{font-family:'DejaVu Sans Mono',Menlo,Consolas,monospace;font-size:18px;fill:#1d1d1d}}
    .small{{font-family:Georgia,serif;font-size:14px;fill:#6b5622}}
  </style>
</defs>
<rect width="1100" height="1000" fill="url(#bg)"/>
<rect x="18" y="18" width="1064" height="964" fill="url(#guil)" stroke="#b38f2e" stroke-width="6"/>
<rect x="40" y="40" width="1020" height="920" fill="#fbf7ec" stroke="#b38f2e" stroke-width="2"/>
<rect x="52" y="52" width="996" height="896" fill="none" stroke="#b38f2e" stroke-width="1" stroke-dasharray="6 4"/>
<text x="550" y="130" text-anchor="middle" class="t" font-size="54" font-weight="bold" letter-spacing="3">AI BIRTH CERTIFICATE</text>
<text x="550" y="170" text-anchor="middle" class="t" font-size="20" font-style="italic">This certifies the identity, origin and runtime of the artificial intelligence model described below</text>
<text x="550" y="215" text-anchor="middle" class="val" font-size="20">{cid}</text>
<line x1="110" y1="245" x2="990" y2="245" stroke="#b38f2e" stroke-width="1.5"/>
{body}
<line x1="110" y1="{ly}" x2="990" y2="{ly}" stroke="#b38f2e" stroke-width="1.5"/>
<text x="110" y="{sy}" class="lbl">Issued</text><text x="250" y="{sy}" class="val">{issued}</text>
<text x="110" y="{sy2}" class="lbl">Valid until</text><text x="250" y="{sy2}" class="val">{expires}</text>
<line x1="110" y1="{sigl}" x2="520" y2="{sigl}" stroke="#3b2f12" stroke-width="1"/>
<text x="110" y="{sigt}" class="small">Issuer signature · ECDSA P-256 (DSSE) · key {keyid}</text>
<text x="110" y="{sigt2}" class="small">Issued by {issuer}</text>
<g transform="translate(860,{sealy})">
  <circle r="78" fill="{seal}" opacity="0.92"/>
  <circle r="68" fill="none" stroke="#f6e7b0" stroke-width="2" stroke-dasharray="3 3"/>
  <text y="-18" text-anchor="middle" font-family="Georgia,serif" font-size="15" fill="#f6e7b0" letter-spacing="2">AI-ID ENGINE</text>
  <text y="10" text-anchor="middle" font-family="Georgia,serif" font-size="21" font-weight="bold" fill="#fff">{status}</text>
  <text y="34" text-anchor="middle" font-family="Georgia,serif" font-size="13" fill="#f6e7b0">in-toto · DSSE</text>
</g>
</svg>
"##,
        cid = esc(&s(&p["certificate_id"])),
        body = body,
        ly = y,
        sy = y + 40,
        sy2 = y + 70,
        issued = esc(&s(&p["issued_at"])),
        expires = esc(&s(&p["expires_at"])),
        sigl = y + 120,
        sigt = y + 142,
        sigt2 = y + 164,
        keyid = esc(keyid),
        issuer = esc(&s(&p["issuer"]["name"])),
        sealy = y + 90,
        seal = seal_col,
        status = esc(status),
    )
}
