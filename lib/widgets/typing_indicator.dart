import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: const [
          SpinKitThreeBounce(color: Colors.blueAccent, size: 18),
          SizedBox(width: 8),
          Text('Preparando respuesta...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
