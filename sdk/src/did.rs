//! DID resolution and DID-document signing identity.
//!
//! S2PA replaces C2PA's certificate-authority trust model with decentralized
//! identifiers (`did:key`, `did:plc`, `did:web`). This module will host the
//! resolver and the glue that lets a DID document stand in for an X.509 chain.
//!
//! Placeholder: the implementation currently lives in Streamplace's `muxl`
//! crate and will migrate here.
