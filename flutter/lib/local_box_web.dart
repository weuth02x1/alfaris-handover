import "package:web/web.dart";

class LocalBox {
  String? read(String key) => window.localStorage.getItem(key);

  void write(String key, String value) =>
      window.localStorage.setItem(key, value);
}

LocalBox createLocalBox() => LocalBox();
