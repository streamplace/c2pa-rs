# Streamplace patches against upstream

Every modification this fork makes to upstream files (`sdk/`, `cli/`, etc.) is
tracked here. Read this before resolving merge conflicts after `git merge
upstream/main`.

Streamplace follows a wrapper-not-rename strategy: new functionality lives in
`s2pa/` and `s2patool/`. Patches below are the unavoidable exceptions.

## ES256K (secp256k1) signing — `sdk/`

Commit: `19a2c48`

Almost entirely additive: new `SigningAlg::Es256k` variant plus dispatch arms.

- `sdk/Cargo.toml` — `k256` dep
- `sdk/src/crypto/raw_signature/signing_alg.rs` — `Es256k` variant
- `sdk/src/crypto/raw_signature/oids.rs` — secp256k1 OID
- `sdk/src/crypto/raw_signature/openssl/signers/ecdsa_signer.rs` — alg arm
- `sdk/src/crypto/raw_signature/rust_native/signers/ecdsa_signer.rs` — alg arm
- `sdk/src/crypto/raw_signature/{openssl,rust_native}/validators/` — validators
- `sdk/src/crypto/{cose/sign,ec_utils,raw_signature/signer}.rs` — wiring
- `sdk/src/wasm/webcrypto_validator.rs`
- `sdk/tests/fixtures/{certs,crypto/raw_signature}/es256k.*`

**Conflict pattern:** if upstream restructures the alg → fn dispatch tables,
our `Es256k` arms need to be re-added in the new shape.

## CLI library extraction — `cli/`

Commit: `<filled in by next commit>`

Splits `cli/src/main.rs` into a library + thin bin so `s2patool` can call
`c2patool::run()` instead of duplicating ~900 lines of CLI code.

- `cli/src/main.rs` → `cli/src/lib.rs` (only diff: `fn main` → `pub fn run`)
- `cli/src/bin/c2patool.rs` (new) — 3-line stub calling `c2patool::run()`

The bin entry point lives under `src/bin/` rather than `src/main.rs` so
that git sees the change as a clean `main.rs → lib.rs` rename with no
new file shadowing the old path. Without that, rename detection breaks
and every upstream `main.rs` change has to be ported manually.

**Conflict pattern:** git's default 50% rename-similarity threshold keeps
upstream `main.rs` edits flowing into our `lib.rs` on merge. If a large
upstream rewrite drops similarity below 50%, the merge will produce both
`upstream/main.rs` (modified) and our `lib.rs` (modified) — resolve by
porting upstream's changes into `lib.rs` and leaving the bin stub alone.
