import '../../../../l10n/app_localizations.dart';
/// Enterprise / Company specialized module domain models
/// (business-specialization brief Ch. 19). Same one-file convention as
/// the other verticals' `*_models.dart`.

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

enum EnterpriseProjectStatus {
  planned,
  active,
  onHold,
  completed,
  cancelled;

  /// Exact value the backend's `enterprise_project_status_enum` uses.
  String get apiValue => switch (this) {
        EnterpriseProjectStatus.planned => 'planned',
        EnterpriseProjectStatus.active => 'active',
        EnterpriseProjectStatus.onHold => 'on_hold',
        EnterpriseProjectStatus.completed => 'completed',
        EnterpriseProjectStatus.cancelled => 'cancelled',
      };

  String get label => switch (this) {
        EnterpriseProjectStatus.planned => 'Planned',
        EnterpriseProjectStatus.active => 'In progress',
        EnterpriseProjectStatus.onHold => 'On hold',
        EnterpriseProjectStatus.completed => 'Completed',
        EnterpriseProjectStatus.cancelled => 'Cancelled',
      };

  String localizedLabel(AppLocalizations l10n) => switch (this) {
        EnterpriseProjectStatus.planned => l10n.projectStatusPlanned,
        EnterpriseProjectStatus.active => l10n.projectStatusInProgress,
        EnterpriseProjectStatus.onHold => l10n.projectStatusOnHold,
        EnterpriseProjectStatus.completed => l10n.projectStatusCompleted,
        EnterpriseProjectStatus.cancelled => l10n.projectStatusCancelled,
      };

  bool get isOpen =>
      this == EnterpriseProjectStatus.planned ||
      this == EnterpriseProjectStatus.active ||
      this == EnterpriseProjectStatus.onHold;

  static EnterpriseProjectStatus fromApi(String? value) => switch (value) {
        'active' => EnterpriseProjectStatus.active,
        'on_hold' => EnterpriseProjectStatus.onHold,
        'completed' => EnterpriseProjectStatus.completed,
        'cancelled' => EnterpriseProjectStatus.cancelled,
        _ => EnterpriseProjectStatus.planned,
      };
}

class EnterpriseProject {
  EnterpriseProject({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    this.budget,
    this.startDate,
    this.dueDate,
    this.customerId,
    this.customerName,
    required this.isOverdue,
  });

  final String id;
  final String name;
  final String? description;
  final EnterpriseProjectStatus status;
  final double? budget;

  /// `YYYY-MM-DD` strings straight from the backend (no timezone shift).
  final String? startDate;
  final String? dueDate;
  final String? customerId;
  final String? customerName;
  final bool isOverdue;

  factory EnterpriseProject.fromJson(Map<String, dynamic> json) => EnterpriseProject(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        status: EnterpriseProjectStatus.fromApi(json['status'] as String?),
        budget: json['budget'] == null ? null : _toDouble(json['budget']),
        startDate: json['start_date'] as String?,
        dueDate: json['due_date'] as String?,
        customerId: json['customer_id'] as String?,
        customerName: json['customer_name'] as String?,
        isOverdue: json['is_overdue'] == true,
      );
}

class EnterpriseUnpaidInvoice {
  EnterpriseUnpaidInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.total,
    this.customerName,
    this.soldAt,
  });

  final String id;
  final String invoiceNumber;
  final double total;
  final String? customerName;
  final DateTime? soldAt;

  factory EnterpriseUnpaidInvoice.fromJson(Map<String, dynamic> json) => EnterpriseUnpaidInvoice(
        id: json['id'] as String,
        invoiceNumber: (json['invoice_number'] as String?) ?? '',
        total: _toDouble(json['total']),
        customerName: json['customer_name'] as String?,
        soldAt: json['sold_at'] == null ? null : DateTime.tryParse(json['sold_at'].toString())?.toLocal(),
      );
}

class EnterpriseProjectSummary {
  EnterpriseProjectSummary({
    required this.planned,
    required this.active,
    required this.onHold,
    required this.completed,
    required this.cancelled,
    required this.overdue,
    required this.total,
  });

  final int planned;
  final int active;
  final int onHold;
  final int completed;
  final int cancelled;
  final int overdue;
  final int total;

  /// Planned + in progress + on hold — what "open projects" means on
  /// the dashboard.
  int get open => planned + active + onHold;

  factory EnterpriseProjectSummary.fromJson(Map<String, dynamic> json) => EnterpriseProjectSummary(
        planned: (json['planned'] as num?)?.toInt() ?? 0,
        active: (json['active'] as num?)?.toInt() ?? 0,
        onHold: (json['onHold'] as num?)?.toInt() ?? 0,
        completed: (json['completed'] as num?)?.toInt() ?? 0,
        cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
        overdue: (json['overdue'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
}

class EnterpriseDashboardStats {
  EnterpriseDashboardStats({
    required this.todayRevenue,
    required this.todayExpenses,
    required this.todayNetProfit,
    required this.weekRevenue,
    required this.monthRevenue,
    required this.monthExpenses,
    required this.monthOperatingExpenses,
    required this.monthPayroll,
    required this.monthNetProfit,
    required this.unpaidInvoicesCount,
    required this.unpaidInvoicesAmount,
    required this.unpaidInvoices,
    required this.clientBalancesOutstanding,
    required this.clientsCount,
    required this.employeesCount,
    required this.suppliersCount,
    required this.projects,
    required this.openProjects,
  });

  /// Revenue = invoiced sales + credit payments received; expenses =
  /// operating expenses + payroll; profit = revenue - expenses — the
  /// same formula as the CORE dashboard (see enterprise.service.js).
  final double todayRevenue;
  final double todayExpenses;
  final double todayNetProfit;
  final double weekRevenue;
  final double monthRevenue;
  final double monthExpenses;

  /// Expenses EXCLUDING payroll (`monthExpenses` = this + `monthPayroll`).
  final double monthOperatingExpenses;
  final double monthPayroll;
  final double monthNetProfit;
  final int unpaidInvoicesCount;
  final double unpaidInvoicesAmount;
  final List<EnterpriseUnpaidInvoice> unpaidInvoices;
  final double clientBalancesOutstanding;
  final int clientsCount;
  final int employeesCount;
  final int suppliersCount;
  final EnterpriseProjectSummary projects;
  final List<EnterpriseProject> openProjects;

  static final empty = EnterpriseDashboardStats(
    todayRevenue: 0,
    todayExpenses: 0,
    todayNetProfit: 0,
    weekRevenue: 0,
    monthRevenue: 0,
    monthExpenses: 0,
    monthOperatingExpenses: 0,
    monthPayroll: 0,
    monthNetProfit: 0,
    unpaidInvoicesCount: 0,
    unpaidInvoicesAmount: 0,
    unpaidInvoices: const [],
    clientBalancesOutstanding: 0,
    clientsCount: 0,
    employeesCount: 0,
    suppliersCount: 0,
    projects: EnterpriseProjectSummary(
      planned: 0,
      active: 0,
      onHold: 0,
      completed: 0,
      cancelled: 0,
      overdue: 0,
      total: 0,
    ),
    openProjects: const [],
  );

  factory EnterpriseDashboardStats.fromJson(Map<String, dynamic> json) => EnterpriseDashboardStats(
        todayRevenue: _toDouble(json['todayRevenue']),
        todayExpenses: _toDouble(json['todayExpenses']),
        todayNetProfit: _toDouble(json['todayNetProfit']),
        weekRevenue: _toDouble(json['weekRevenue']),
        monthRevenue: _toDouble(json['monthRevenue']),
        monthExpenses: _toDouble(json['monthExpenses']),
        monthOperatingExpenses: _toDouble(json['monthOperatingExpenses']),
        monthPayroll: _toDouble(json['monthPayroll']),
        monthNetProfit: _toDouble(json['monthNetProfit']),
        unpaidInvoicesCount: (json['unpaidInvoicesCount'] as num?)?.toInt() ?? 0,
        unpaidInvoicesAmount: _toDouble(json['unpaidInvoicesAmount']),
        unpaidInvoices: (json['unpaidInvoices'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(EnterpriseUnpaidInvoice.fromJson)
            .toList(),
        clientBalancesOutstanding: _toDouble(json['clientBalancesOutstanding']),
        clientsCount: (json['clientsCount'] as num?)?.toInt() ?? 0,
        employeesCount: (json['employeesCount'] as num?)?.toInt() ?? 0,
        suppliersCount: (json['suppliersCount'] as num?)?.toInt() ?? 0,
        projects: EnterpriseProjectSummary.fromJson(
          (json['projects'] as Map<String, dynamic>?) ?? const {},
        ),
        openProjects: (json['openProjects'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(EnterpriseProject.fromJson)
            .toList(),
      );
}
