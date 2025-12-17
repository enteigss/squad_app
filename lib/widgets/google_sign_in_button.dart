import 'package:flutter/material.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double height;
  final String text;

  const GoogleSignInButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.height = 40,
    this.text = 'Sign in with Google',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF3c4043),
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
            side: const BorderSide(
              color: Color(0xFFdadce0),
              width: 1,
            ),
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
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3c4043)),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildGoogleIcon(),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF3c4043),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Roboto',
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 18,
      height: 18,
      child: CustomPaint(
        painter: GoogleLogoPainter(),
      ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    
    // Google "G" logo colors
    const Color googleBlue = Color(0xFF4285f4);
    const Color googleGreen = Color(0xFF34a853);
    const Color googleYellow = Color(0xFFfbbc04);
    const Color googleRed = Color(0xFFea4335);
    
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double outerRadius = size.width / 2;
    final double innerRadius = outerRadius * 0.6;
    final double strokeWidth = outerRadius - innerRadius;
    
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = strokeWidth;
    paint.strokeCap = StrokeCap.round;
    
    final Rect circleRect = Rect.fromCircle(center: Offset(centerX, centerY), radius: outerRadius - strokeWidth / 2);
    
    // Blue arc (top right) - from -90 degrees to -30 degrees (gap from -30 to 30)
    paint.color = googleBlue;
    canvas.drawArc(
      circleRect,
      -1.57, // -90 degrees
      1.05, // 60 degrees (stops at -30 degrees, gap from -30 to 30)
      false,
      paint,
    );
    
    // Blue arc continuation (after gap) - from 30 degrees to 90 degrees  
    canvas.drawArc(
      circleRect,
      0.52, // 30 degrees
      1.05, // 60 degrees (from 30 to 90 degrees)
      false,
      paint,
    );
    
    // Green arc (bottom right) - from 90 degrees to 150 degrees
    paint.color = googleGreen;
    canvas.drawArc(
      circleRect,
      1.57, // 90 degrees
      1.05, // 60 degrees
      false,
      paint,
    );
    
    // Yellow arc (bottom left) - from 150 degrees to 210 degrees
    paint.color = googleYellow;
    canvas.drawArc(
      circleRect,
      2.62, // 150 degrees
      1.05, // 60 degrees
      false,
      paint,
    );
    
    // Red arc (top left) - from 210 degrees to 330 degrees
    paint.color = googleRed;
    canvas.drawArc(
      circleRect,
      3.67, // 210 degrees
      2.09, // 120 degrees
      false,
      paint,
    );
    
    // Draw the horizontal line extending from the right side into the center
    paint.color = googleBlue;
    paint.style = PaintingStyle.fill;
    paint.strokeCap = StrokeCap.square;
    
    final double lineY = centerY;
    final double lineStartX = centerX + innerRadius * 0.3;
    final double lineEndX = centerX + outerRadius - 1;
    final double lineThickness = strokeWidth * 0.8;
    
    canvas.drawRect(
      Rect.fromLTWH(
        lineStartX,
        lineY - lineThickness / 2,
        lineEndX - lineStartX,
        lineThickness,
      ),
      paint,
    );
    
    // Draw the vertical part of the "G" opening
    canvas.drawRect(
      Rect.fromLTWH(
        lineEndX - lineThickness,
        lineY - lineThickness / 2,
        lineThickness,
        lineThickness * 1.5,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}