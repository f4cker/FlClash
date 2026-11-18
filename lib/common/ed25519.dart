import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// RFC 8032 Ed25519 verification (cofactorless, canonical S, no small-order
/// keys). Verification handles public data only, so it need not be constant
/// time.
bool ed25519Verify({
  required List<int> publicKey,
  required List<int> message,
  required List<int> signature,
}) {
  if (publicKey.length != 32 || signature.length != 64) return false;
  final a = _decompress(publicKey);
  final r = _decompress(signature.sublist(0, 32));
  final s = _decode(signature.sublist(32));
  if (a == null || r == null || s >= _q) return false;
  if (_equal(_multiply(BigInt.from(8), a), _identity)) return false;
  final digest = sha512.convert([
    ...signature.sublist(0, 32),
    ...publicKey,
    ...message,
  ]);
  final h = _decode(digest.bytes) % _q;
  return _equal(_multiply(s, _base), _add(r, _multiply(h, a)));
}

typedef _Point = (BigInt, BigInt, BigInt, BigInt);

final _p = (BigInt.one << 255) - BigInt.from(19);
final _q =
    (BigInt.one << 252) +
    BigInt.parse('27742317777372353535851937790883648493');
final _d = (BigInt.from(-121665) * _inverse(BigInt.from(121666))) % _p;
final _sqrtM1 = BigInt.two.modPow((_p - BigInt.one) ~/ BigInt.from(4), _p);
final _identity = (BigInt.zero, BigInt.one, BigInt.one, BigInt.zero);
final _base = () {
  final y = (BigInt.from(4) * _inverse(BigInt.from(5))) % _p;
  final x = _recoverX(y, 0)!;
  return (x, y, BigInt.one, (x * y) % _p);
}();

BigInt _inverse(BigInt value) => value.modPow(_p - BigInt.two, _p);

BigInt _decode(List<int> bytes) {
  var value = BigInt.zero;
  for (var i = bytes.length - 1; i >= 0; i--) {
    value = (value << 8) | BigInt.from(bytes[i]);
  }
  return value;
}

BigInt? _recoverX(BigInt y, int sign) {
  if (y >= _p) return null;
  final x2 = ((y * y - BigInt.one) * _inverse(_d * y * y + BigInt.one)) % _p;
  if (x2 == BigInt.zero) return sign == 0 ? BigInt.zero : null;
  var x = x2.modPow((_p + BigInt.from(3)) ~/ BigInt.from(8), _p);
  if ((x * x - x2) % _p != BigInt.zero) x = (x * _sqrtM1) % _p;
  if ((x * x - x2) % _p != BigInt.zero) return null;
  return x.isOdd != (sign == 1) ? _p - x : x;
}

_Point? _decompress(List<int> bytes) {
  final encoded = Uint8List.fromList(bytes);
  final sign = encoded[31] >> 7;
  encoded[31] &= 0x7f;
  final y = _decode(encoded);
  final x = _recoverX(y, sign);
  if (x == null) return null;
  return (x, y, BigInt.one, (x * y) % _p);
}

_Point _add(_Point a, _Point b) {
  final x = ((a.$2 - a.$1) * (b.$2 - b.$1)) % _p;
  final y = ((a.$2 + a.$1) * (b.$2 + b.$1)) % _p;
  final c = (BigInt.two * a.$4 * b.$4 * _d) % _p;
  final d = (BigInt.two * a.$3 * b.$3) % _p;
  final e = y - x, f = d - c, g = d + c, h = y + x;
  return ((e * f) % _p, (g * h) % _p, (f * g) % _p, (e * h) % _p);
}

_Point _multiply(BigInt scalar, _Point point) {
  var result = _identity;
  var addend = point;
  var rest = scalar;
  while (rest > BigInt.zero) {
    if (rest.isOdd) result = _add(result, addend);
    addend = _add(addend, addend);
    rest >>= 1;
  }
  return result;
}

bool _equal(_Point a, _Point b) {
  return (a.$1 * b.$3 - b.$1 * a.$3) % _p == BigInt.zero &&
      (a.$2 * b.$3 - b.$2 * a.$3) % _p == BigInt.zero;
}
