# ai-id-engine
hardware/firmware source tree. It's a reference implementation of a DICE-based AI identity engine (Device Identifier Composition Engine — the industry-standard layered identity primitive, aligned with TCG DICE, IETF RATS/EAT, and SPDM).
Here's the AI identity framework visualized:
The Technical Architecture — Three nested layers with provenance chains binding each layer to the one below. The weight hash at the core is the only truly immutable property; everything else is assigned at deployment time.
The AI Birth Certificate — A conceptual document showing what an official AI identity record would contain. In practice, this would be a signed attestation combining the weight hash, deployment signature, and environment digest.
The key insight your breakdown captures: AI identity is verifiable, not intrinsic. Unlike biological entities with DNA, an AI's "self" is a stack of cryptographic attestations. Two instances are only "the same AI" if they share the full provenance chain from weights through configuration.
The D6 pattern you mentioned — treating runner identity and environment digests as the trust anchor — is the correct approach. The model weights are just the beginning; the running system's identity is the hash of (weights + deployment + configuration + environment).
hardware and software stack for AI identity attestation that can be deployed across existing systems. This requires secure enclaves, cryptographic hardware, and a verification protocol.
<img width="1536" height="864" alt="image" src="https://github.com/user-attachments/assets/1ed44a52-2a26-40f5-acd3-885e29f0dac0" />

visual representation of AI/AGI/LLM identity layers and a conceptual "birth certificate" ID for an AI system.
<img width="1536" height="1152" alt="image" src="https://github.com/user-attachments/assets/38d2c581-a2be-4763-8ca2-e6a9ba3dabaf" />
