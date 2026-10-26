import 'dart:async';

import 'package:flutter/material.dart';

import '../models/dashboard_data.dart';
import '../services/demand_api.dart';

const _mint = Color(0xFF176F5E);
const _paleMint = Color(0xFFD8F4EA);
const _muted = Color(0xFF728098);
const _border = Color(0xFFDCE2E9);
const _surface = Color(0xFFFFFFFF);

const _tabTitles = ['Home', 'Forecasts', 'Simulator', 'Inventory', 'Insights'];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DemandApi _api = DemandApi();
  late Future<(Overview, List<Product>, List<InventoryRisk>)> _data;
  Timer? _syncTimer;
  int _selectedTab = 0;
  double _promotion = 10;
  double _priceChange = 0;
  double _replenishment = 120;
  int _simulatorStep = 0;
  bool _scenarioSaved = false;
  Product? _simulatedProduct;
  Product? _forecastProduct;

  @override
  void initState() {
    super.initState();
    _data = _api.loadDashboard();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _data = _api.loadDashboard();
        });
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final next = _api.loadDashboard();
    setState(() => _data = next);
    await next;
  }

  Future<void> _adjustInventory(Product product) async {
    final quantityController = TextEditingController(text: '1');
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Adjust ${product.name}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Current stock: ${product.inventory}',
                    style: const TextStyle(color: _muted)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Quantity change',
                    helperText: 'Use a negative number to remove stock.',
                  ),
                  validator: (value) {
                    final quantity = int.tryParse(value ?? '');
                    if (quantity == null || quantity == 0) {
                      return 'Enter a non-zero whole number.';
                    }
                    if (product.inventory + quantity < 0) {
                      return 'Stock cannot go below zero.';
                    }
                    return null;
                  },
                ),
                TextField(
                  controller: noteController,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
                if (error != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(error!,
                        style: const TextStyle(color: Color(0xFFC9433D))),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await _api.adjustInventory(
                    productId: product.id,
                    quantityChange: int.parse(quantityController.text),
                    note: noteController.text.trim(),
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (cause) {
                  setDialogState(() => error = cause.toString());
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    quantityController.dispose();
    noteController.dispose();
    if (confirmed == true && mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final title = _tabTitles[_selectedTab];
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: _surface,
        titleSpacing: 20,
        title: Row(
          children: [
            if (_selectedTab == 0) ...[
              const Icon(Icons.show_chart_rounded, color: _mint, size: 23),
              const SizedBox(width: 8),
            ],
            Text(_selectedTab == 0 ? 'DemandTwin AI' : title,
                style: const TextStyle(
                    color: Color(0xFF182333),
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
            color: _muted,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 15),
            child: CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFFEDF1F6),
              child: Text('AP',
                  style: TextStyle(
                      color: Color(0xFF182333),
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: FutureBuilder<(Overview, List<Product>, List<InventoryRisk>)>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: _mint));
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onRetry: () => setState(() => _data = _api.loadDashboard()),
            );
          }
          final (overview, products, risks) = snapshot.requireData;
          final selected = risks.firstWhere(
            (risk) => risk.product.sku == 'CD-001',
            orElse: () => risks.first,
          );
          final forecastSelected = risks.firstWhere(
            (risk) => risk.product.id == _forecastProduct?.id,
            orElse: () => selected,
          );
          final simulated = risks.firstWhere(
            (risk) => risk.product.id == _simulatedProduct?.id,
            orElse: () => selected,
          );
          return RefreshIndicator(
            color: _mint,
            onRefresh: _refresh,
            child: ListView(
              key: PageStorageKey(title),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                _StoreLine(),
                const SizedBox(height: 22),
                switch (_selectedTab) {
                  0 => _HomeContent(
                      overview: overview,
                      products: products,
                      risks: risks,
                      selected: selected,
                      onReview: _adjustInventory,
                      onSimulator: () => setState(() => _selectedTab = 2),
                    ),
                  1 => _ForecastContent(
                      risks: risks,
                      selected: forecastSelected,
                      history: overview.featuredSalesHistory,
                      onProductChanged: (product) =>
                          setState(() => _forecastProduct = product),
                    ),
                  2 => _SimulatorContent(
                      risks: risks,
                      selected: simulated,
                      step: _simulatorStep,
                      scenarioSaved: _scenarioSaved,
                      promotion: _promotion,
                      priceChange: _priceChange,
                      replenishment: _replenishment,
                      onProductChanged: (product) =>
                          setState(() => _simulatedProduct = product),
                      onStepChanged: (step) =>
                          setState(() => _simulatorStep = step),
                      onSavedChanged: (saved) =>
                          setState(() => _scenarioSaved = saved),
                      onPromotionChanged: (value) =>
                          setState(() => _promotion = value),
                      onPriceChangeChanged: (value) =>
                          setState(() => _priceChange = value),
                      onReplenishmentChanged: (value) =>
                          setState(() => _replenishment = value),
                    ),
                  3 => _InventoryContent(
                      risks: risks,
                      onAdjust: _adjustInventory,
                    ),
                  _ => const _InsightsContent(),
                },
                const SizedBox(height: 12),
                const Text(
                  'FreshMart Supermarket · Ahmedabad · Illustrative demo only',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 9),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        backgroundColor: _surface,
        indicatorColor: _paleMint,
        height: 66,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.show_chart_rounded), label: 'Forecasts'),
          NavigationDestination(
              icon: Icon(Icons.tune_rounded), label: 'Simulator'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
          NavigationDestination(
              icon: Icon(Icons.lightbulb_outline_rounded), label: 'Insights'),
        ],
      ),
    );
  }
}

class _StoreLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(
            child: Text('FreshMart · Ahmedabad⌄',
                style: TextStyle(color: _muted, fontSize: 11)),
          ),
          Container(
            decoration: BoxDecoration(
                color: const Color(0xFFEDF1F6),
                borderRadius: BorderRadius.circular(5)),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            child: const Text('Demo data · Not live',
                style: TextStyle(color: _muted, fontSize: 9)),
          ),
        ],
      );
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.overview,
    required this.products,
    required this.risks,
    required this.selected,
    required this.onReview,
    required this.onSimulator,
  });

  final Overview overview;
  final List<Product> products;
  final List<InventoryRisk> risks;
  final InventoryRisk selected;
  final ValueChanged<Product> onReview;
  final VoidCallback onSimulator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Good morning, Aarav',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF182333))),
        const SizedBox(height: 5),
        const Text('Your next decision, made clearer.',
            style: TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 4),
        const Text('19–25 Oct 2026⌄',
            style: TextStyle(color: _mint, fontSize: 11)),
        const SizedBox(height: 18),
        _ReviewCard(risk: selected, onReview: onReview),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Forecasted Demand',
                value: _format(selected.forecastUnits),
                detail: '${selected.product.name} · Next week',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Units sold',
                value: _format(overview.salesLast7Days),
                detail: 'Store · 19–25 Oct',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Store performance',
          subtitle: '',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PerformanceLine(
                  label: 'Total sales · Historical',
                  value: _currency(overview.historicalSalesRevenue)),
              _PerformanceLine(
                  label: 'Change vs previous week',
                  value:
                      '${overview.salesChangePercent >= 0 ? '+' : ''}${overview.salesChangePercent.toStringAsFixed(1)}%'),
              _PerformanceLine(
                  label: 'Inventory at Risk',
                  value:
                      '${risks.where((risk) => risk.risk == 'High').length} SKUs · high risk'),
              const _PerformanceLine(
                  label: 'Forecast accuracy', value: 'Not estimated · Demo'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '${selected.product.name} outlook',
          subtitle:
              '${_format((selected.forecastUnits * .89).round())} historical → ${_format(selected.forecastUnits)} predicted units / week',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  height: 165,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _DemandChartPainter(
                      overview.featuredSalesHistory,
                      forecast: selected.forecastUnits,
                    ),
                  )),
              const SizedBox(height: 10),
              const Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Legend(color: Color(0xFF101A2B), label: 'Historical actual'),
                  _Legend(color: Color(0xFF368C78), label: 'Predicted'),
                  _Legend(color: Color(0xFFD4F2E7), label: '80% uncertainty band'),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Illustrative outlook only. No live data or trained model.',
                style: TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _InfoBanner(
          title: 'A warmer week may lift demand',
          body:
              'Seasonal and festive-period assumptions support the illustrative outlook. Validate local conditions before ordering.',
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Try a decision safely',
          subtitle: '',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A 10% promotion could mean more hypothetical units. Compare before you commit.',
                style: TextStyle(fontSize: 12, height: 1.45),
              ),
              const SizedBox(height: 13),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSimulator,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Run Simulation'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _mint,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(44, 44),
                  ),
                ),
              ),
            ],
          ),
          mint: true,
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.risk, required this.onReview});

  final InventoryRisk risk;
  final ValueChanged<Product> onReview;

  @override
  Widget build(BuildContext context) {
    final gap = (risk.forecastUnits - risk.product.inventory).clamp(0, 999999);
    return _SectionCard(
      title: 'Review ${risk.product.name} inventory',
      subtitle: 'High risk  ·  Next 7 days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${risk.daysCover} days of stock. ${risk.leadTimeDays}-day lead time.',
            style: const TextStyle(
                fontSize: 19, height: 1.35, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${_format(risk.product.inventory)} on hand vs ${_format(risk.forecastUnits)} predicted next week. Review a ${_format(risk.suggestedReplenishment)}-unit replenishment.',
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onReview(risk.product),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Review inventory'),
              style: FilledButton.styleFrom(
                backgroundColor: _mint,
                foregroundColor: Colors.white,
                minimumSize: const Size(44, 44),
              ),
            ),
          ),
          if (gap > 0)
            const Padding(
              padding: EdgeInsets.only(top: 9),
              child: Text('Suggested quantity includes an illustrative safety buffer.',
                  style: TextStyle(color: _muted, fontSize: 9)),
            ),
        ],
      ),
    );
  }
}

class _ForecastContent extends StatelessWidget {
  const _ForecastContent({
    required this.risks,
    required this.selected,
    required this.history,
    required this.onProductChanged,
  });

  final List<InventoryRisk> risks;
  final InventoryRisk selected;
  final List<({DateTime date, int actual})> history;
  final ValueChanged<Product> onProductChanged;

  @override
  Widget build(BuildContext context) {
    final hasProductHistory =
        selected.product.sku == 'CD-001' && history.isNotEmpty;
    final historicalUnits =
        hasProductHistory ? history.last.actual : null;
    final weeklyChange = historicalUnits == null || historicalUnits == 0
        ? null
        : (selected.forecastUnits - historicalUnits) /
            historicalUnits *
            100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Demand Forecasts',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        const Text('A forward-looking view, with uncertainty in plain sight.',
            style: TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Product',
          child: DropdownButtonFormField<Product>(
            value: selected.product,
            decoration: const InputDecoration(labelText: 'Find a product'),
            items: risks
                .map((risk) => DropdownMenuItem(
                    value: risk.product, child: Text(risk.product.name)))
                .toList(),
            onChanged: (product) {
              if (product != null) onProductChanged(product);
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Expected units · next week',
                value: _format(selected.forecastUnits),
                detail: 'Predicted baseline',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Historical units · last week',
                value: historicalUnits == null
                    ? '—'
                    : _format(historicalUnits),
                detail: historicalUnits == null
                    ? 'Not available in this demo'
                    : 'Observed demo',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Change vs history',
                value: weeklyChange == null
                    ? '—'
                    : '${weeklyChange >= 0 ? '+' : ''}${weeklyChange.toStringAsFixed(1)}%',
                detail: 'Illustrative comparison',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: '80% illustrative range',
                value:
                    '${_format((selected.forecastUnits * .92).round())}–${_format((selected.forecastUnits * 1.08).round())}',
                detail: 'Units · not a guarantee',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '${selected.product.name} · Actual vs predicted',
          subtitle: 'Weekly demand · 26 Oct–1 Nov 2026',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasProductHistory)
                SizedBox(
                  height: 175,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _DemandChartPainter(
                      history,
                      forecast: selected.forecastUnits,
                    ),
                  ),
                )
              else
                const Text(
                  'Product-level historical chart is not available for this item in the demo.',
                  style: TextStyle(color: _muted, fontSize: 11, height: 1.45),
                ),
              const SizedBox(height: 10),
              const Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _Legend(color: Color(0xFF101A2B), label: 'Historical actual'),
                  _Legend(color: Color(0xFF368C78), label: 'Predicted'),
                  _Legend(
                      color: Color(0xFFD4F2E7), label: '80% uncertainty band'),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Illustrative baseline only. No trained model or live data connection.',
                style: TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _InfoBanner(
          title: 'Why demand may rise',
          body:
              'Seasonal and festive-period assumptions may influence the outlook. Validate local conditions before ordering.',
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'What to review',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PerformanceLine(
                label: 'Inventory on hand',
                value: '${_format(selected.product.inventory)} units',
              ),
              _PerformanceLine(
                label: 'Suggested replenishment',
                value: '${_format(selected.suggestedReplenishment)} units · advisory',
              ),
              _PerformanceLine(
                label: 'Coverage / supplier lead',
                value:
                    '${selected.daysCover} days / ${selected.leadTimeDays} days',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _InfoBanner(
          title: 'Forecasts are not guarantees',
          body:
              'Review inventory, expiry, pending orders and supplier lead time before acting.',
        ),
      ],
    );
  }
}

class _SimulatorContent extends StatelessWidget {
  const _SimulatorContent({
    required this.risks,
    required this.selected,
    required this.step,
    required this.scenarioSaved,
    required this.promotion,
    required this.priceChange,
    required this.replenishment,
    required this.onProductChanged,
    required this.onStepChanged,
    required this.onSavedChanged,
    required this.onPromotionChanged,
    required this.onPriceChangeChanged,
    required this.onReplenishmentChanged,
  });

  final List<InventoryRisk> risks;
  final InventoryRisk selected;
  final int step;
  final bool scenarioSaved;
  final double promotion;
  final double priceChange;
  final double replenishment;
  final ValueChanged<Product> onProductChanged;
  final ValueChanged<int> onStepChanged;
  final ValueChanged<bool> onSavedChanged;
  final ValueChanged<double> onPromotionChanged;
  final ValueChanged<double> onPriceChangeChanged;
  final ValueChanged<double> onReplenishmentChanged;

  @override
  Widget build(BuildContext context) {
    final baseline = selected.forecastUnits;
    final scenario =
        (baseline * (1 + promotion * .0139 - priceChange * .02)).round();
    final supply = selected.product.inventory + replenishment.round();
    final gap = (scenario + 40 - supply).clamp(0, 100000);
    final price = selected.product.unitPrice * (1 + priceChange / 100);
    final discountedPrice = price * (1 - promotion / 100);
    final baselineRevenue = baseline * price;
    final scenarioRevenue = scenario * discountedPrice;

    if (step == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New simulation',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const _InfoPill(label: 'Step 1 of 3 · Choose context', color: _paleMint),
          const SizedBox(height: 18),
          const Text('What would you like to test?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Start with a product and review the baseline. Your current inventory and forecast stay unchanged.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Store',
            subtitle: 'FreshMart · Ahmedabad Central',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<Product>(
                  value: selected.product,
                  decoration: const InputDecoration(labelText: 'Search products'),
                  items: risks
                      .map((risk) => DropdownMenuItem(
                          value: risk.product,
                          child: Text(risk.product.name)))
                      .toList(),
                  onChanged: (product) {
                    if (product != null) onProductChanged(product);
                  },
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: selected.product.name,
                  subtitle:
                      '${selected.product.category} · ${selected.product.sku}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PerformanceLine(
                        label: 'Predicted baseline · next week',
                        value: '${_format(baseline)} units',
                      ),
                      _PerformanceLine(
                        label: 'Historical · last week',
                        value: '${_format((baseline * .89).round())} units',
                      ),
                      _PerformanceLine(
                        label: 'Available inventory',
                        value: '${_format(selected.product.inventory)} units',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _InfoBanner(
            title: 'A safe space for assumptions',
            body:
                'This simulation will not update prices, place an order, or change inventory.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onStepChanged(1),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continue to assumptions'),
              style: FilledButton.styleFrom(
                backgroundColor: _mint,
                minimumSize: const Size(44, 46),
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => onStepChanged(3),
              child: const Text('View saved scenarios'),
            ),
          ),
        ],
      );
    }

    if (step == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Scenario assumptions',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const _InfoPill(label: 'Step 2 of 3 · Configure', color: _paleMint),
          const SizedBox(height: 18),
          Text(selected.product.name,
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Ahmedabad Central · 26 Oct–1 Nov',
              style: TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Price & promotion',
            child: Column(
              children: [
                _RangeSetting(
                  title: 'Price change',
                  value: priceChange,
                  suffix: '%',
                  min: -20,
                  max: 20,
                  onChanged: onPriceChangeChanged,
                ),
                _RangeSetting(
                  title: 'Promotion discount',
                  value: promotion,
                  suffix: '%',
                  min: 0,
                  max: 30,
                  onChanged: onPromotionChanged,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Effective unit price · ${_currency(discountedPrice)}',
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _SectionCard(
            title: 'Contextual assumptions',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PerformanceLine(
                    label: 'Festival / event', value: 'Festive week · Baseline'),
                _PerformanceLine(
                    label: 'Weather', value: 'Warm · Demo baseline'),
                Text(
                  'Weather is not connected to a live source.',
                  style: TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Inventory assumptions',
            child: Column(
              children: [
                _PerformanceLine(
                  label: 'Available inventory',
                  value: '${_format(selected.product.inventory)} units',
                ),
                _RangeSetting(
                  title: 'Planned replenishment',
                  value: replenishment,
                  suffix: ' units',
                  min: 0,
                  max: 500,
                  onChanged: onReplenishmentChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _InfoBanner(
            title: 'Assumptions, not guarantees',
            body:
                'Promotion response is illustrative. No live data, trained model or weather source is active.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onStepChanged(2),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Run simulation'),
              style: FilledButton.styleFrom(
                backgroundColor: _mint,
                minimumSize: const Size(44, 46),
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => onStepChanged(0),
              child: const Text('Back to context'),
            ),
          ),
        ],
      );
    }

    if (step == 3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Saved comparisons',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Same store and week. Different assumptions.',
              style: TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Predicted baseline',
            subtitle: '${selected.product.name} · No promotion',
            child: Text(
              '${_format(baseline)} units',
              style:
                  const TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          if (scenarioSaved)
            _SectionCard(
              title: 'Promotion +${promotion.round()}%',
              subtitle: 'Hypothetical · Not an actual outcome',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_format(scenario)} units',
                    style: const TextStyle(
                        fontSize: 27, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _PerformanceLine(
                    label: 'Change vs predicted baseline',
                    value:
                        '+${_format(scenario - baseline)} / ${baseline == 0 ? '0.0' : ((scenario - baseline) / baseline * 100).toStringAsFixed(1)}%',
                  ),
                  _PerformanceLine(
                    label: 'Replenishment to review',
                    value:
                        '${_format((scenario + 40 - selected.product.inventory).clamp(0, 100000))} units',
                  ),
                ],
              ),
            )
          else
            const _InfoBanner(
              title: 'No saved scenarios yet',
              body: 'Run a simulation and save it to compare assumptions here.',
            ),
          const SizedBox(height: 12),
          const _InfoBanner(
            title: 'Higher demand is not automatically better',
            body:
                'Scenario values are illustrative assumptions, not performance claims.',
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Saved for this app session only. Scenario comparisons are not synced to the website.',
              style: TextStyle(color: _muted, fontSize: 10, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onStepChanged(0),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New simulation'),
              style: FilledButton.styleFrom(
                backgroundColor: _mint,
                minimumSize: const Size(44, 46),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Simulation results',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const _InfoPill(label: 'Step 3 of 3 · Complete', color: _paleMint),
        const SizedBox(height: 12),
        const Text('A promotion may lift demand.',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text('${selected.product.name} · Ahmedabad Central · 26 Oct–1 Nov',
            style: TextStyle(color: _muted, fontSize: 12)),
        _SectionCard(
          title: 'Predicted baseline',
          subtitle: 'No promotion · ${_currency(price)} / unit',
          child: Text(
            '${_format(baseline)} units',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _MetricCard(
              label: 'Hypothetical scenario',
              value: '${_format(scenario)} units',
              detail:
                  '+${_format(scenario - baseline)} / ${baseline == 0 ? '0.0' : ((scenario - baseline) / baseline * 100).toStringAsFixed(1)}%',
              amber: true,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(
              label: '80% illustrative range',
              value:
                  '${_format((scenario * .9).round())}–${_format((scenario * 1.1).round())}',
              detail: 'Not a guarantee',
            )),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Compare demand',
          child: Column(
            children: [
              _ComparisonBar(
                label: 'Predicted baseline',
                value: baseline,
                maxValue: [baseline, scenario].reduce((a, b) => a > b ? a : b),
                color: const Color(0xFF101A2B),
              ),
              const SizedBox(height: 13),
              _ComparisonBar(
                label: 'Hypothetical scenario',
                value: scenario,
                maxValue: [baseline, scenario].reduce((a, b) => a > b ? a : b),
                color: const Color(0xFFF2B740),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: gap > 0
              ? 'High stock-out risk · ${_format(gap)}-unit gap'
              : 'Stock coverage · illustrative',
          subtitle: '${_format(supply)} units available after replenishment',
          child: Text(
            gap > 0
                ? 'Review ${_format(gap)} more units to cover the scenario and assumed 40-unit buffer. No order is placed.'
                : 'Supply covers the hypothetical scenario and assumed buffer at the midpoint.',
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
          ),
          mint: gap == 0,
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Hypothetical revenue · Not a forecast',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PerformanceLine(
                label: 'Predicted baseline value',
                value:
                    '${_format(baseline)} × ${_currency(price)} = ${_currency(baselineRevenue)}',
              ),
              _PerformanceLine(
                label: 'Hypothetical promotional value',
                value:
                    '${_format(scenario)} × ${_currency(discountedPrice)} = ${_currency(scenarioRevenue)}',
              ),
              _PerformanceLine(
                label: 'Hypothetical difference',
                value:
                    '${scenarioRevenue - baselineRevenue >= 0 ? '+' : ''}${_currency(scenarioRevenue - baselineRevenue)}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _InfoBanner(
          title: 'Advisory only',
          body:
              'Assumes demand is fulfilled. Excludes costs, taxes, returns and stock-outs. Validate assumptions before acting.',
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              onSavedChanged(true);
              onStepChanged(3);
            },
            icon: const Icon(Icons.bookmark_outline_rounded),
            label: Text(scenarioSaved ? 'Update saved scenario' : 'Save scenario'),
            style: FilledButton.styleFrom(
              backgroundColor: _mint,
              minimumSize: const Size(44, 46),
            ),
          ),
        ),
        Center(
          child: TextButton.icon(
            onPressed: () => onStepChanged(3),
            icon: const Icon(Icons.compare_arrows_rounded),
            label: const Text('Compare scenarios'),
          ),
        ),
      ],
    );
  }
}

class _InventoryContent extends StatelessWidget {
  const _InventoryContent({required this.risks, required this.onAdjust});

  final List<InventoryRisk> risks;
  final ValueChanged<Product> onAdjust;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${risks.where((risk) => risk.risk != 'Low').length} products need review.',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Next 7 days · 26 Oct–1 Nov 2026',
              style: TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 18),
          ...risks.map((risk) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SectionCard(
                  title: risk.product.name,
                  subtitle:
                      '${risk.product.sku} · ${risk.product.category} · ${risk.risk.toLowerCase()} risk',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PerformanceLine(
                          label: 'On hand / predicted next week',
                          value:
                              '${_format(risk.product.inventory)} / ${_format(risk.forecastUnits)} units'),
                      _PerformanceLine(
                          label: 'Coverage / supplier lead',
                          value:
                              '${risk.daysCover} days / ${risk.leadTimeDays} days'),
                      _PerformanceLine(
                          label: 'Replenishment to review',
                          value:
                              '${_format(risk.suggestedReplenishment)} units'),
                      const SizedBox(height: 9),
                      Text(risk.reason,
                          style:
                              const TextStyle(color: _muted, fontSize: 10)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => onAdjust(risk.product),
                          icon: const Icon(Icons.arrow_forward, size: 15),
                          label: const Text('Review inventory'),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
          const _InfoBanner(
              title: 'No automatic ordering',
              body:
                  'Replenishment is advisory. Check expiry, pending orders and supplier capacity.'),
        ],
      );
}

class _InsightsContent extends StatelessWidget {
  const _InsightsContent();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('The story behind the numbers.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Historical patterns · Illustrative demo data',
              style: TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 18),
          const _SectionCard(
            title: 'Drinks and snacks often travel together',
            subtitle: 'Association · Not causation',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('180 of 1,000 demo baskets included both Cold Drinks and Packaged Snacks.',
                    style: TextStyle(fontSize: 13, height: 1.5)),
                SizedBox(height: 14),
                _PerformanceLine(label: 'Support', value: '18% of all baskets'),
                _PerformanceLine(
                    label: 'Confidence', value: '60% of Cold Drinks baskets'),
                _PerformanceLine(label: 'Lift', value: '1.50× association'),
                SizedBox(height: 12),
                _InfoBanner(
                  title: 'Try a merchandising test',
                  body:
                      'Consider adjacent shelf placement, then compare basket behavior. Association does not prove causation.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _SectionCard(
            title: 'Prepare for the weekend',
            subtitle: 'Seasonal pattern · illustrative',
            child: Text(
                'Higher basket intensity may justify a shelf check before peak hours, not an automatic stock increase.',
                style: TextStyle(fontSize: 12, height: 1.5)),
          ),
        ],
      );
}

class _RangeSetting extends StatelessWidget {
  const _RangeSetting({
    required this.title,
    required this.value,
    required this.suffix,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final double value;
  final String suffix;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11)),
              Text('${value.round()}$suffix',
                  style: const TextStyle(color: _muted, fontSize: 10)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: _mint,
            onChanged: onChanged,
          ),
        ],
      );
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final String label;
  final int value;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 10)),
              Text('${_format(value)} units',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 16,
              color: const Color(0xFFE9EDF1),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: maxValue == 0
                    ? 0
                    : (value / maxValue).clamp(0.0, 1.0).toDouble(),
                child: ColoredBox(color: color),
              ),
            ),
          ),
        ],
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
    this.amber = false,
  });

  final String label;
  final String value;
  final String detail;
  final bool amber;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 116),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: _muted, fontSize: 10)),
            const SizedBox(height: 12),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: amber ? const Color(0xFFBC6D0B) : _inkColor,
                    fontSize: 23,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 9)),
          ],
        ),
      );
}

const _inkColor = Color(0xFF182333);

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.subtitle = '',
    required this.child,
    this.mint = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool mint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 17, 16, 15),
        decoration: BoxDecoration(
          color: mint ? _paleMint : _surface,
          border: Border.all(color: mint ? _paleMint : _border),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: _inkColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(subtitle,
                  style: const TextStyle(color: _muted, fontSize: 10)),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}

class _PerformanceLine extends StatelessWidget {
  const _PerformanceLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: _muted, fontSize: 10)),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    color: _inkColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _paleMint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(body,
                style: const TextStyle(
                    color: _muted, fontSize: 10, height: 1.45)),
          ],
        ),
      );
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(5)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(label,
            style: const TextStyle(
                color: _mint, fontSize: 9, fontWeight: FontWeight.w600)),
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 12,
              height: 4,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: _muted, fontSize: 9)),
        ],
      );
}

class _DemandChartPainter extends CustomPainter {
  const _DemandChartPainter(this.points, {this.forecast = 0});

  final List<({DateTime date, int actual})> points;
  final int forecast;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    const top = 10.0;
    const bottom = 24.0;
    final chartHeight = size.height - top - bottom;
    final chartWidth = size.width - left - 5;
    final historyPeak = points.fold<int>(
        1, (maximum, point) => point.actual > maximum ? point.actual : maximum);
    final peak = (historyPeak > forecast ? historyPeak : forecast) * 1.25;
    final historyWidth = forecast > 0 ? chartWidth * .68 : chartWidth;
    final gridPaint = Paint()
      ..color = const Color(0xFFE4E8EE)
      ..strokeWidth = 1;
    final labelStyle = const TextStyle(color: _muted, fontSize: 8);
    for (var index = 0; index < 5; index++) {
      final y = top + index * chartHeight / 4;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), gridPaint);
      final label = TextPainter(
        text: TextSpan(
            text: _format((peak * (4 - index) / 4).round()), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: left - 3);
      label.paint(canvas, Offset(0, y - label.height / 2));
    }
    if (points.length < 2) return;
    final historyLine = Path();
    for (var index = 0; index < points.length; index++) {
      final x = left + index * historyWidth / (points.length - 1);
      final y = top + chartHeight * (1 - points[index].actual / peak);
      if (index == 0) {
        historyLine.moveTo(x, y);
      } else {
        historyLine.lineTo(x, y);
      }
      final label = TextPainter(
        text: TextSpan(
          text: '${points[index].date.day} ${_month(points[index].date.month)}',
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(x - label.width / 2, size.height - 14));
    }
    canvas.drawPath(
      historyLine,
      Paint()
        ..color = const Color(0xFF101A2B)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (forecast > 0) {
      final startX = left + historyWidth;
      final endX = left + chartWidth;
      final previous = points.last.actual;
      final previousY = top + chartHeight * (1 - previous / peak);
      final forecastY = top + chartHeight * (1 - forecast / peak);
      final bandPaint = Paint()..color = const Color(0xFFD4F2E7);
      canvas.drawRect(
        Rect.fromLTRB(
          startX,
          (forecastY - 8).clamp(top, top + chartHeight).toDouble(),
          endX,
          (forecastY + 8).clamp(top, top + chartHeight).toDouble(),
        ),
        bandPaint,
      );
      canvas.drawLine(
        Offset(startX, top),
        Offset(startX, top + chartHeight),
        Paint()
          ..color = const Color(0xFFDCE2E9)
          ..strokeWidth = 1,
      );
      final forecastLine = Path()
        ..moveTo(startX, previousY)
        ..lineTo(startX + (endX - startX) * .45,
            (previousY + forecastY) / 2)
        ..lineTo(endX, forecastY);
      canvas.drawPath(
        forecastLine,
        Paint()
          ..color = const Color(0xFF368C78)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      final forecastLabel = TextPainter(
        text: const TextSpan(
          text: 'Forecast',
          style: TextStyle(color: _muted, fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      forecastLabel.paint(
          canvas, Offset(endX - forecastLabel.width, size.height - 14));
    }
  }

  @override
  bool shouldRepaint(covariant _DemandChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.forecast != forecast;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, color: _muted, size: 42),
              const SizedBox(height: 14),
              const Text('Could not load your workspace',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

String _format(int value) => value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );

String _currency(double value) =>
    '₹${_format(value.round())}';

String _month(int month) => const [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][month];
