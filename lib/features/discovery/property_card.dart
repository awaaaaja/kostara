import 'package:flutter/material.dart';

import 'models.dart';

/// Kartu hasil properti bersama (list pencarian, home feed, favorit).
class PropertyCard extends StatelessWidget {
  const PropertyCard({super.key, required this.property, this.onTap});

  final PropertySummary property;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final price = property.priceFrom;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 112,
              height: 112,
              child: property.coverUrl == null
                  ? ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: const Icon(Icons.home_outlined),
                    )
                  : Image.network(
                      property.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price == null
                          ? 'Harga menyusul'
                          : 'Rp${price.toString()} / bulan',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: scheme.primary,
                        ),
                        Text(
                          property.ratingCount > 0
                              ? '${property.ratingAvg?.toStringAsFixed(1)} (${property.ratingCount})'
                              : 'Belum ada ulasan',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (property.distanceM != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${property.distanceM} m',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                    if (property.availability != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${property.availability} kamar tersedia',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: scheme.primary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
