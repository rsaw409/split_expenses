import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../components/async_state.dart';
import '../models/expense/expense.dart';
import '../models/user_balance.dart';
import '../notify_controllers/allexpense_controller.dart';
import '../notify_controllers/userbalances_controller.dart';
import '../theme/app_theme.dart';
import '../utils/group_currency.dart';
import '../utils/expenditure.dart';

enum _Period { allTime, thisMonth, lastMonth, last30Days, custom }

/// How much the group spent and what each member's share of it was, over a
/// chosen period. Computed from the cached expense list, so it works offline.
class TotalExpenditureView extends StatefulWidget {
  const TotalExpenditureView({super.key});

  @override
  State<TotalExpenditureView> createState() => _TotalExpenditureViewState();
}

class _TotalExpenditureViewState extends State<TotalExpenditureView> {
  _Period _period = _Period.allTime;
  DateTimeRange? _customRange;

  DateTimeRange? _rangeFor(_Period period, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      _Period.allTime => null,
      _Period.thisMonth =>
        DateTimeRange(start: DateTime(now.year, now.month), end: today),
      _Period.lastMonth => DateTimeRange(
          start: DateTime(now.year, now.month - 1),
          // Day 0 of this month is the last day of the previous one.
          end: DateTime(now.year, now.month, 0),
        ),
      _Period.last30Days => DateTimeRange(
          start: today.subtract(const Duration(days: 29)), end: today),
      _Period.custom => _customRange,
    };
  }

  Future<void> _pickCustomRange(List<Expense> expenses) async {
    final now = DateTime.now();
    final earliest = expenses.isEmpty
        ? DateTime(now.year - 1)
        : expenses
            .map((e) => e.transactionDate.toLocal())
            .reduce((a, b) => a.isBefore(b) ? a : b);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(earliest.year, earliest.month, earliest.day),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _customRange,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = picked;
      _period = _Period.custom;
    });
  }

  String _periodLabel(_Period period) => switch (period) {
        _Period.allTime => 'All time',
        _Period.thisMonth => 'This month',
        _Period.lastMonth => 'Last month',
        _Period.last30Days => 'Last 30 days',
        _Period.custom => _customRange == null
            ? 'Custom…'
            : _formatRange(_customRange!),
      };

  static String _formatRange(DateTimeRange range) {
    final format = DateFormat('d MMM');
    final sameYear = range.start.year == range.end.year;
    final end = DateFormat(sameYear ? 'd MMM' : 'd MMM y').format(range.end);
    return '${format.format(range.start)} – $end';
  }

  @override
  Widget build(BuildContext context) {
    final expenseController = context.watch<AllExpenseController>();
    final balances = context.watch<UserBalanceController>().userBalances;

    return Scaffold(
      appBar: AppBar(title: const Text('Total expenditure')),
      body: _buildBody(expenseController, balances),
    );
  }

  Widget _buildBody(
    AllExpenseController controller,
    List<UserBalance> balances,
  ) {
    if (controller.isLoading) return const LoadingView();
    if (controller.isError) {
      return ErrorView(
        message: controller.errorMessage ?? 'Something went wrong.',
        onRetry: controller.refresh,
      );
    }

    final expenses = controller.expenses;
    final expenditure = computeExpenditure(
      expenses,
      range: _rangeFor(_period, DateTime.now()),
    );
    final members = _membersOf(balances, expenses);

    final colors = _sliceColors(
      Theme.of(context),
      members.keys.toList()
        ..sort((a, b) => expenditure.shareOf(b).compareTo(expenditure.shareOf(a))),
    );

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          _FilterBar(
            periods: [
              for (final p in _Period.values)
                (label: _periodLabel(p), selected: p == _period, period: p),
            ],
            onPeriod: (p) {
              if (p == _Period.custom) {
                _pickCustomRange(expenses);
              } else {
                setState(() => _period = p);
              }
            },
          ),
          if (expenditure.total == 0)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xl),
              child: EmptyStateView(
                icon: Icons.pie_chart_outline_rounded,
                title: 'No expenses in this period',
                subtitle: 'Try a longer time range.',
              ),
            )
          else
            _Breakdown(
              expenditure: expenditure,
              members: members,
              colors: colors,
            ),
        ],
      ),
    );
  }

  /// Every member by id, from the balances (which include members with no
  /// transactions) plus anyone named only in an expense.
  Map<int, String> _membersOf(
    List<UserBalance> balances,
    List<Expense> expenses,
  ) {
    final members = {for (final b in balances) b.userId: b.name};
    for (final e in expenses) {
      members.putIfAbsent(e.userId, () => e.userName);
      for (final d in e.distributions) {
        if (d.userId != null && d.userName != null) {
          members.putIfAbsent(d.userId!, () => d.userName!);
        }
      }
    }
    return members;
  }

  /// Well-spread hues (golden angle) toned for the current brightness, so
  /// neighbouring slices stay distinct however many members there are.
  Map<int, Color> _sliceColors(ThemeData theme, List<int> orderedIds) {
    final dark = theme.brightness == Brightness.dark;
    final base = HSLColor.fromColor(theme.colorScheme.primary).hue;
    return {
      for (var i = 0; i < orderedIds.length; i++)
        orderedIds[i]: HSLColor.fromAHSL(
          1,
          (base + i * 137.508) % 360,
          dark ? 0.55 : 0.5,
          dark ? 0.68 : 0.5,
        ).toColor(),
    };
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.periods, required this.onPeriod});

  final List<({String label, bool selected, _Period period})> periods;
  final ValueChanged<_Period> onPeriod;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          for (final p in periods)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(p.label),
                avatar: p.period == _Period.custom
                    ? const Icon(Icons.date_range_outlined, size: 18)
                    : null,
                selected: p.selected,
                onSelected: (_) => onPeriod(p.period),
              ),
            ),
        ],
      ),
    );
  }
}

class _Breakdown extends StatefulWidget {
  const _Breakdown({
    required this.expenditure,
    required this.members,
    required this.colors,
  });

  final Expenditure expenditure;
  final Map<int, String> members;
  final Map<int, Color> colors;

  @override
  State<_Breakdown> createState() => _BreakdownState();
}

class _BreakdownState extends State<_Breakdown> {
  /// The member whose slice is highlighted, from tapping the chart or the
  /// list. Tapping it again, or the hole in the middle, clears it.
  int? _highlighted;

  void _toggle(int? id) =>
      setState(() => _highlighted = id == _highlighted ? null : id);

  @override
  Widget build(BuildContext context) {
    final expenditure = widget.expenditure;
    final members = widget.members;
    final colors = widget.colors;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ranked = members.keys
        .where((id) => expenditure.shareOf(id) > 0)
        .toList()
      ..sort((a, b) => expenditure.shareOf(b).compareTo(expenditure.shareOf(a)));

    // A new time range can leave the highlighted member with no slice.
    final highlighted = ranked.contains(_highlighted) ? _highlighted : null;
    final highlightedIndex =
        highlighted == null ? null : ranked.indexOf(highlighted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DonutChart(
          slices: [
            for (final id in ranked)
              (value: expenditure.shareOf(id), color: colors[id]!),
          ],
          highlighted: highlightedIndex,
          onSliceTap: (index) => _toggle(index == null ? null : ranked[index]),
          label: highlighted == null ? 'Group spent' : members[highlighted]!,
          amount: highlighted == null
              ? expenditure.total
              : expenditure.shareOf(highlighted),
          caption: highlighted == null
              ? (expenditure.expenseCount == 1
                  ? '1 expense'
                  : '${expenditure.expenseCount} expenses')
              : '${_percent(expenditure.shareOf(highlighted), expenditure.total)}'
                  ' of the total',
        ),
        // Reserves its height either way, so the list doesn't jump.
        SizedBox(
          height: 40,
          child: highlighted == null
              ? Center(
                  child: Text(
                    'Tap a slice to see who it is',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text('Cost per person', style: textTheme.titleSmall),
        ),
        for (final id in ranked)
          ListTile(
            onTap: () => _toggle(id),
            selected: id == highlighted,
            selectedTileColor: colorScheme.secondaryContainer,
            selectedColor: colorScheme.onSecondaryContainer,
            leading: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: colors[id],
                shape: BoxShape.circle,
              ),
            ),
            minLeadingWidth: 14,
            title: Text(
              members[id]!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${_percent(expenditure.shareOf(id), expenditure.total)} '
              'of the total',
            ),
            trailing: Text(
              context.groupCurrency.format(expenditure.shareOf(id)),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const _Footnote(),
        if (ranked.length < members.length)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'Members with no share in this period are not shown.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Cost is each person\'s share, including unsettled amounts.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String _percent(int part, int whole) {
  if (whole == 0) return '0%';
  final pct = part * 100 / whole;
  return pct >= 10 || pct == 0
      ? '${pct.round()}%'
      : '${pct.toStringAsFixed(1)}%';
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.slices,
    required this.label,
    required this.amount,
    required this.caption,
    this.highlighted,
    this.onSliceTap,
  });

  final List<({int value, Color color})> slices;
  final String label;
  final int amount;
  final String caption;

  /// Index into [slices] drawn raised, with the others dimmed.
  final int? highlighted;

  /// Called with the tapped slice's index, or null for a tap in the hole.
  final ValueChanged<int?>? onSliceTap;

  static const _size = 240.0;

  /// Which slice, if any, is under [position] (local to the chart's square).
  int? _sliceAt(Offset position) {
    final fromCenter = position - const Offset(_size / 2, _size / 2);
    final radius = _DonutPainter.radiusFor(const Size.square(_size));
    // A little slack either side, so a near miss still lands.
    if ((fromCenter.distance - radius).abs() > _DonutPainter.stroke / 2 + 8) {
      return null;
    }

    final total = slices.fold(0, (sum, s) => sum + s.value);
    if (total <= 0) return null;
    // Clockwise from twelve o'clock, matching how the slices are drawn.
    var angle = atan2(fromCenter.dy, fromCenter.dx) + pi / 2;
    if (angle < 0) angle += 2 * pi;

    var start = 0.0;
    for (var i = 0; i < slices.length; i++) {
      start += 2 * pi * slices[i].value / total;
      if (angle < start) return i;
    }
    return slices.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: onSliceTap == null
              ? null
              : (details) => onSliceTap!(_sliceAt(details.localPosition)),
          child: SizedBox.square(
            dimension: _size,
            child: CustomPaint(
              painter: _DonutPainter(
                slices: slices,
                highlighted: highlighted,
                gapColor: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: Padding(
                padding: const EdgeInsets.all(52),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    FittedBox(
                      child: Text(
                        context.groupCurrency.format(amount),
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      caption,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.gapColor,
    this.highlighted,
  });

  final List<({int value, Color color})> slices;
  final Color gapColor;
  final int? highlighted;

  static const stroke = 32.0;

  /// How much wider the highlighted slice is drawn.
  static const _raise = 10.0;

  /// Radius of the ring's centre line, leaving room for a raised slice.
  static double radiusFor(Size size) =>
      size.shortestSide / 2 - (stroke + _raise) / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold(0, (sum, s) => sum + s.value);
    if (total <= 0) return;

    final radius = radiusFor(size);
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);

    var start = -pi / 2;
    for (var i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final sweep = 2 * pi * slice.value / total;
      if (sweep > 0) {
        final isRaised = i == highlighted;
        final dimmed = highlighted != null && !isRaised;
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isRaised ? stroke + _raise : stroke
            ..color = dimmed ? slice.color.withValues(alpha: 0.3) : slice.color,
        );
      }
      start += sweep;
    }

    // Thin separators between slices, so equal neighbours stay readable.
    if (slices.where((s) => s.value > 0).length > 1) {
      final separator = Paint()
        ..color = gapColor
        ..strokeWidth = 2;
      final inner = radius - (stroke + _raise) / 2;
      final outer = radius + (stroke + _raise) / 2;
      var angle = -pi / 2;
      for (final slice in slices) {
        if (slice.value == 0) continue;
        final dir = Offset(cos(angle), sin(angle));
        canvas.drawLine(center + dir * inner, center + dir * outer, separator);
        angle += 2 * pi * slice.value / total;
      }
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.gapColor != gapColor ||
      old.highlighted != highlighted ||
      old.slices.toString() != slices.toString();
}
