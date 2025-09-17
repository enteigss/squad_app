import 'package:flutter/material.dart';

class AppleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double height;
  final String text;

  const AppleSignInButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.height = 40,
    this.text = 'Sign in with Apple',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 1,
          shadowColor: Colors.black.withOpacity(0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
            side: const BorderSide(color: Colors.black, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: _buildButtonContent(),
      ),
    );
  }

  Widget _buildButtonContent() {
    if (isLoading) {
      return const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAppleIcon(),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Roboto',
          ),
        ),
      ],
    );
  }

  Widget _buildAppleIcon() {
    return Container(
      width: 18,
      height: 18,
      child: CustomPaint(painter: AppleLogoPainter()),
    );
  }
}

class AppleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    final double width = size.width;
    final double height = size.height;

    // Create Apple logo path
    Path applePath = Path();

    // Apple body (rounded rectangle-like shape)
    applePath.moveTo(width * 0.5, height * 0.9);
    applePath.cubicTo(
      width * 0.3,
      height * 0.9,
      width * 0.1,
      height * 0.7,
      width * 0.1,
      height * 0.5,
    );
    applePath.cubicTo(
      width * 0.1,
      height * 0.3,
      width * 0.3,
      height * 0.1,
      width * 0.5,
      height * 0.1,
    );
    applePath.cubicTo(
      width * 0.7,
      height * 0.1,
      width * 0.9,
      height * 0.3,
      width * 0.9,
      height * 0.5,
    );
    applePath.cubicTo(
      width * 0.9,
      height * 0.7,
      width * 0.7,
      height * 0.9,
      width * 0.5,
      height * 0.9,
    );
    applePath.close();

    // Apple bite (right side)
    Path bitePath = Path();
    bitePath.addOval(
      Rect.fromCenter(
        center: Offset(width * 0.75, height * 0.4),
        width: width * 0.25,
        height: height * 0.25,
      ),
    );

    // Subtract bite from apple
    applePath = Path.combine(PathOperation.difference, applePath, bitePath);

    canvas.drawPath(applePath, paint);

    // Apple stem/leaf
    paint.strokeWidth = width * 0.08;
    paint.style = PaintingStyle.stroke;
    paint.strokeCap = StrokeCap.round;

    // Stem
    canvas.drawLine(
      Offset(width * 0.55, height * 0.1),
      Offset(width * 0.6, height * 0.05),
      paint,
    );

    // Small leaf
    paint.strokeWidth = width * 0.05;
    canvas.drawLine(
      Offset(width * 0.58, height * 0.06),
      Offset(width * 0.65, height * 0.03),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
