/*
MIT License

Copyright (c) 2024 Arno Richter (https://arnorichter.de)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

function p1363_to_asn1 (p1363) {
	const input = new Uint8Array(p1363);

	let asn1; // ASN.1 contents.
	let len = 0; // Length of ASN.1 contents.
	const componentLength = Math.floor(input.byteLength / 2); // Length of each P1363 component.

	// Separate P1363 signature into its two equally sized components.
	const chunks = [];
	chunks.push([...input.slice(0, componentLength)]);
	chunks.push([...input.slice(componentLength)]);

	const prefix = parseInt('02', 16); // 0x02 prefix before each component.

	for (let i=0; i<chunks.length; i++) {
		// remove leading 0x00 bytes in R and S!
		// https://stackoverflow.com/questions/59904522/asn1-encoding-routines-errors-when-verifying-ecdsa-signature-type-with-openssl#comment105937557_59905274
		while (chunks[i][0] === 0) {
			chunks[i].shift();
		}

		// Add 0x00 because first byte of component > 0x7f.
		// Length of component = (componentLength + 1).
		if (chunks[i][0] > parseInt('7f', 16)) {
			chunks[i].unshift(parseInt('00', 16));
		}
	}

	len = 4 + chunks[0].length + chunks[1].length;
	// 4 is the combined length of 2 prefixes and 2 lengths (?)

	let finalLength;
	if (len > parseInt('7f', 16)) {
		// handle large lengths, like P-521
		// https://security.stackexchange.com/a/164906
		finalLength = [parseInt('81', 16), len];
	} else {
		finalLength = [len];
	}

	asn1 = [
		parseInt('30', 16),
		...finalLength,

		prefix,
		chunks[0].length,
		...chunks[0],

		prefix,
		chunks[1].length,
		...chunks[1]
	];

	return new Uint8Array(asn1).buffer;
}

function asn1_to_p1363 (asn1) {
	// https://stackoverflow.com/a/48727351/3625228
	const input = new Uint8Array(asn1);
	const inputArray = Array.from(input);

	inputArray.shift(1); // remove 0x30 sequence

	let totalLength = inputArray.shift(1);
	if (totalLength == parseInt('81', 16)) {
		// handle large length curves
		totalLength += inputArray.shift(1);
	}

	inputArray.shift(1); // remove 0x02 prefix
	const c1Len = inputArray.shift(1);
	const c1 = inputArray.splice(0, c1Len);

	inputArray.shift(1); // remove 0x02 prefix
	const c2Len = inputArray.shift(1);
	const c2 = inputArray;

	// remove leading 0x00 bytes (??)
	while (c1[0] === 0) {
		c1.shift();
	}
	while (c2[0] === 0) {
		c2.shift();
	}

	return new Uint8Array([...c1, ...c2]).buffer;
}

function readStdinToArrayBuffer() {
  return new Promise((resolve, reject) => {
    const chunks = [];
    
    process.stdin.on('data', (chunk) => {
      chunks.push(chunk);
    });
    
    process.stdin.on('end', () => {
      const buffer = Buffer.concat(chunks);
      resolve(buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength));
    });
    
    process.stdin.on('error', (err) => {
      reject(err);
    });
  });
}



export { p1363_to_asn1, asn1_to_p1363 }

readStdinToArrayBuffer().then(input => {
	const output = asn1_to_p1363(input);
	process.stdout.write(Buffer.from(output));
})