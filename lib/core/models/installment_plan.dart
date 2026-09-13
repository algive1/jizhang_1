enum InstallmentPlanStatus { active, completed, canceled }

class InstallmentPlan {
  const InstallmentPlan({
    required this.id,
    required this.bookId,
    required this.name,
    required this.originalTransactionId,
    required this.totalAmount,
    required this.totalPeriods,
    required this.currentPeriod,
    required this.principalPerPeriod,
    required this.feePerPeriod,
    required this.startDate,
    required this.dueDay,
    required this.creditAccountId,
    required this.repaymentAccountId,
    required this.remainingPrincipal,
    this.status = InstallmentPlanStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String bookId;
  final String name;
  final String originalTransactionId;
  final double totalAmount;
  final int totalPeriods;
  final int currentPeriod;
  final double principalPerPeriod;
  final double feePerPeriod;
  final DateTime startDate;
  final int dueDay;
  final String creditAccountId;
  final String repaymentAccountId;
  final double remainingPrincipal;
  final InstallmentPlanStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get monthlyPayment => principalPerPeriod + feePerPeriod;
}
