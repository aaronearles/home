// Structured-clone-ish codec for relaying IPC and MessagePort traffic as JSON over a WebSocket.
// Shared verbatim by the server (Electron main, CommonJS) and the browser shim (global).
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.__relayCodec = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  const TYPED = ['Int8Array', 'Uint8Array', 'Uint8ClampedArray', 'Int16Array', 'Uint16Array', 'Int32Array',
    'Uint32Array', 'Float32Array', 'Float64Array', 'BigInt64Array', 'BigUint64Array', 'DataView'];

  const toB64 = typeof Buffer !== 'undefined'
    ? (u8) => Buffer.from(u8.buffer, u8.byteOffset, u8.byteLength).toString('base64')
    : (u8) => {
        let s = '';
        for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000));
        return btoa(s);
      };
  const fromB64 = typeof Buffer !== 'undefined'
    ? (s) => { const b = Buffer.from(s, 'base64'); return new Uint8Array(b.buffer, b.byteOffset, b.byteLength).slice(); }
    : (s) => { const bin = atob(s); const u8 = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u8[i] = bin.charCodeAt(i); return u8; };

  function encode(v) {
    if (v === undefined) return { $t: 'u' };
    if (v === null || typeof v === 'boolean' || typeof v === 'string') return v;
    if (typeof v === 'number') {
      if (Number.isNaN(v)) return { $t: 'n', v: 'NaN' };
      if (!Number.isFinite(v)) return { $t: 'n', v: v > 0 ? 'Infinity' : '-Infinity' };
      if (v === 0 && 1 / v < 0) return { $t: 'n', v: '-0' };
      return v;
    }
    if (typeof v === 'bigint') return { $t: 'b', v: v.toString() };
    if (typeof v === 'function' || typeof v === 'symbol') return { $t: 'u' };
    if (Array.isArray(v)) return v.map(encode);
    if (v instanceof ArrayBuffer) return { $t: 'ab', v: toB64(new Uint8Array(v)) };
    if (ArrayBuffer.isView(v)) {
      const k = v.constructor && v.constructor.name;
      return { $t: 'ta', k: TYPED.includes(k) ? k : 'Uint8Array', v: toB64(new Uint8Array(v.buffer, v.byteOffset, v.byteLength)) };
    }
    if (v instanceof Date) return { $t: 'd', v: v.getTime() };
    if (v instanceof RegExp) return { $t: 'r', s: v.source, f: v.flags };
    if (v instanceof Map) return { $t: 'm', v: [...v].map(([k, x]) => [encode(k), encode(x)]) };
    if (v instanceof Set) return { $t: 's', v: [...v].map(encode) };
    if (v instanceof Error) {
      const extra = {};
      for (const k of Object.keys(v)) extra[k] = encode(v[k]);
      return { $t: 'e', n: v.name, m: v.message, s: v.stack, x: extra };
    }
    const out = {};
    for (const k of Object.keys(v)) out[k] = encode(v[k]);
    return Object.prototype.hasOwnProperty.call(v, '$t') ? { $t: 'o', v: out } : out;
  }

  function decode(v) {
    if (v === null || typeof v !== 'object') return v;
    if (Array.isArray(v)) return v.map(decode);
    switch (v.$t) {
      case undefined: break;
      case 'u': return undefined;
      case 'n': return v.v === '-0' ? -0 : Number(v.v);
      case 'b': return BigInt(v.v);
      case 'ab': return fromB64(v.v).buffer;
      case 'ta': {
        const u8 = fromB64(v.v);
        if (v.k === 'Uint8Array') return u8;
        if (v.k === 'DataView') return new DataView(u8.buffer);
        const C = (typeof globalThis !== 'undefined' ? globalThis : self)[v.k];
        return new C(u8.buffer, 0, u8.byteLength / C.BYTES_PER_ELEMENT);
      }
      case 'd': return new Date(v.v);
      case 'r': return new RegExp(v.s, v.f);
      case 'm': return new Map(v.v.map(([k, x]) => [decode(k), decode(x)]));
      case 's': return new Set(v.v.map(decode));
      case 'e': {
        const C = (typeof globalThis !== 'undefined' ? globalThis : self)[v.n];
        const err = typeof C === 'function' && C.prototype instanceof Error ? new C(v.m) : new Error(v.m);
        err.name = v.n; err.stack = v.s;
        for (const k of Object.keys(v.x || {})) err[k] = decode(v.x[k]);
        return err;
      }
      case 'o': v = v.v; break;
      default: break;
    }
    const out = {};
    for (const k of Object.keys(v)) out[k] = decode(v[k]);
    return out;
  }

  return { encode, decode };
});
