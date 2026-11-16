#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# End-to-end demo (`make demo`):
#   1. RTL simulation of id_engine_top streams real model weights through the
#      DMA port (SHA-256 in hardware), extends PCR2, derives the DICE device
#      ID and signs an AIQ2 quote through the SPI secure element (OpenSSL
#      model holding a TEST-ONLY P-256 key).
#   2. A TEST-ONLY demo vendor CA is created at run time and certifies the SE key.
#   3. The Rust verifier appraises the hardware quote (signature, chain,
#      nonce, freshness, tamper, lifecycle, model digest, PCR2).
#   4. `aiid cert create` issues an AI Birth Certificate that embeds the quote
#      and a host attestation (TPM 2.0 via tpm2-tools if available, otherwise
#      a clearly marked software fallback); `aiid cert verify` re-checks
#      everything and re-hashes the weights; a tampered copy must fail.
# Nothing secret is committed: every key here is generated now, in $OUT.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
OUT=${OUT:-$ROOT/demo-out}
CARGO=${CARGO:-cargo}
MODEL=${MODEL:-}
HF_REPO=prajjwal1/bert-tiny
HF_REV=6f75de8b60a9f8a2fdf7b69cbd86d9e64bcb3837
HF_SHA=dab2c2bddcfb48ea430ef63fd76d46d67d704487844d967256a50dd7d7fd0a66

step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
rm -rf "$OUT/ca" "$OUT"/*.json "$OUT"/*.svg "$OUT/tampered"
mkdir -p "$OUT"

if [ -z "$MODEL" ]; then
  MODEL=$OUT/models/bert-tiny
  if ! echo "$HF_SHA  $MODEL/pytorch_model.bin" | sha256sum -c --quiet 2>/dev/null; then
    step "Downloading $HF_REPO@${HF_REV:0:7} (MIT, 17 MB) from Hugging Face"
    mkdir -p "$MODEL"
    for f in pytorch_model.bin config.json vocab.txt; do
      curl -fsSL --retry 3 -o "$MODEL/$f" "https://huggingface.co/$HF_REPO/resolve/$HF_REV/$f"
    done
    echo "$HF_SHA  $MODEL/pytorch_model.bin" | sha256sum -c --quiet
  fi
  WEIGHTS=$MODEL/pytorch_model.bin
  CHECKPOINT="$HF_REPO@$HF_REV"
  NAME=$HF_REPO
  ARCH="BertModel (bert-tiny: 2 layers, hidden 128, 2 heads)"
else
  # a single weight file is streamed through the engine; directories use the first weight file
  if [ -d "$MODEL" ]; then
    WEIGHTS=$(find "$MODEL" -maxdepth 2 -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' -o -name '*.gguf' -o -name '*.onnx' \) | sort | head -1)
  else
    WEIGHTS=$MODEL
  fi
  CHECKPOINT=${CHECKPOINT:-unspecified}
  NAME=${NAME:-}
  ARCH=${ARCH:-}
fi
WSHA=$(sha256sum "$WEIGHTS" | cut -d' ' -f1)
echo "weights: $WEIGHTS"
echo "sha256:  $WSHA"

step "Building RTL simulation (Verilator) and Rust tools"
make -s obj_dir/Vid_engine_top >/dev/null
(cd hwid && $CARGO build -q --release --locked)
(cd verifier && $CARGO build -q --release --locked)
AIID=$ROOT/hwid/target/release/aiid
HWID=$ROOT/hwid/target/release/hwid
VERIFIER=$ROOT/verifier/target/release/ai-id-verifier

step "Generating TEST-ONLY secure-element key"
openssl ecparam -name prime256v1 -genkey -noout -out "$OUT/se_TEST_ONLY.pem" 2>/dev/null
chmod 600 "$OUT/se_TEST_ONLY.pem"
NONCE=$(openssl rand -hex 32)
NOW=$(date +%s)

step "RTL: engine measures the weights over DMA and signs an AIQ2 quote via the SE"
./obj_dir/Vid_engine_top +weights="$WEIGHTS" +se_key="$OUT/se_TEST_ONLY.pem" \
  +nonce="$NONCE" +time="$NOW" +out="$OUT/engine_quote.json" | tee "$OUT/rtl_sim.log" | grep -E '^\[|PASS|FAIL|weights|wrote'

step "Demo vendor CA (TEST-ONLY, generated now) certifies the SE key"
"$AIID" ca init --dir "$OUT/ca" >/dev/null
SEPUB=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['se_pubkey'])" "$OUT/engine_quote.json")
"$AIID" ca issue --dir "$OUT/ca" --pubkey "$SEPUB" --out "$OUT/engine_chain.json"

step "Rust verifier appraises the hardware quote"
python3 - "$OUT" "$WSHA" <<'PY'
import hashlib, json, sys
out, wsha = sys.argv[1], sys.argv[2]
pcr2 = hashlib.sha256(bytes(32) + bytes.fromhex(wsha)).hexdigest()
root = open(f"{out}/ca/ca.pub").read().strip()
json.dump({"trusted_roots": [root], "allowed_models": [wsha], "pcrs": {"2": pcr2},
           "max_skew_secs": 600, "allowed_hw_revs": ["A1"]}, open(f"{out}/hw_policy.json", "w"), indent=2)
PY
"$VERIFIER" verify-hw --quote "$OUT/engine_quote.json" --chain "$OUT/engine_chain.json" \
  --policy "$OUT/hw_policy.json" --nonce "$NONCE"

step "Host identity"
"$HWID" show
"$HWID" challenge

step "aiid cert create (streams SHA-256, records arch/checkpoint/instance/env/HWID/attestation + engine quote)"
CREATE=(cert create --weights "$WEIGHTS" --ca "$OUT/ca" --out "$OUT/birth_certificate.json"
        --checkpoint "$CHECKPOINT" --engine-quote "$OUT/engine_quote.json"
        --engine-chain "$OUT/engine_chain.json" --svg "$OUT/birth_certificate.svg")
[ -n "$ARCH" ] && CREATE+=(--arch "$ARCH")
[ -n "$NAME" ] && CREATE+=(--name "$NAME")
"$AIID" "${CREATE[@]}"

step "aiid cert verify (signature, chain, freshness, re-hash, attestation, engine quote)"
"$AIID" cert verify --cert "$OUT/birth_certificate.json" --ca "$OUT/ca" --weights "$WEIGHTS" \
  --this-machine --svg "$OUT/birth_certificate_verified.svg"

step "Negative test: one flipped byte in the weights must be rejected"
mkdir -p "$OUT/tampered"
cp "$WEIGHTS" "$OUT/tampered/$(basename "$WEIGHTS")"
printf '\xff' | dd of="$OUT/tampered/$(basename "$WEIGHTS")" bs=1 seek=4096 conv=notrunc 2>/dev/null
if "$AIID" cert verify --cert "$OUT/birth_certificate.json" --ca "$OUT/ca" \
     --weights "$OUT/tampered/$(basename "$WEIGHTS")" > "$OUT/tampered/verify.log" 2>&1; then
  echo "ERROR: tampered weights were accepted"; exit 1
fi
grep FAIL "$OUT/tampered/verify.log"
echo "tampered weights rejected as expected"
rm -rf "$OUT/tampered"

step "DEMO PASS"
echo "artifacts in $OUT: engine_quote.json engine_chain.json birth_certificate.json birth_certificate_verified.svg"
