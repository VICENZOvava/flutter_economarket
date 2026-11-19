//desenha o logo reutilizável

import 'package:flutter/material.dart';
import '../style/colors.dart';

class EcoMarketLogo extends StatelessWidget {
  final double iconSize;
  final double textSize;

  const EcoMarketLogo({
    super.key,
    this.iconSize = 44,
    this.textSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconSize > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(iconSize * .24),
            child: Image.asset(
              'assets/Ícone do app (1024 px)@1x.png',
              width: iconSize,
              height: iconSize,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
        ],
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: textSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
            ),
            children: const [
              TextSpan(
                text: 'Econo',
                style: TextStyle(color: AppColors.green),
              ),
              TextSpan(
                text: 'Market',
                style: TextStyle(color: AppColors.text),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
