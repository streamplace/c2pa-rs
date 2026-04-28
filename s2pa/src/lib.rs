//! s2pa — Simple Standard for Provenance and Authenticity.
//!
//! Streamplace's superset of C2PA with secp256k1 (ES256K) signing and
//! DID-based identity. Re-exports the upstream `c2pa` crate verbatim and
//! layers Streamplace extensions on top.

pub use c2pa::*;

/// DID resolution and DID-document signing identity (did:key, did:plc, did:web).
pub mod did {}

/// ES256K signer constructors that integrate with [`c2pa::Signer`].
pub mod signing {}

/// DRISL-canonical CBOR helpers for DASL-compliant manifests.
///
/// See <https://github.com/n0-computer/dasl>.
pub mod drisl {}
