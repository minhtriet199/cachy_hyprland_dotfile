.pragma library
// Tiny 4×4 matrix helpers (row-major, column vectors) — the same maths as CSS 3D transforms.
function mul(A, B) { const R = new Array(16); for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) { let v = 0; for (let k = 0; k < 4; k++) v += A[i * 4 + k] * B[k * 4 + j]; R[i * 4 + j] = v } return R }
function chain() { let m = I(); for (let i = 0; i < arguments.length; i++) m = mul(m, arguments[i]); return m }
function I() { return [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1] }
function T(x, y, z) { return [1,0,0,x, 0,1,0,y, 0,0,1,z || 0, 0,0,0,1] }
function S(s) { return [s,0,0,0, 0,s,0,0, 0,0,s,0, 0,0,0,1] }
function rad(d) { return d * Math.PI / 180 }
function Rx(d) { const c = Math.cos(rad(d)), s = Math.sin(rad(d)); return [1,0,0,0, 0,c,-s,0, 0,s,c,0, 0,0,0,1] }
function Ry(d) { const c = Math.cos(rad(d)), s = Math.sin(rad(d)); return [c,0,s,0, 0,1,0,0, -s,0,c,0, 0,0,0,1] }
function Rz(d) { const c = Math.cos(rad(d)), s = Math.sin(rad(d)); return [c,-s,0,0, s,c,0,0, 0,0,1,0, 0,0,0,1] }
function P(d) { return [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,-1 / d,1] }
function F() { return [1,0,0,0, 0,1,0,0, 0,0,0,0, 0,0,0,1] }   // flatten z (keeps w for perspective)
// CSS "perspective: d; perspective-origin: ox oy" on the parent
function persp(d, ox, oy) { return chain(T(ox, oy), P(d), T(-ox, -oy)) }
function about(ox, oy, m) { return chain(T(ox, oy), m, T(-ox, -oy)) }
function toQt(m) { return Qt.matrix4x4(m[0],m[1],m[2],m[3], m[4],m[5],m[6],m[7], m[8],m[9],m[10],m[11], m[12],m[13],m[14],m[15]) }
function clamp(v) { return Math.max(0, Math.min(1, v)) }
function easeInOut(t) { return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2 }
function easeBack(t, s) { s = s === undefined ? 1.7 : s; const c3 = s + 1; return 1 + c3 * Math.pow(t - 1, 3) + s * Math.pow(t - 1, 2) }
