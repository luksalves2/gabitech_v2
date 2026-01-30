import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// KPI Card widget for dashboard - Visual igual ao dashboard antigo
class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final LinearGradient? gradient;
  final VoidCallback? onTap;
  final bool hasOutline;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.gradient,
    this.onTap,
    this.hasOutline = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasGradient = gradient != null;
    final bool isOutlineCard = hasOutline && !hasGradient;
    
    Widget child = GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: hasGradient ? gradient : null,
            color: !hasGradient 
                ? (isOutlineCard ? Colors.transparent : (color?.withValues(alpha: 0.1) ?? AppColors.surface))
                : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: hasGradient ? [
              BoxShadow(
                color: (gradient?.colors.first ?? AppColors.primary).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ] : null,
            border: isOutlineCard 
                ? Border.all(color: color ?? AppColors.border, width: 2)
                : (!hasGradient ? Border.all(color: AppColors.border) : null),
          ),
          child: Stack(
            children: [
              // Ícone decorativo no canto superior direito
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasGradient
                        ? Colors.white.withValues(alpha: 0.15)
                        : (color ?? AppColors.primary).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: hasGradient 
                        ? Colors.white.withValues(alpha: 0.9)
                        : (color ?? AppColors.primary),
                  ),
                ),
              ),
              // Conteúdo
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasGradient
                          ? Colors.white
                          : (isOutlineCard ? color : AppColors.textPrimary),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: hasGradient 
                          ? Colors.white 
                          : (isOutlineCard ? color : AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ),
    );

    return child;
  }
}
