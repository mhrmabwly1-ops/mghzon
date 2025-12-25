import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    String statusText;

    switch (status) {
      case 'approved':
        backgroundColor = Colors.green;
        statusText = 'معتمدة';
        break;
      case 'cancelled':
        backgroundColor = Colors.red;
        statusText = 'ملغاة';
        break;
      default:
        backgroundColor = Colors.orange;
        statusText = 'مسودة';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}