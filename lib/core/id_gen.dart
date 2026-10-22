/// Generator ID acak kripto-aman.
library;

import 'package:hadir/core/crypto.dart';

/// ID unik baru: 16 byte acak dalam hex (32 karakter).
String newId() => randomHex(16);
