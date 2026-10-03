import 'package:flutter/material.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';

class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.notice,
    this.onTap,
    this.trailing,
    this.unread = false,
  });
  final Notice notice;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(notice.category, categoryColor(notice.category)),
              if (!notice.isPublished) ...[
                const SizedBox(width: 8),
                const StatusChip('Draft', AppColors.amber),
              ],
              if (unread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      color: theme.colorScheme.primary, shape: BoxShape.circle),
                ),
              ],
              const Spacer(),
              Text(Fmt.date(notice.publishedOn),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          Text(notice.title,
              style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
          const SizedBox(height: 4),
          Text(notice.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.onTap, this.trailing});
  final EventItem event;
  final VoidCallback? onTap;
  final Widget? trailing;

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 60,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${event.date.day}',
                    style: TextStyle(
                        color: scheme.onPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                Text(_months[event.date.month - 1],
                    style: TextStyle(color: scheme.onPrimary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('${Fmt.time12(event.startTime)} - ${Fmt.time12(event.endTime)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(event.location,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class TimetableTile extends StatelessWidget {
  const TimetableTile({
    super.key,
    required this.entry,
    this.highlight = false,
    this.trailing,
    this.showClass = false,
    this.onTap,
  });
  final TimetableEntry entry;
  final bool highlight;
  final bool showClass;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // IntrinsicHeight: stretch needs bounded height, but tiles live in lists.
    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 64,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Fmt.time12(entry.start).replaceAll(' ', '\u00A0'),
                    style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: highlight ? scheme.primary : null)),
                Text(Fmt.time12(entry.end).replaceAll(' ', '\u00A0'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        Expanded(
          child: AppCard(
            onTap: onTap,
            color: highlight ? scheme.primaryContainer : null,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(entry.courseName,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                          if (highlight) ...[
                            const SizedBox(width: 8),
                            const StatusChip('Now', AppColors.primary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(entry.facultyName, style: theme.textTheme.bodySmall),
                      Text(
                          showClass
                              ? '${entry.room} \u00B7 ${entry.program} Sem ${entry.semester}'
                              : entry.room,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ],
    ),
    );
  }
}
