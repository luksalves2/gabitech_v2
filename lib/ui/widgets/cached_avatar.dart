import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Avatar com cache e tratamento de erro para fotos de perfil
/// Evita erros 403 e mostra fallback quando foto não está disponível
class CachedAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData fallbackIcon;

  const CachedAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.fallbackIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    // Se não tem URL, mostra fallback
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback();
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppColors.primary.withValues(alpha: 0.1),
      foregroundColor: foregroundColor ?? AppColors.primary,
      child: ClipOval(
        child: Image.network(
          imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          // Silencia erros de carregamento
          errorBuilder: (context, error, stackTrace) {
            // Não loga o erro - evita poluir o console
            return _buildFallbackContent();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingContent();
          },
          // Adiciona headers para evitar alguns erros de CORS
          headers: const {
            'Accept': 'image/*',
          },
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppColors.primary.withValues(alpha: 0.1),
      foregroundColor: foregroundColor ?? AppColors.primary,
      child: _buildFallbackContent(),
    );
  }

  Widget _buildFallbackContent() {
    // Se tem nome, mostra iniciais
    if (name != null && name!.isNotEmpty) {
      final initials = _getInitials(name!);
      return Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w600,
          color: foregroundColor ?? AppColors.primary,
        ),
      );
    }

    // Senão mostra ícone
    return Icon(
      fallbackIcon,
      size: radius,
      color: foregroundColor ?? AppColors.primary,
    );
  }

  Widget _buildLoadingContent() {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Center(
        child: SizedBox(
          width: radius,
          height: radius,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: foregroundColor ?? AppColors.primary,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}
