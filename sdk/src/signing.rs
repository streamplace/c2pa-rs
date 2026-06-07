//! ES256K (secp256k1) signer constructors.
//!
//! The upstream SDK validates ES256K (the [`SigningAlg::Es256k`] variant and
//! its COSE/validator wiring are part of this fork) but does not sign with it
//! directly; S2PA signs via [`CallbackSigner`] with a host-provided secp256k1
//! key. This module will host those signer constructors plus the S2PA leaf
//! certificate generation.
//!
//! [`SigningAlg::Es256k`]: crate::SigningAlg
//! [`CallbackSigner`]: crate::CallbackSigner
//!
//! Placeholder: the implementation currently lives in Streamplace's `muxl`
//! crate and will migrate here.
