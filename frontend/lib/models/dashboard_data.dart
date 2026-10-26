class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.inventory,
    required this.reorderPoint,
    required this.unitPrice,
    required this.supplier,
    required this.leadTimeDays,
    required this.status,
  });

  final int id;
  final String name;
  final String sku;
  final String category;
  final int inventory;
  final int reorderPoint;
  final double unitPrice;
  final String supplier;
  final int leadTimeDays;
  final String status;

  bool get needsReorder => inventory <= reorderPoint;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as int,
        name: json['name'] as String,
        sku: json['sku'] as String,
        category: json['category'] as String,
        inventory: json['inventory'] as int,
        reorderPoint: json['reorder_point'] as int,
        unitPrice: double.parse(json['unit_price'].toString()),
        supplier: json['supplier'] as String? ?? '',
        leadTimeDays: json['lead_time_days'] as int? ?? 3,
        status: json['status'] as String,
      );
}

class InventoryRisk {
  const InventoryRisk({
    required this.product,
    required this.forecastUnits,
    required this.daysCover,
    required this.leadTimeDays,
    required this.suggestedReplenishment,
    required this.risk,
    required this.reason,
  });

  final Product product;
  final int forecastUnits;
  final double daysCover;
  final int leadTimeDays;
  final int suggestedReplenishment;
  final String risk;
  final String reason;

  factory InventoryRisk.fromJson(Map<String, dynamic> json) =>
      InventoryRisk(
        product: Product.fromJson(json['product'] as Map<String, dynamic>),
        forecastUnits: json['forecast_units'] as int,
        daysCover: (json['days_cover'] as num).toDouble(),
        leadTimeDays: json['lead_time_days'] as int,
        suggestedReplenishment: json['suggested_replenishment'] as int,
        risk: json['risk'] as String,
        reason: json['reason'] as String,
      );
}

class Overview {
  const Overview({
    required this.salesLast7Days,
    required this.salesChangePercent,
    required this.forecastNext7Days,
    required this.inventoryValue,
    required this.lowStockCount,
    required this.productCount,
    required this.historicalSalesRevenue,
    required this.salesHistory,
    required this.featuredSalesHistory,
  });

  final int salesLast7Days;
  final double salesChangePercent;
  final int forecastNext7Days;
  final double inventoryValue;
  final int lowStockCount;
  final int productCount;
  final double historicalSalesRevenue;
  final List<({DateTime date, int actual})> salesHistory;
  final List<({DateTime date, int actual})> featuredSalesHistory;

  factory Overview.fromJson(Map<String, dynamic> json) => Overview(
        salesLast7Days: json['sales_last_7_days'] as int,
        salesChangePercent:
            (json['sales_change_percent'] as num).toDouble(),
        forecastNext7Days: json['forecast_next_7_days'] as int,
        inventoryValue: (json['inventory_value'] as num).toDouble(),
        lowStockCount: json['low_stock_count'] as int,
        productCount: json['product_count'] as int,
        historicalSalesRevenue:
            (json['historical_sales_revenue'] as num).toDouble(),
        salesHistory: (json['sales_history'] as List<dynamic>)
            .map((item) {
              final point = item as Map<String, dynamic>;
              return (
                date: DateTime.parse(point['date'] as String),
                actual: point['actual'] as int,
              );
            })
            .toList(),
        featuredSalesHistory:
            (json['featured_sales_history'] as List<dynamic>)
                .map((item) {
                  final point = item as Map<String, dynamic>;
                  return (
                    date: DateTime.parse(point['date'] as String),
                    actual: point['actual'] as int,
                  );
                })
                .toList(),
      );
}
