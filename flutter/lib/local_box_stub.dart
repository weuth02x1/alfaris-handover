class LocalBox {
  final Map<String, String> _data = {};

  String? read(String key) => _data[key];

  void write(String key, String value) => _data[key] = value;
}

LocalBox createLocalBox() => LocalBox();
