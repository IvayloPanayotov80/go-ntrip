const { EventEmitter } = require('events');

// CRC24Q implementation (polynomial 0x1864CFB, init 0)
function crc24q(buffer, start, end) {
	let crc = 0;
	for (let i = start; i < end; i += 1) {
		crc ^= (buffer[i] << 16);
		for (let b = 0; b < 8; b += 1) {
			crc <<= 1;
			if (crc & 0x1000000) {
				crc ^= 0x1864CFB;
			}
		}
		crc &= 0xFFFFFF;
	}
	return crc >>> 0;
}

// Helper to read bits from buffer
class BitReader {
	constructor(buffer) {
		this.buffer = buffer;
		this.bitOffset = 0; // from start of buffer
	}

	readBits(numBits) {
		let value = 0;
		for (let i = 0; i < numBits; i += 1) {
			const byteIndex = (this.bitOffset >> 3);
			const bitIndex = 7 - (this.bitOffset & 7);
			const bit = (this.buffer[byteIndex] >> bitIndex) & 1;
			value = (value << 1) | bit;
			this.bitOffset += 1;
		}
		return value >>> 0;
	}
}

// Basic RTCM3 parser: detects frames, validates CRC24Q, extracts message type and length
class Rtcm3Parser extends EventEmitter {
	constructor() {
		super();
		this.buffer = Buffer.alloc(0);
	}

	write(chunk) {
		if (!chunk || chunk.length === 0) return;
		this.buffer = Buffer.concat([this.buffer, chunk]);
		this._drain();
	}

	_drain() {
		// RTCM3 framing: 0xD3, 10-bit length (bytes after length and before CRC), then payload, then 3-byte CRC
		while (this.buffer.length >= 6) {
			// Find sync byte 0xD3
			const syncIndex = this.buffer.indexOf(0xD3);
			if (syncIndex < 0) {
				// No sync found, drop buffer
				this.buffer = Buffer.alloc(0);
				return;
			}
			if (syncIndex > 0) {
				this.buffer = this.buffer.subarray(syncIndex);
			}
			if (this.buffer.length < 3) return; // need at least header

			// Length is 10 bits: next two bytes lower 10 bits
			const lenHigh = this.buffer[1] & 0x03;
			const lenLow = this.buffer[2];
			const payloadLen = ((lenHigh << 8) | lenLow) >>> 0;
			const fullLen = 3 + payloadLen + 3; // header + payload + crc
			if (this.buffer.length < fullLen) return; // wait more data

			const frame = this.buffer.subarray(0, fullLen);
			const payload = frame.subarray(3, 3 + payloadLen);
			const crcExpected = (frame[fullLen - 3] << 16) | (frame[fullLen - 2] << 8) | frame[fullLen - 1];
			const crcComputed = crc24q(frame, 0, fullLen - 3);

			if ((crcComputed & 0xFFFFFF) !== (crcExpected & 0xFFFFFF)) {
				this.emit('crc_error', { length: payloadLen, crcExpected, crcComputed });
				// Drop sync and continue
				this.buffer = this.buffer.subarray(1);
				continue;
			}

			// Extract message number: first 12 bits of payload
			const reader = new BitReader(payload);
			const messageNumber = reader.readBits(12);

			this.emit('message', {
				messageNumber,
				length: payloadLen,
				crc: crcExpected >>> 0
			});

			// Consume frame
			this.buffer = this.buffer.subarray(fullLen);
		}
	}
}

module.exports = { Rtcm3Parser, crc24q };

