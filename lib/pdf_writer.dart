import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart';

/// One page for [PdfWriter]: a JPG picture that fills the whole page.
class WriterPage {
  const WriterPage({
    required this.jpg,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.width,
    required this.height,
  });

  final Uint8List jpg;
  final int pixelWidth;
  final int pixelHeight;

  /// Page size in PDF points (1/72 inch).
  final double width;
  final double height;
}

/// A small PDF writer that can lock the file with a password (AES-128).
///
/// Pages are JPG pictures. Run [build] in a background isolate for big files.
class PdfWriter {
  PdfWriter._();

  static const List<int> _padding = [
    0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41, 0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08, //
    0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80, 0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A,
  ];

  // All permissions allowed (the password only controls opening the file).
  static const List<int> _permissionBytes = [0xFC, 0xFF, 0xFF, 0xFF];
  static const int _permissionValue = -4;

  /// The bytes of [password], or null if it uses characters that PDF readers
  /// may not match. Only plain keyboard characters are allowed.
  static Uint8List? passwordBytes(String password) {
    final units = password.codeUnits;
    if (units.isEmpty || units.length > 32) return null;
    if (units.any((u) => u < 32 || u > 126)) return null;
    return Uint8List.fromList(units);
  }

  static Uint8List _md5(List<int> data) => Uint8List.fromList(crypto.md5.convert(data).bytes);

  static Uint8List _padPassword(List<int> password) {
    final out = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      out[i] = i < password.length ? password[i] : _padding[i - password.length];
    }
    return out;
  }

  static Uint8List _rc4(List<int> key, List<int> data) {
    final s = List<int>.generate(256, (i) => i);
    var j = 0;
    for (var i = 0; i < 256; i++) {
      j = (j + s[i] + key[i % key.length]) & 255;
      final t = s[i];
      s[i] = s[j];
      s[j] = t;
    }
    final out = Uint8List(data.length);
    var a = 0;
    var b = 0;
    for (var k = 0; k < data.length; k++) {
      a = (a + 1) & 255;
      b = (b + s[a]) & 255;
      final t = s[a];
      s[a] = s[b];
      s[b] = t;
      out[k] = data[k] ^ s[(s[a] + s[b]) & 255];
    }
    return out;
  }

  static Uint8List _rc4Rounds(List<int> key, List<int> data) {
    var result = _rc4(key, data);
    for (var i = 1; i < 20; i++) {
      result = _rc4([for (final byte in key) byte ^ i], result);
    }
    return result;
  }

  static Uint8List _aesEncrypt(Uint8List key, Uint8List iv, Uint8List data) {
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()));
    cipher.init(
      true,
      PaddedBlockCipherParameters<CipherParameters?, CipherParameters?>(
        ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
        null,
      ),
    );
    return cipher.process(data);
  }

  static String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Builds the PDF. Pass [password] to lock it.
  static Uint8List build(List<WriterPage> pages, {String? password}) {
    final random = math.Random.secure();
    Uint8List randomBytes(int count) => Uint8List.fromList(List<int>.generate(count, (_) => random.nextInt(256)));

    final docId = randomBytes(16);

    Uint8List? fileKey;
    Uint8List? ownerEntry;
    Uint8List? userEntry;
    if (password != null) {
      final user = passwordBytes(password);
      if (user == null) throw ArgumentError('Unsupported password');

      // Owner entry (algorithm 3); the owner password is the same as the user one.
      var k = _md5(_padPassword(user));
      for (var i = 0; i < 50; i++) {
        k = _md5(k);
      }
      final ownerKey = k.sublist(0, 16);
      ownerEntry = _rc4Rounds(ownerKey, _padPassword(user));

      // File key (algorithm 2).
      var key = _md5([..._padPassword(user), ...ownerEntry, ..._permissionBytes, ...docId]);
      for (var i = 0; i < 50; i++) {
        key = _md5(key.sublist(0, 16));
      }
      fileKey = key.sublist(0, 16);

      // User entry (algorithm 5).
      final u = _rc4Rounds(fileKey, _md5([..._padding, ...docId]));
      userEntry = Uint8List.fromList([...u, ...Uint8List(16)]);
    }

    final out = BytesBuilder();
    final offsets = <int, int>{};

    void addObject(int number, List<int> bytes) {
      offsets[number] = out.length;
      out.add(bytes);
    }

    void addText(int number, String text) => addObject(number, latin1.encode('$number 0 obj\n$text\nendobj\n'));

    void addStream(int number, String dictionary, Uint8List data) {
      var payload = data;
      final key = fileKey;
      if (key != null) {
        final objectKey = _md5([
          ...key,
          number & 255,
          (number >> 8) & 255,
          (number >> 16) & 255,
          0,
          0,
          ...latin1.encode('sAlT'),
        ]).sublist(0, 16);
        final iv = randomBytes(16);
        payload = Uint8List.fromList([...iv, ..._aesEncrypt(objectKey, iv, data)]);
      }
      final builder = BytesBuilder()
        ..add(latin1.encode('$number 0 obj\n<< $dictionary /Length ${payload.length} >>\nstream\n'))
        ..add(payload)
        ..add(latin1.encode('\nendstream\nendobj\n'));
      addObject(number, builder.toBytes());
    }

    out.add(const [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x36, 0x0A, 0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);

    final count = pages.length;
    final kids = [for (var i = 0; i < count; i++) '${3 + 3 * i} 0 R'].join(' ');
    addText(1, '<< /Type /Catalog /Pages 2 0 R >>');
    addText(2, '<< /Type /Pages /Kids [$kids] /Count $count >>');

    for (var i = 0; i < count; i++) {
      final page = pages[i];
      final pageNumber = 3 + 3 * i;
      final contentNumber = pageNumber + 1;
      final imageNumber = pageNumber + 2;
      final w = page.width.toStringAsFixed(2);
      final h = page.height.toStringAsFixed(2);
      addText(
        pageNumber,
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $w $h] '
        '/Resources << /XObject << /Im0 $imageNumber 0 R >> >> /Contents $contentNumber 0 R >>',
      );
      addStream(contentNumber, '', Uint8List.fromList(latin1.encode('q $w 0 0 $h 0 0 cm /Im0 Do Q')));
      addStream(
        imageNumber,
        '/Type /XObject /Subtype /Image /Width ${page.pixelWidth} /Height ${page.pixelHeight} '
        '/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode',
        page.jpg,
      );
    }

    var size = 3 + 3 * count;
    var encryptReference = '';
    if (ownerEntry != null && userEntry != null) {
      final encryptNumber = size;
      addText(
        encryptNumber,
        '<< /Filter /Standard /V 4 /R 4 /Length 128 '
        '/CF << /StdCF << /CFM /AESV2 /AuthEvent /DocOpen /Length 16 >> >> '
        '/StmF /StdCF /StrF /StdCF /O <${_hex(ownerEntry)}> /U <${_hex(userEntry)}> '
        '/P $_permissionValue /EncryptMetadata true >>',
      );
      encryptReference = ' /Encrypt $encryptNumber 0 R';
      size += 1;
    }

    final xrefOffset = out.length;
    final xref = StringBuffer('xref\n0 $size\n0000000000 65535 f \n');
    for (var n = 1; n < size; n++) {
      xref.write('${offsets[n]!.toString().padLeft(10, '0')} 00000 n \n');
    }
    final id = _hex(docId);
    xref.write('trailer\n<< /Size $size /Root 1 0 R$encryptReference /ID [<$id> <$id>] >>\n');
    xref.write('startxref\n$xrefOffset\n%%EOF\n');
    out.add(latin1.encode(xref.toString()));

    return out.toBytes();
  }
}
