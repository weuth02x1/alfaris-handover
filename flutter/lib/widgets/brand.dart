import "package:material_ui/material_ui.dart";

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.height = 40, this.markOnly = false});
  final double height;
  final bool markOnly;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      markOnly ? "assets/brand/alfaris-mark.png" : "assets/brand/alfaris-lockup.png",
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class BrandWatermark extends StatelessWidget {
  const BrandWatermark({super.key, this.size = 280, this.angle = 0});
  final double size;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.14,
      child: Transform.rotate(
        angle: angle,
        child: Image.asset("assets/brand/alfaris-mark.png", width: size, height: size, fit: BoxFit.contain),
      ),
    );
  }
}
