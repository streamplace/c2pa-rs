#!/bin/bash

set -euo pipefail
set -x

# generates all of the test certs used everywhere
# usage: generate.sh

# Get the directory where the script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SDK_FIXTURES="$DIR/sdk/tests/fixtures/certs"
CRYPTO_FIXTURES="$DIR/internal/crypto/src/tests/fixtures/raw_signature"

function ecparam() {
  tmp=$(mktemp)-$1
  openssl ecparam -name $1 > $tmp-$1
  echo "ec:$tmp-$1"
}

function generate() {
  NAME="$1"
  ALGORITHM="$2"
  REQ_PARAMS="$3"
  X509_PARAMS="$4"
  echo "ALGORITHM=$ALGORITHM name=$NAME"
  temp="$(mktemp -d)"
  cd $temp

  openssl req \
    -new \
    -x509 \
    -nodes \
    -newkey $ALGORITHM \
    -extensions usr_cert \
    -extensions v3_req \
    -addext "subjectKeyIdentifier = hash" \
    -addext "authorityKeyIdentifier = keyid:always" \
    -addext basicConstraints=critical,CA:TRUE \
    -addext "keyUsage = critical,cRLSign,digitalSignature,keyCertSign" \
    -keyout root.pem \
    -out root.pub \
    $REQ_PARAMS \
    -days 3650 \
    -subj "/C=US/ST=CA/L=Somewhere/O=C2PA Test Root CA/OU=FOR TESTING_ONLY/CN=Root CA"

  openssl x509 -inform pem -in root.pub -pubkey -noout > ${NAME}_root.pub_key

  openssl req \
    -new \
    -nodes \
    -newkey $ALGORITHM \
    -keyout intermediate.pem \
    -out intermediate.csr \
    -extensions usr_cert \
    -extensions v3_req \
    -addext basicConstraints=critical,CA:TRUE \
    -addext "keyUsage = critical,cRLSign,digitalSignature,keyCertSign" \
    $REQ_PARAMS \
    -days 3650 \
    -subj '/C=US/ST=CA/L=Somewhere/O=C2PA Test Intermediate Root CA/OU=FOR TESTING_ONLY/CN=Intermediate CA'

  openssl x509 \
    -req \
    -in intermediate.csr \
    -CA root.pub \
    -CAkey root.pem \
    -copy_extensions=copyall \
    -CAcreateserial \
    -days 3650 \
    $X509_PARAMS \
    -out intermediate.crt

  openssl req \
    -new \
    -nodes \
    -newkey $ALGORITHM \
    -keyout $NAME.pem \
    -out leaf.csr \
    -extensions usr_cert \
    -extensions v3_req \
    -addext basicConstraints=critical,CA:FALSE \
    -addext "extendedKeyUsage = critical,emailProtection" \
    -addext "keyUsage = critical,digitalSignature,nonRepudiation" \
    $REQ_PARAMS \
    -days 3650 \
    -subj '/C=US/ST=CA/L=Somewhere/O=C2PA Test Signing Cert/OU=FOR TESTING_ONLY/CN=C2PA Signer'

  openssl x509 \
    -req \
    -in leaf.csr \
    -CA intermediate.crt \
    -CAkey intermediate.pem \
    -copy_extensions=copyall \
    -CAcreateserial \
    -days 3650 \
    $X509_PARAMS \
    -out leaf.crt

  openssl x509 -in leaf.crt -out leaf.der -outform DER

  openssl verify -CAfile root.pub -untrusted intermediate.crt leaf.crt

  cd -
  cat "$temp/leaf.crt" "$temp/intermediate.crt" > "$SDK_FIXTURES/$NAME.pub"
  cp "$temp/${NAME}_root.pub_key" "$SDK_FIXTURES"
  cp "$temp/$NAME.pem" "$SDK_FIXTURES"
  openssl sha256 -binary "$temp/leaf.der" | openssl base64 >> "$SDK_FIXTURES/trust/allowed_list.hash"
  cat "$temp/leaf.crt" >> "$SDK_FIXTURES/trust/allowed_list.pem"
  echo "" >> "$SDK_FIXTURES/trust/test_cert_root_bundle.pem"
  cat "$temp/root.pub" >> "$SDK_FIXTURES/trust/test_cert_root_bundle.pem"

  cp "$temp/$NAME.pem" "$CRYPTO_FIXTURES/$NAME.priv"
  cat "$temp/leaf.crt" "$temp/intermediate.crt" > "$CRYPTO_FIXTURES/$NAME.pub"
  openssl x509 -pubkey -noout -in "$CRYPTO_FIXTURES/$NAME.pub" | sed 's/^\-.*//g' | base64 --decode > "$CRYPTO_FIXTURES/$NAME.pub_key"
  echo -en "some sample content to sign" | openssl dgst $X509_PARAMS -sign "$CRYPTO_FIXTURES/$NAME.priv" | node "$DIR/fix-sig.mjs" > "$CRYPTO_FIXTURES/$NAME.raw_sig"
  echo "" >> "$CRYPTO_FIXTURES/test_cert_root_bundle.pem"
  cat "$temp/root.pub" >> "$CRYPTO_FIXTURES/test_cert_root_bundle.pem"
  openssl sha256 -binary "$temp/leaf.der" | openssl base64 >> "$SDK_FIXTURES/trust/allowed_list.hash"

  rm -rf $temp
}

# clear out all the old cert trust
echo "" > "$SDK_FIXTURES/trust/allowed_list.hash"
echo "" > "$SDK_FIXTURES/trust/allowed_list.pem"
echo "" > "$SDK_FIXTURES/trust/test_cert_root_bundle.pem"

echo "" > "$CRYPTO_FIXTURES/allowed_list.hash"
echo "" > "$CRYPTO_FIXTURES/test_cert_root_bundle.pem"

generate es256 $(ecparam prime256v1) "-sha256" "-sha256"
generate es256k $(ecparam secp256k1) "-sha256" "-sha256"
# generate es384 $(ecparam secp384r1) "-sha384" "-sha384"
# generate es512 $(ecparam secp521r1) "-sha512" "-sha512"
# generate ed25519 ed25519 "-sha256" "-sha256"
# generate ps256 rsa-pss "-pkeyopt rsa_pss_keygen_saltlen:32 -pkeyopt rsa_keygen_bits:4096 -pkeyopt rsa_pss_keygen_md:sha256 -pkeyopt rsa_pss_keygen_mgf1_md:sha256" "-sha256"
# generate ps384 rsa-pss "-pkeyopt rsa_pss_keygen_saltlen:32 -pkeyopt rsa_keygen_bits:4096 -pkeyopt rsa_pss_keygen_md:sha384 -pkeyopt rsa_pss_keygen_mgf1_md:sha384" "-sha384"
# generate ps512 rsa-pss "-pkeyopt rsa_pss_keygen_saltlen:32 -pkeyopt rsa_keygen_bits:4096 -pkeyopt rsa_pss_keygen_md:sha512 -pkeyopt rsa_pss_keygen_mgf1_md:sha512" "-sha512"
# generate rs256 rsa:4096 "-sha256" "-sha256"
