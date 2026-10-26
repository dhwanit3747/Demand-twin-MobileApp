import 'package:flutter_test/flutter_test.dart';
import 'package:demandtwin_mobile/models/dashboard_data.dart';

void main() {
  test('product data parses inventory and reorder status', () {
    final product = Product.fromJson({
      'id': 3,
      'name': 'Desk Lamp',
      'sku': 'OFF-032',
      'category': 'Office',
      'inventory': 12,
      'reorder_point': 15,
      'unit_price': '54.00',
      'supplier': 'Demo supplier',
      'lead_time_days': 4,
      'status': 'Reorder',
    });

    expect(product.unitPrice, 54);
    expect(product.needsReorder, isTrue);
  });

  test('overview data parses forecast and sales metrics', () {
    final overview = Overview.fromJson({
      'sales_last_7_days': 240,
      'sales_change_percent': 8.5,
      'forecast_next_7_days': 270,
      'inventory_value': 18340.5,
      'low_stock_count': 2,
      'product_count': 8,
      'historical_sales_revenue': 124000.0,
      'sales_history': [
        {'date': '2026-10-24', 'actual': 320},
      ],
      'featured_sales_history': [
        {'date': '2026-10-24', 'actual': 320},
      ],
    });

    expect(overview.salesLast7Days, 240);
    expect(overview.salesChangePercent, 8.5);
    expect(overview.forecastNext7Days, 270);
    expect(overview.historicalSalesRevenue, 124000);
    expect(overview.salesHistory.single.actual, 320);
    expect(overview.featuredSalesHistory.single.actual, 320);
  });
}
