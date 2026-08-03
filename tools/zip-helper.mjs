// ZIP reading for ZCL_ZIP_JS (@KERNEL bridge) - node:zlib does the inflating.
// Parses the central directory; supports store (0) and deflate (8) entries.
// Hex-string in / hex-string out, because that is how the ABAP runtime
// represents xstring values.

import { inflateRawSync, deflateRawSync } from "node:zlib";

const EOCD = 0x06054b50;
const CDIR = 0x02014b50;

function toBuffer(zipHex) {
  return Buffer.from(zipHex.toLowerCase(), "hex");
}

function findEocd(buf) {
  // EOCD is at least 22 bytes from the end, possibly preceded by a comment
  for (let i = buf.length - 22; i >= 0; i--) {
    if (buf.readUInt32LE(i) === EOCD) return i;
  }
  return -1;
}

export function isZip(zipHex) {
  const buf = toBuffer(zipHex);
  return buf.length > 22 && buf.readUInt16LE(0) === 0x4b50 && findEocd(buf) >= 0;
}

// All entries of the archive for CL_ABAP_ZIP->LOAD: content is returned as
// RAW DEFLATE hex (matching cl_abap_gzip=>compress_binary/decompress_binary,
// which use deflateRawSync/inflateRawSync). Stored entries are re-deflated.
// Returns null when the archive cannot be parsed.
export function listEntries(zipHex) {
  let buf;
  try {
    buf = toBuffer(zipHex);
  } catch {
    return null;
  }
  const eocd = findEocd(buf);
  if (eocd < 0) return null;

  const count = buf.readUInt16LE(eocd + 10);
  let off = buf.readUInt32LE(eocd + 16);
  const entries = [];

  for (let i = 0; i < count; i++) {
    if (buf.readUInt32LE(off) !== CDIR) return null;
    const method = buf.readUInt16LE(off + 10);
    const csize = buf.readUInt32LE(off + 20);
    const usize = buf.readUInt32LE(off + 24);
    const nlen = buf.readUInt16LE(off + 28);
    const elen = buf.readUInt16LE(off + 30);
    const clen = buf.readUInt16LE(off + 32);
    const lho = buf.readUInt32LE(off + 42);
    const fname = buf.toString("utf8", off + 46, off + 46 + nlen);

    const lnlen = buf.readUInt16LE(lho + 26);
    const lelen = buf.readUInt16LE(lho + 28);
    const start = lho + 30 + lnlen + lelen;
    const data = buf.subarray(start, start + csize);
    const deflated = method === 0 ? deflateRawSync(data) : Buffer.from(data);
    const inflated = method === 0 ? Buffer.from(data) : inflateRawSync(data);

    entries.push({
      name: fname,
      size: usize,
      deflateHex: deflated.toString("hex").toUpperCase(),
      // uncompressed too: CL_ABAP_ZIP->SAVE derives CRC + size from CONTENT
      contentHex: inflated.toString("hex").toUpperCase(),
    });
    off += 46 + nlen + elen + clen;
  }
  return entries;
}

export function getFile(zipHex, name) {
  const buf = toBuffer(zipHex);
  const eocd = findEocd(buf);
  if (eocd < 0) return null;

  const count = buf.readUInt16LE(eocd + 10);
  let off = buf.readUInt32LE(eocd + 16);

  for (let i = 0; i < count; i++) {
    if (buf.readUInt32LE(off) !== CDIR) return null;
    const method = buf.readUInt16LE(off + 10);
    const csize = buf.readUInt32LE(off + 20);
    const nlen = buf.readUInt16LE(off + 28);
    const elen = buf.readUInt16LE(off + 30);
    const clen = buf.readUInt16LE(off + 32);
    const lho = buf.readUInt32LE(off + 42);
    const fname = buf.toString("utf8", off + 46, off + 46 + nlen);

    if (fname === name) {
      const lnlen = buf.readUInt16LE(lho + 26);
      const lelen = buf.readUInt16LE(lho + 28);
      const start = lho + 30 + lnlen + lelen;
      const data = buf.subarray(start, start + csize);
      const out = method === 0 ? Buffer.from(data) : inflateRawSync(data);
      return out.toString("hex").toUpperCase();
    }
    off += 46 + nlen + elen + clen;
  }
  return null;
}
