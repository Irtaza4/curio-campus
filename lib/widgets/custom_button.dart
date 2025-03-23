import 'package:flutter/material.dart';
import 'package:curio_campus/utils/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 50,
    this.borderRadius = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined
              ? Colors.transparent
              : backgroundColor ?? AppTheme.primaryColor,
          foregroundColor: isOutlined
              ? textColor ?? AppTheme.primaryColor
              : textColor ?? Colors.white,
          elevation: isOutlined ? 0 : 2,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: isOutlined
                ? BorderSide(color: backgroundColor ?? AppTheme.primaryColor)
                : BorderSide.none,
          ),
          disabledBackgroundColor: isOutlined
              ? Colors.transparent
              : AppTheme.primaryColor.withOpacity(0.7),
          disabledForegroundColor: isOutlined
              ? AppTheme.primaryColor.withOpacity(0.7)
              : Colors.white.withOpacity(0.7),
        ),
        child: isLoading
            ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              isOutlined ? AppTheme.primaryColor : Colors.white,
            ),
          ),
        )
            : Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isOutlined
                ? textColor ?? AppTheme.primaryColor
                : textColor ?? Colors.white,
          ),
        ),
      ),
    );
  }
}

