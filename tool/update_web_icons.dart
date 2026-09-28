import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/pearlsbyelly_logo.jpg');
  if (!file.existsSync()) {
    print('Error: assets/pearlsbyelly_logo.jpg not found');
    return;
  }

  final bytes = file.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Error: Failed to decode image');
    return;
  }

  final favicon = img.copyResize(image, width: 64, height: 64);
  File('web/favicon.png').writeAsBytesSync(img.encodePng(favicon));

  final icon192 = img.copyResize(image, width: 192, height: 192);
  File('web/icons/Icon-192.png').writeAsBytesSync(img.encodePng(icon192));
  File('web/icons/Icon-maskable-192.png').writeAsBytesSync(img.encodePng(icon192));

  final icon512 = img.copyResize(image, width: 512, height: 512);
  File('web/icons/Icon-512.png').writeAsBytesSync(img.encodePng(icon512));
  File('web/icons/Icon-maskable-512.png').writeAsBytesSync(img.encodePng(icon512));

  print('✓ Web favicon and icons generated successfully!');
}
