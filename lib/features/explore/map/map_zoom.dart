/// Shared by gestures and the explicit +/- controls. Tile detail depends on
/// Google's available cartography, but the application no longer stops at 18.
abstract final class MapZoom {
  static const minimum = 10.8;
  static const maximum = 21.0;
  static num clamp(num zoom) => zoom.clamp(minimum, maximum);
}
