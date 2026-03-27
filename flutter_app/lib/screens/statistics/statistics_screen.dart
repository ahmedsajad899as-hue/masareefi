import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/stats_model.dart';
import '../../providers/settings_provider.dart';
import '../../providers/stats_provider.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  DateTime _month = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(statsProvider.notifier).loadDashboard(
            year: _month.year,
            month: _month.month,
          );
    });
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    ref.read(statsProvider.notifier).loadDashboard(
          year: _month.year,
          month: _month.month,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final stats = ref.watch(statsProvider);
    final lang = ref.watch(settingsProvider).language;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.statistics),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: stats.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: () => ref.read(statsProvider.notifier).loadDashboard(
                    year: _month.year,
                    month: _month.month,
                  ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Month navigator
                  _MonthNavigator(month: _month, onChange: _changeMonth, l: l)
                      .animate()
                      .fadeIn(),

                  const SizedBox(height: 20),

                  // Total summary card
                  if (stats.monthly != null)
                    _TotalCard(l: l, monthly: stats.monthly!).animate().fadeIn(),

                  const SizedBox(height: 20),

                  // Category pie chart
                  if (stats.categories.isNotEmpty)
                    _CategoryPieCard(l: l, categories: stats.categories, lang: lang)
                        .animate()
                        .fadeIn(delay: 100.ms),

                  const SizedBox(height: 20),

                  // Daily trend bar chart
                  if (stats.trend.isNotEmpty)
                    _DailyTrendCard(l: l, trend: stats.trend).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 20),

                  // Monthly comparison
                  if (stats.comparison.isNotEmpty)
                    _MonthlyComparisonCard(l: l, data: stats.comparison)
                        .animate()
                        .fadeIn(delay: 300.ms),

                  const SizedBox(height: 20),

                  // AI Insights
                  _InsightsCard(l: l, stats: stats).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

// ─── Month Navigator ──────────────────────────────────────────────────────────

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({required this.month, required this.onChange, required this.l});
  final DateTime month;
  final void Function(int) onChange;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final months_ar = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    final months_en = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    final label = l.isArabic
        ? '${months_ar[month.month - 1]} ${month.year}'
        : '${months_en[month.month - 1]} ${month.year}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: () => onChange(-1), icon: const Icon(Icons.chevron_left_rounded)),
        Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        IconButton(
          onPressed: month.year == DateTime.now().year && month.month == DateTime.now().month
              ? null
              : () => onChange(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

// ─── Total Card ───────────────────────────────────────────────────────────────

class _TotalCard extends ConsumerWidget {
  const _TotalCard({required this.l, required this.monthly});
  final AppLocalizations l;
  final Map<String, dynamic> monthly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(settingsProvider).currency;
    final total = (monthly['total_amount'] as num?)?.toDouble() ?? 0.0;
    final count = monthly['expense_count'] as int? ?? 0;
    final avg = (monthly['average_daily'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.monthlyTotal, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 6),
          Text(
            '${total.toStringAsFixed(0)} $currency',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat(context, l.isArabic ? 'المعاملات' : 'Transactions', count.toString()),
              const SizedBox(width: 24),
              _stat(context, l.isArabic ? 'متوسط يومي' : 'Daily avg', '${avg.toStringAsFixed(0)} $currency'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext ctx, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    ],
  );
}

// ─── Category Pie Chart ───────────────────────────────────────────────────────

class _CategoryPieCard extends StatefulWidget {
  const _CategoryPieCard({required this.l, required this.categories, required this.lang});
  final AppLocalizations l;
  final List<CategoryStat> categories;
  final String lang;

  @override
  State<_CategoryPieCard> createState() => _CategoryPieCardState();
}

class _CategoryPieCardState extends State<_CategoryPieCard> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.l.categoryBreakdown, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sections: widget.categories.asMap().map((i, cat) {
                    final isTouched = i == _touched;
                    return MapEntry(i, PieChartSectionData(
                      value: cat.percentage,
                      color: AppColors.chartPalette[i % AppColors.chartPalette.length],
                      radius: isTouched ? 80 : 65,
                      title: '${cat.percentage.toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ));
                  }).values.toList(),
                  pieTouchData: PieTouchData(
                    touchCallback: (e, r) => setState(() => _touched = r?.touchedSection?.touchedSectionIndex ?? -1),
                  ),
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: widget.categories.asMap().map((i, cat) => MapEntry(i, Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(
                    color: AppColors.chartPalette[i % AppColors.chartPalette.length],
                    shape: BoxShape.circle,
                  )),
                  const SizedBox(width: 4),
                  Text(
                    widget.lang == 'ar' ? cat.categoryNameAr : cat.categoryNameEn,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ))).values.toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Daily Trend Bar Chart ────────────────────────────────────────────────────

class _DailyTrendCard extends StatelessWidget {
  const _DailyTrendCard({required this.l, required this.trend});
  final AppLocalizations l;
  final List<DailyTrendPoint> trend;

  @override
  Widget build(BuildContext context) {
    final top = trend.fold(0.0, (m, e) => e.total > m ? e.total : m);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.dailyTrend, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: top * 1.2,
                  barGroups: trend.asMap().map((i, p) => MapEntry(i, BarChartGroupData(
                    x: i,
                    barRods: [BarChartRodData(
                      toY: p.total,
                      color: AppColors.primary.withOpacity(0.85),
                      width: 10,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    )],
                  ))).values.toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
                        final day = trend[idx].date.day.toString();
                        return Text(day, style: const TextStyle(fontSize: 10));
                      },
                    )),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Monthly Comparison Bar Chart ────────────────────────────────────────────

class _MonthlyComparisonCard extends StatelessWidget {
  const _MonthlyComparisonCard({required this.l, required this.data});
  final AppLocalizations l;
  final List<MonthlyPoint> data;

  @override
  Widget build(BuildContext context) {
    final top = data.fold(0.0, (m, e) => e.total > m ? e.total : m);
    final months_short_en = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final months_short_ar = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    final isAr = l.isArabic;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.monthlyComparison, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: top * 1.2,
                  barGroups: data.asMap().map((i, p) => MapEntry(i, BarChartGroupData(
                    x: i,
                    barRods: [BarChartRodData(
                      toY: p.total,
                      gradient: AppColors.primaryGradient,
                      width: 18,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    )],
                  ))).values.toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                        final mIdx = data[idx].month - 1;
                        return Text(
                          isAr ? months_short_ar[mIdx] : months_short_en[mIdx],
                          style: const TextStyle(fontSize: 9),
                        );
                      },
                    )),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── AI Insights Card ─────────────────────────────────────────────────────────

class _InsightsCard extends ConsumerWidget {
  const _InsightsCard({required this.l, required this.stats});
  final AppLocalizations l;
  final StatsState stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(l.aiInsights, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (stats.isLoading)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 12),
            if (stats.insights != null)
              Text(stats.insights!, style: Theme.of(context).textTheme.bodyMedium)
            else
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => ref.read(statsProvider.notifier).loadInsights(),
                  icon: const Icon(Icons.tips_and_updates_rounded, size: 18),
                  label: Text(l.isArabic ? 'احصل على تحليل ذكي' : 'Get AI Analysis'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
