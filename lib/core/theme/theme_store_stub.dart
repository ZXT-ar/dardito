class ThemeStore {
  bool read() => false;
  void write(bool dark) {}
  void listen(void Function(bool) changed) {}
  void dispose() {}
}
