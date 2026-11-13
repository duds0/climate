import 'package:flutter/material.dart';

import '../../domain/models.dart';

Color _parseHex(String hex, Color fallback) {
  final h = hex.replaceFirst('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? fallback : Color(v);
}

/// Faixa "Alerta do INMET". Nunca entra na média; é só informação.
class AlertBanner extends StatelessWidget {
  const AlertBanner(this.alert, {super.key});
  final InmetAlert alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stripe = _parseHex(alert.colorHex, Colors.amber);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: stripe.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetails(context, stripe),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: stripe),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: stripe,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alerta do INMET: ${alert.title}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _subtitle(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    if (alert.severity.isNotEmpty) parts.add(alert.severity);
    if (alert.end != null) {
      final e = alert.end!;
      parts.add(
        'até ${e.day.toString().padLeft(2, '0')}/${e.month.toString().padLeft(2, '0')}',
      );
    }
    return parts.join(' · ');
  }

  void _showDetails(BuildContext context, Color stripe) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: stripe),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(alert.title, style: theme.textTheme.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _subtitle(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (alert.risks.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Riscos', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                for (final r in alert.risks)
                  Text(r, style: theme.textTheme.bodyMedium),
              ],
              if (alert.instructions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Instruções', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                for (final i in alert.instructions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $i', style: theme.textTheme.bodyMedium),
                  ),
              ],
              const SizedBox(height: 16),
              Text(
                'Fonte: INMET. Este aviso não entra no cálculo da previsão.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
