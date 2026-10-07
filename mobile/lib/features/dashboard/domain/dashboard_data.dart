class DashboardData {
  DashboardData({
    required this.todayRevenue,
    required this.todayExpenses,
    required this.todayProfit,
    required this.salesCount,
    required this.lowStockCount,
    required this.unpaidInvoicesCount,
    required this.upcomingAppointmentsCount,
    required this.totalOutstandingCredit,
    this.inventoryValue = 0,
    this.todayGrossProfit,
  });

  final double todayRevenue;
  final double todayExpenses;
  final double todayProfit;
  final int salesCount;
  final int lowStockCount;
  final int unpaidInvoicesCount;
  final int upcomingAppointmentsCount;
  final double inventoryValue;
  final double totalOutstandingCredit;
  final double? todayGrossProfit;

  static final empty = DashboardData(
    todayRevenue: 0.0,
    todayExpenses: 0.0,
    todayProfit: 0.0,
    salesCount: 0,
    lowStockCount: 0,
    unpaidInvoicesCount: 0,
    upcomingAppointmentsCount: 0,
    totalOutstandingCredit: 0.0,
    inventoryValue: 0.0,
    todayGrossProfit: 0.0,
  );

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
        todayRevenue: (json['todayRevenue'] ?? json['today_revenue'] ?? json['revenue'] ?? json['dailyRevenue'] as num?)?.toDouble() ?? 0.0,
        todayExpenses: (json['todayExpenses'] ?? json['today_expenses'] ?? json['expenses'] ?? json['dailyExpenses'] as num?)?.toDouble() ?? 0.0,
        todayProfit: (json['todayProfit'] ?? json['today_profit'] ?? json['netProfit'] ?? json['profit'] as num?)?.toDouble() ?? 0.0,
        salesCount: (json['salesCount'] ?? json['sales_count'] ?? json['totalSales'] ?? json['ordersCount'] as num?)?.toInt() ?? 0,
        lowStockCount: (json['lowStockCount'] ?? json['low_stock_count'] ?? json['lowStockProducts'] as num?)?.toInt() ?? 0,
        unpaidInvoicesCount: (json['unpaidInvoicesCount'] ?? json['unpaid_invoices_count'] ?? json['pendingInvoices'] as num?)?.toInt() ?? 0,
        upcomingAppointmentsCount: (json['upcomingAppointmentsCount'] ?? json['upcoming_appointments_count'] as num?)?.toInt() ?? 0,
        totalOutstandingCredit: (json['totalOutstandingCredit'] ?? json['total_outstanding_credit'] ?? json['outstandingCredit'] ?? json['credit'] as num?)?.toDouble() ?? 0.0,
        inventoryValue: (json['inventoryValue'] ?? json['inventory_value'] ?? json['stockValue'] as num?)?.toDouble() ?? 0.0,
        todayGrossProfit: (json['todayGrossProfit'] ?? json['today_gross_profit'] ?? json['grossProfit'] as num?)?.toDouble(),
      );
}
