import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Color? textColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Widget? icon;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.width,
    this.height,
    this.backgroundColor,
    this.textColor,
    this.borderRadius = 8.0,
    this.padding,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    
    return SizedBox(
      width: width,
      height: height ?? 48,
      child: isOutlined
          ? OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                side: BorderSide(
                  color: backgroundColor ?? theme.primaryColor,
                ),
              ),
              child: _buildButtonContent(theme),
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor ?? theme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 2,
              ),
              child: _buildButtonContent(theme),
            ),
    );
  }

  Widget _buildButtonContent(ThemeData theme) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            isOutlined 
                ? (backgroundColor ?? theme.primaryColor)
                : (textColor ?? Colors.white),
          ),
        ),
      );
    }

    final Color finalTextColor = isOutlined
        ? (textColor ?? backgroundColor ?? theme.primaryColor)
        : (textColor ?? Colors.white);

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon!,
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: finalTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Text(
      text,
      style: TextStyle(
        color: finalTextColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}