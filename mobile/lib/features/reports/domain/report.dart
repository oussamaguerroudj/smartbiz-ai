class TopProduct {
  final String name;
  final int unitsSold;
  final double total;

  TopProduct({
    required this.name,
    required this.unitsSold,
    this.total = 0.0,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
        name: (json['name'] ?? 'Product').toString(),
        unitsSold: (json['units_sold'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0.0,
      );
}

class ExpenseCategoryItem {
  final String category;
  final double amount;
  final double total;

  ExpenseCategoryItem({
    required this.category,
    required this.amount,
    required this.total,
  });

  factory ExpenseCategoryItem.fromJson(Map<String, dynamic> json) =>
      ExpenseCategoryItem(
        category: (json['category'] ?? 'General').toString(),
        amount: (json['amount'] as num?)?.toDouble() ??
            (json['total'] as num?)?.toDouble() ??
            0.0,
        total: (json['total'] as num?)?.toDouble() ??
            (json['amount'] as num?)?.toDouble() ??
            0.0,
      );
}

class EmployeeSalaryItem {
  final String id;
  final String name;
  final String? position;
  final double baseSalary;
  final double periodSalary;
  final String? paymentDate;
  final String? salaryPeriod;
  final String? duration;

  EmployeeSalaryItem({
    required this.id,
    required this.name,
    this.position,
    required this.baseSalary,
    required this.periodSalary,
    this.paymentDate,
    this.salaryPeriod,
    this.duration,
  });

  factory EmployeeSalaryItem.fromJson(Map<String, dynamic> json) =>
      EmployeeSalaryItem(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        position: json['position']?.toString(),
        baseSalary: (json['baseSalary'] as num?)?.toDouble() ?? 0.0,
        periodSalary: (json['periodSalary'] as num?)?.toDouble() ?? 0.0,
        paymentDate: json['paymentDate']?.toString(),
        salaryPeriod: json['salaryPeriod']?.toString(),
        duration: json['duration']?.toString(),
      );
}

class RevenueBreakdown {
  final double sales;
  final double creditPayments;
  final double clinicRevenue;
  final double restaurantRevenue;
  final double totalRevenue;

  RevenueBreakdown({
    required this.sales,
    required this.creditPayments,
    required this.clinicRevenue,
    required this.restaurantRevenue,
    required this.totalRevenue,
  });

  factory RevenueBreakdown.fromJson(Map<String, dynamic> json) =>
      RevenueBreakdown(
        sales: (json['sales'] as num?)?.toDouble() ?? 0.0,
        creditPayments: (json['creditPayments'] as num?)?.toDouble() ?? 0.0,
        clinicRevenue: (json['clinicRevenue'] as num?)?.toDouble() ?? 0.0,
        restaurantRevenue:
            (json['restaurantRevenue'] as num?)?.toDouble() ?? 0.0,
        totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      );
}

class ExpensesBreakdown {
  final double operatingExpenses;
  final double employeeSalaries;
  final double costOfGoodsSold;
  final double totalExpenses;
  final List<ExpenseCategoryItem> byCategory;
  final List<EmployeeSalaryItem> byEmployee;

  ExpensesBreakdown({
    required this.operatingExpenses,
    required this.employeeSalaries,
    required this.costOfGoodsSold,
    required this.totalExpenses,
    required this.byCategory,
    required this.byEmployee,
  });

  factory ExpensesBreakdown.fromJson(Map<String, dynamic> json) =>
      ExpensesBreakdown(
        operatingExpenses:
            (json['operatingExpenses'] as num?)?.toDouble() ?? 0.0,
        employeeSalaries: (json['employeeSalaries'] as num?)?.toDouble() ?? 0.0,
        costOfGoodsSold: (json['costOfGoodsSold'] as num?)?.toDouble() ?? 0.0,
        totalExpenses: (json['totalExpenses'] as num?)?.toDouble() ?? 0.0,
        byCategory: ((json['byCategory'] as List?) ?? [])
            .map((e) => ExpenseCategoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        byEmployee: ((json['byEmployee'] as List?) ?? [])
            .map((e) => EmployeeSalaryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ActivitySummary {
  final int salesCount;
  final int expensesCount;
  final int employeesCount;
  final int invoicesCount;

  ActivitySummary({
    required this.salesCount,
    required this.expensesCount,
    required this.employeesCount,
    required this.invoicesCount,
  });

  factory ActivitySummary.fromJson(Map<String, dynamic> json) => ActivitySummary(
        salesCount: (json['salesCount'] as num?)?.toInt() ?? 0,
        expensesCount: (json['expensesCount'] as num?)?.toInt() ?? 0,
        employeesCount: (json['employeesCount'] as num?)?.toInt() ?? 0,
        invoicesCount: (json['invoicesCount'] as num?)?.toInt() ?? 0,
      );
}

class ReportTransaction {
  final String id;
  final String type; // 'sale' | 'expense' | 'salary'
  final double amount;
  final String? status;
  final DateTime? date;
  final String title;
  final String? description;
  final String? employeeName;
  final String? salaryPeriod;
  final String? duration;

  ReportTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.status,
    this.date,
    required this.title,
    this.description,
    this.employeeName,
    this.salaryPeriod,
    this.duration,
  });

  factory ReportTransaction.fromJson(Map<String, dynamic> json) =>
      ReportTransaction(
        id: (json['id'] ?? '').toString(),
        type: (json['type'] ?? 'sale').toString(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        status: json['status']?.toString(),
        date: json['date'] != null
            ? DateTime.tryParse(json['date'].toString())
            : null,
        title: (json['title'] ?? '').toString(),
        description: json['description']?.toString(),
        employeeName: json['employeeName']?.toString(),
        salaryPeriod: json['salaryPeriod']?.toString(),
        duration: json['duration']?.toString(),
      );
}

class MonthlyBreakdownItem {
  final int month;
  final String monthName;
  final double revenue;
  final double expenses;
  final double salaryExpenses;
  final double operatingExpenses;
  final double netProfit;

  MonthlyBreakdownItem({
    required this.month,
    required this.monthName,
    required this.revenue,
    required this.expenses,
    required this.salaryExpenses,
    required this.operatingExpenses,
    required this.netProfit,
  });

  factory MonthlyBreakdownItem.fromJson(Map<String, dynamic> json) =>
      MonthlyBreakdownItem(
        month: (json['month'] as num?)?.toInt() ?? 1,
        monthName: (json['monthName'] ?? '').toString(),
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
        expenses: (json['expenses'] as num?)?.toDouble() ?? 0.0,
        salaryExpenses: (json['salaryExpenses'] as num?)?.toDouble() ?? 0.0,
        operatingExpenses:
            (json['operatingExpenses'] as num?)?.toDouble() ?? 0.0,
        netProfit: (json['netProfit'] as num?)?.toDouble() ?? 0.0,
      );
}

class GlobalFinancials {
  final double allRevenue;
  final double allExpenses;
  final double globalNetProfit;

  GlobalFinancials({
    required this.allRevenue,
    required this.allExpenses,
    required this.globalNetProfit,
  });

  factory GlobalFinancials.fromJson(Map<String, dynamic> json) =>
      GlobalFinancials(
        allRevenue: (json['allRevenue'] as num?)?.toDouble() ?? 0.0,
        allExpenses: (json['allExpenses'] as num?)?.toDouble() ?? 0.0,
        globalNetProfit: (json['globalNetProfit'] as num?)?.toDouble() ?? 0.0,
      );
}

class ReportData {
  final String period;
  final String rangeStart;
  final String rangeEnd;
  final double revenue;
  final double expenses;
  final double operatingExpenses;
  final double employeeSalaries;
  final double netProfit;
  final double grossProfit;
  final double profitMargin;
  final int salesCount;
  final List<TopProduct> topProducts;
  final List<ExpenseCategoryItem> expensesByCategory;
  final List<EmployeeSalaryItem> employeeSalariesBreakdown;
  final RevenueBreakdown revenueBreakdown;
  final ExpensesBreakdown expensesBreakdown;
  final ActivitySummary activitySummary;
  final List<ReportTransaction> recentTransactions;
  final List<MonthlyBreakdownItem> monthlyBreakdown;

  // Global All-Time Financials (independent of period)
  final GlobalFinancials global;
  final double allRevenue;
  final double allExpenses;
  final double globalNetProfit;

  ReportData({
    required this.period,
    required this.rangeStart,
    required this.rangeEnd,
    required this.revenue,
    required this.expenses,
    required this.operatingExpenses,
    required this.employeeSalaries,
    required this.netProfit,
    required this.grossProfit,
    required this.profitMargin,
    required this.salesCount,
    required this.topProducts,
    required this.expensesByCategory,
    required this.employeeSalariesBreakdown,
    required this.revenueBreakdown,
    required this.expensesBreakdown,
    required this.activitySummary,
    required this.recentTransactions,
    this.monthlyBreakdown = const [],
    required this.global,
    required this.allRevenue,
    required this.allExpenses,
    required this.globalNetProfit,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    final revBreakdown = json['revenueBreakdown'] is Map<String, dynamic>
        ? RevenueBreakdown.fromJson(
            json['revenueBreakdown'] as Map<String, dynamic>)
        : RevenueBreakdown(
            sales: (json['revenue'] as num?)?.toDouble() ?? 0.0,
            creditPayments: 0.0,
            clinicRevenue: 0.0,
            restaurantRevenue: 0.0,
            totalRevenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
          );

    final expCatList = ((json['expensesByCategory'] as List?) ?? [])
        .map((e) => ExpenseCategoryItem.fromJson(e as Map<String, dynamic>))
        .toList();

    final empSalList = ((json['employeeSalariesBreakdown'] as List?) ?? [])
        .map((e) => EmployeeSalaryItem.fromJson(e as Map<String, dynamic>))
        .toList();

    final expBreakdown = json['expensesBreakdown'] is Map<String, dynamic>
        ? ExpensesBreakdown.fromJson(
            json['expensesBreakdown'] as Map<String, dynamic>)
        : ExpensesBreakdown(
            operatingExpenses:
                (json['operatingExpenses'] as num?)?.toDouble() ?? 0.0,
            employeeSalaries:
                (json['employeeSalaries'] as num?)?.toDouble() ?? 0.0,
            costOfGoodsSold:
                (json['costOfGoodsSold'] as num?)?.toDouble() ?? 0.0,
            totalExpenses: (json['expenses'] as num?)?.toDouble() ?? 0.0,
            byCategory: expCatList,
            byEmployee: empSalList,
          );

    final actSummary = json['activitySummary'] is Map<String, dynamic>
        ? ActivitySummary.fromJson(
            json['activitySummary'] as Map<String, dynamic>)
        : ActivitySummary(
            salesCount: (json['salesCount'] as num?)?.toInt() ?? 0,
            expensesCount: expCatList.length,
            employeesCount: empSalList.length,
            invoicesCount: 0,
          );

    final transactions = ((json['recentTransactions'] as List?) ?? [])
        .map((e) => ReportTransaction.fromJson(e as Map<String, dynamic>))
        .toList();

    final monthlyBreakdownItems = ((json['monthlyBreakdown'] as List?) ?? [])
        .map((e) => MonthlyBreakdownItem.fromJson(e as Map<String, dynamic>))
        .toList();

    final allRev = (json['allRevenue'] as num?)?.toDouble() ??
        (json['global'] is Map<String, dynamic>
            ? ((json['global']['allRevenue'] as num?)?.toDouble() ?? 0.0)
            : (json['revenue'] as num?)?.toDouble() ?? 0.0);

    final allExp = (json['allExpenses'] as num?)?.toDouble() ??
        (json['global'] is Map<String, dynamic>
            ? ((json['global']['allExpenses'] as num?)?.toDouble() ?? 0.0)
            : (json['expenses'] as num?)?.toDouble() ?? 0.0);

    final globalProfit = (json['globalNetProfit'] as num?)?.toDouble() ??
        (json['global'] is Map<String, dynamic>
            ? ((json['global']['globalNetProfit'] as num?)?.toDouble() ?? (allRev - allExp))
            : (allRev - allExp));

    final globalFin = json['global'] is Map<String, dynamic>
        ? GlobalFinancials.fromJson(json['global'] as Map<String, dynamic>)
        : GlobalFinancials(
            allRevenue: allRev,
            allExpenses: allExp,
            globalNetProfit: globalProfit,
          );

    return ReportData(
      period: (json['period'] ?? 'monthly').toString(),
      rangeStart: (json['rangeStart'] ?? '').toString(),
      rangeEnd: (json['rangeEnd'] ?? '').toString(),
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      expenses: (json['expenses'] as num?)?.toDouble() ?? 0.0,
      operatingExpenses: (json['operatingExpenses'] as num?)?.toDouble() ?? 0.0,
      employeeSalaries: (json['employeeSalaries'] as num?)?.toDouble() ?? 0.0,
      netProfit: (json['netProfit'] as num?)?.toDouble() ?? 0.0,
      grossProfit: (json['grossProfit'] as num?)?.toDouble() ?? 0.0,
      profitMargin: (json['profitMargin'] as num?)?.toDouble() ?? 0.0,
      salesCount: (json['salesCount'] as num?)?.toInt() ?? 0,
      topProducts: ((json['topProducts'] as List?) ?? [])
          .map((e) => TopProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
      expensesByCategory: expCatList,
      employeeSalariesBreakdown: empSalList,
      revenueBreakdown: revBreakdown,
      expensesBreakdown: expBreakdown,
      activitySummary: actSummary,
      recentTransactions: transactions,
      monthlyBreakdown: monthlyBreakdownItems,
      global: globalFin,
      allRevenue: allRev,
      allExpenses: allExp,
      globalNetProfit: globalProfit,
    );
  }
}
