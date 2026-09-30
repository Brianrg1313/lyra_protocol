import 'dart:convert';

import 'package:lyra_protocol/lyra_protocol.dart';
import 'package:test/test.dart';

BigInt _int(String hex) => BigInt.parse(hex, radix: 16);

String _hex(List<int> bytes) => Hashes.hex(bytes);

void main() {
  group('SPAKE2, RFC 9382 appendix B', () {
    // The four vectors of P256-SHA256-HKDF-HMAC, empty identities included.
    const vectors = [
      (
        a: "server", b: "client",
        w: "2ee57912099d31560b3a44b1184b9b4866e904c49d12ac5042c97dca461b1a5f",
        x: "43dd0fd7215bdcb482879fca3220c6a968e66d70b1356cac18bb26c84a78d729",
        y: "dcb60106f276b02606d8ef0a328c02e4b629f84f89786af5befb0bc75b6e66be",
        pA: "04a56fa807caaa53a4d28dbb9853b9815c61a411118a6fe516a8798434751470f9010153ac33d0d5f2047ffdb1a3e42c9b4e6be662766e1eeb4116988ede5f912c",
        pB: "0406557e482bd03097ad0cbaa5df82115460d951e3451962f1eaf4367a420676d09857ccbc522686c83d1852abfa8ed6e4a1155cf8f1543ceca528afb591a1e0b7",
        ke: "0e0672dc86f8e45565d338b0540abe69",
        confA: "58ad4aa88e0b60d5061eb6b5dd93e80d9c4f00d127c65b3b35b1b5281fee38f0",
        confB: "d3e2e547f1ae04f2dbdbf0fc4b79f8ecff2dff314b5d32fe9fcef2fb26dc459b",
      ),
      (
        a: "", b: "client",
        w: "0548d8729f730589e579b0475a582c1608138ddf7054b73b5381c7e883e2efae",
        x: "403abbe3b1b4b9ba17e3032849759d723939a27a27b9d921c500edde18ed654b",
        y: "903023b6598908936ea7c929bd761af6039577a9c3f9581064187c3049d87065",
        pA: "04a897b769e681c62ac1c2357319a3d363f610839c4477720d24cbe32f5fd85f44fb92ba966578c1b712be6962498834078262caa5b441ecfa9d4a9485720e918a",
        pB: "04e0f816fd1c35e22065d5556215c097e799390d16661c386e0ecc84593974a61b881a8c82327687d0501862970c64565560cb5671f696048050ca66ca5f8cc7fc",
        ke: "642f05c473c2cd79909f9a841e2f30a7",
        confA: "47d29e6666af1b7dd450d571233085d7a9866e4d49d2645e2df975489521232b",
        confB: "3313c5cefc361d27fb16847a91c2a73b766ffa90a4839122a9b70a2f6bd1d6df",
      ),
      (
        a: "server", b: "",
        w: "626e0cdc7b14c9db3e52a0b1b3a768c98e37852d5db30febe0497b14eae8c254",
        x: "07adb3db6bc623d3399726bfdbfd3d15a58ea776ab8a308b00392621291f9633",
        y: "b6a4fc8dbb629d4ba51d6f91ed1532cf87adec98f25dd153a75accafafedec16",
        pA: "04f88fb71c99bfffaea370966b7eb99cd4be0ff1a7d335caac4211c4afd855e2e15a873b298503ad8ba1d9cbb9a392d2ba309b48bfd7879aefd0f2cea6009763b0",
        pB: "040c269d6be017dccb15182ac6bfcd9e2a14de019dd587eaf4bdfd353f031101e7cca177f8eb362a6e83e7d5e729c0732e1b528879c086f39ba0f31a9661bd34db",
        ke: "005184ff460da2ce59062c87733c299c",
        confA: "bc9f9bbe99f26d0b2260e6456e05a86196a3307ec6663a18bf6ac825736533b2",
        confB: "c2370e1bf813b086dff0d834e74425a06e6390f48f5411900276dcccc5a297ec",
      ),
      (
        a: "", b: "",
        w: "7bf46c454b4c1b25799527d896508afd5fc62ef4ec59db1efb49113063d70cca",
        x: "8cef65df64bb2d0f83540c53632de911b5b24b3eab6cc74a97609fd659e95473",
        y: "d7a66f64074a84652d8d623a92e20c9675c61cb5b4f6a0063e4648a2fdc02d53",
        pA: "04a65b367a3f613cf9f0654b1b28a1e3a8a40387956c8ba6063e8658563890f46ca1ef6a676598889fc28de2950ab8120b79a5ef1ea4c9f44bc98f585634b46d66",
        pB: "04589f13218822710d98d8b2123a079041052d9941b9cf88c6617ddb2fcc0494662eea8ba6b64692dc318250030c6af045cb738bc81ba35b043c3dcb46adf6f58d",
        ke: "fc6374762ba5cf11f4b2caa08b2cd1b9",
        confA: "dfb4db8d48ae5a675963ea5e6c19d98d4ea028d8e898dad96ea19a80ade95dca",
        confB: "d0f0609d1613138d354f7e95f19fb556bf52d751947241e8c7118df5ef0ae175",
      ),
    ];

    for (final v in vectors) {
      test('A="${v.a}", B="${v.b}"', () {
        final a = Spake2.a(_int(v.w), idA: v.a, idB: v.b, x: _int(v.x));
        final b = Spake2.b(_int(v.w), idA: v.a, idB: v.b, y: _int(v.y));

        expect(_hex(a.message), v.pA);
        expect(_hex(b.message), v.pB);

        final keysA = a.finish(b.message);
        final keysB = b.finish(a.message);

        expect(_hex(keysA.sharedKey), v.ke);
        expect(_hex(keysB.sharedKey), v.ke);
        expect(_hex(keysA.confirmA), v.confA);
        expect(_hex(keysA.confirmB), v.confB);
        expect(keysA.checkPeer(keysB.confirmation), isTrue);
        expect(keysB.checkPeer(keysA.confirmation), isTrue);
      });
    }
  });

  group('SPAKE2 in pairing', () {
    test('the same code agrees, a different one does not', () {
      final device = Spake2.a(Spake2.passwordScalar("12345678", instanceId: "i1"), idA: "d", idB: "i1");
      final master = Spake2.b(Spake2.passwordScalar("12345678", instanceId: "i1"), idA: "d", idB: "i1");
      final wrong = Spake2.b(Spake2.passwordScalar("12345679", instanceId: "i1"), idA: "d", idB: "i1");

      final keys = device.finish(master.message);
      expect(master.finish(device.message).checkPeer(keys.confirmation), isTrue);
      expect(wrong.finish(device.message).checkPeer(keys.confirmation), isFalse);

      // The master's id is in w: the same code for another master is another secret.
      final elsewhere = Spake2.b(Spake2.passwordScalar("12345678", instanceId: "i2"), idA: "d", idB: "i1");
      expect(elsewhere.finish(device.message).checkPeer(keys.confirmation), isFalse);
    });

    test('a point off the curve or the identity is refused', () {
      final master = Spake2.b(Spake2.passwordScalar("1", instanceId: "i1"), idA: "d", idB: "i1");
      final offCurve = List<int>.filled(65, 1)..[0] = 4;

      expect(() => master.finish(offCurve), throwsFormatException);
      expect(() => master.finish([0]), throwsFormatException);
    });
  });

  group('P-256 keys', () {
    test('a signature verifies with the SPKI, in DER and raw form, and nothing else does', () {
      final key = EcKeyPair.generate();
      final message = utf8.encode("challenge");
      final signature = key.sign(message);

      expect(P256.verify(key.spki, message, signature), isTrue);
      expect(P256.verify(key.spki, utf8.encode("other"), signature), isFalse);
      expect(P256.verify(EcKeyPair.generate().spki, message, signature), isFalse);

      final reader = DerReader(signature).next(Der.tagSequence).children;
      final raw = [...Der.fixed(reader.integer(), 32), ...Der.fixed(reader.integer(), 32)];
      expect(P256.verify(key.spki, message, raw), isTrue);
      expect(P256.verify(key.spki, message, [1, 2, 3]), isFalse);
    });

    test('the private key round-trips through PEM', () {
      final key = EcKeyPair.generate();
      final again = EcKeyPair.fromPem(key.privateKeyPem);

      expect(again.spki, key.spki);
      expect(key.privateKeyPem, startsWith("-----BEGIN EC PRIVATE KEY-----"));
    });

    test('fingerprints are SHA-256 hex, grouped for people', () {
      expect(Fingerprint.of(utf8.encode("abc")), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
      expect(Fingerprint.display("ba7816bf8f01"), "BA78 16BF 8F01");
    });

    test('HKDF matches RFC 5869 test case 1', () {
      final okm = Hashes.hkdf(
        Hashes.fromHex("0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b"),
        salt: Hashes.fromHex("000102030405060708090a0b0c"),
        info: Hashes.fromHex("f0f1f2f3f4f5f6f7f8f9"),
        length: 42,
      );

      expect(_hex(okm), "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865");
    });
  });
}
