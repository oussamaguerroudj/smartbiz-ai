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

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
        todayRevenue: (json['todayRevenue'] as num?)?.toDouble() ?? 0.0,
        todayExpenses: (json['todayExpenses'] as num?)?.toDouble() ?? 0.0,
        todayProfit: (json['todayProfit'] as num?)?.toDouble() ?? 0.0,
        salesCount: (json['salesCount'] as num?)?.toInt() ?? 0,
        lowStockCount: (json['lowStockCount'] as num?)?.toInt() ?? 0,
        unpaidInvoicesCount: (json['unpaidInvoicesCount'] as num?)?.toInt() ?? 0,
        upcomingAppointmentsCount: (json['upcomingAppointmentsCount'] as num?)?.toInt() ?? 0,
        totalOutstandingCredit: (json['totalOutstandingCredit'] as num?)?.toDouble() ?? 0.0,
        inventoryValue: (json['inventoryValue'] as num?)?.toDouble() ?? 0.0,
        todayGrossProfit: (json['todayGrossProfit'] as num?)?.toDouble(),
      );
}
