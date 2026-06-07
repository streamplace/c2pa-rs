# Streamplace patches against upstream

Every modification this fork makes to upstream files (`sdk/`, `cli/`, etc.) is
tracked here. Read this before resolving merge conflicts after `git merge
upstream/main`.

The SDK is published to crates.io as **`s2pa`** (Streamplace owns that name).
Rather than a separate wrapper crate, the `sdk/` package itself is renamed
`c2pa → s2pa`; the rename is confined to manifests, so `sdk/` source and the
in-tree dependents keep merging from upstream cleanly. New S2PA-specific
surface lives in `sdk/src/{did,signing,drisl}.rs`. Patches below are the
modifications to upstream files.

## Package rename `c2pa` → `s2pa` — manifests only

Publishes the patched SDK under a Streamplace-owned crates.io name without
touching upstream source.

- `sdk/Cargo.toml` — `[package].name` and `[lib].name` are `s2pa` (was `c2pa`);
  metadata (description/repo/keywords/authors) updated. **The crate source is
  untouched** — internal references use `crate::`, so upstream `sdk/` merges
  are unaffected.
- Every in-workspace dependent keeps `use c2pa::…` via cargo's dependency
  rename: `c2pa = { package = "s2pa", path = "…/sdk", … }` in
  `cli/`, `c2pa_c_ffi/`, `export_schema/`, `make_test_images/`, and the
  `[workspace.dependencies]` entry. Their source is unchanged.
- New downstream consumers (and `s2patool`) depend on `s2pa` directly and
  write `use s2pa::…`.
- The old placeholder `s2pa/` wrapper crate is removed; its `did`/`signing`/
  `drisl` modules now live in `sdk/src/`.

**Conflict pattern:** the only upstream conflict is the one-line
`[package].name` (and `[lib].name`) in `sdk/Cargo.toml` — keep `s2pa`. If
upstream adds a new crate that depends on the SDK by path, give it the same
`package = "s2pa"` rename. **Caveat:** `sdk/`'s own doctests use
`use c2pa::…`; under the `s2pa` lib name `cargo test --doc -p s2pa` will not
compile them. This does not affect `cargo build`/`cargo publish` or any
downstream consumer — it is a fork-local test-suite gap to sweep later.

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

## CMAF segment (.m4s) support — `sdk/`

Commit: `d192a9d5`

c2pa BMFF v3 spec admits bare CMAF segments (no `ftyp`, no `moov`), but
upstream `bmff_io.rs` rejects them: the format dispatch list excludes
`m4s`, and the JUMBF insertion path hard-requires `/ftyp` to compute the
c2pa-uuid offset. Both are small additive fixes.

- `sdk/src/asset_handlers/bmff_io.rs` — `SUPPORTED_TYPES` gains `m4s` +
  `video/iso.segment`; the two `bmff_map.get("/ftyp").ok_or(...)` sites
  fall back to offset 0 when `/ftyp` is absent (insertion at file head).

**Conflict pattern:** upstream may eventually accept `m4s` natively — if
so, the SUPPORTED_TYPES additions become redundant and can be dropped.
The no-ftyp-fallback patch only conflicts if upstream restructures the
JUMBF insertion path entirely.

## CLI library extraction — `cli/`

Commit: `7c9ed7bb`

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
