enum GoalStatus { active, completed, paused, archived }

enum GoalType {
  car,
  travel,
  homeDownPayment,
  emergencyFund,
  wedding,
  renovation,
  digitalProduct,
  education,
  childrenFamily,
  healthcare,
  retirement,
  debtRepayment,
  business,
  caregiving,
  giftCharity,
  majorPurchase,
  custom,
}

enum GoalContributionType { deposit, withdraw, adjustment }

class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.icon,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.status,
    required this.createdAt,
    required this.milestones,
    this.goalType = GoalType.custom,
    DateTime? updatedAt,
    this.description,
    this.coverPath,
    this.completionCelebrationShown = false,
    this.contributions = const [],
    this.bookId = 'book-personal',
    this.version = 1,
    this.sortOrder = 0,
    this.monthlyReservation = 0,
    this.createdBy,
    this.updatedBy,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;
  final String name;
  final GoalType goalType;
  final String icon;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final GoalStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<GoalMilestone> milestones;
  final String? description;
  final String? coverPath;
  final bool completionCelebrationShown;
  final List<GoalContribution> contributions;
  final String bookId;
  final int version;
  final int sortOrder;
  final double monthlyReservation;
  final String? createdBy;
  final String? updatedBy;

  double get progress => (currentAmount / targetAmount).clamp(0, 1);
  int get progressPercent => (progress * 100).floor();
}

class GoalMilestone {
  const GoalMilestone({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.title,
    required this.order,
    required this.isCompleted,
    this.completedAt,
    this.celebrationShown = false,
  });

  final String id;
  final String goalId;
  final double amount;
  final String title;
  final int order;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool celebrationShown;
}

class GoalContribution {
  const GoalContribution({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.type,
    required this.createdAt,
    this.sourceTransactionId,
    this.note,
    this.contributorUserId,
  });

  final String id;
  final String goalId;
  final double amount;
  final GoalContributionType type;
  final String? sourceTransactionId;
  final DateTime createdAt;
  final String? note;
  final String? contributorUserId;
}

class GoalForecast {
  const GoalForecast({
    required this.windowDays,
    required this.averageDailyDeposit,
    required this.estimatedCompletionDate,
  });

  final int windowDays;
  final double averageDailyDeposit;
  final DateTime? estimatedCompletionDate;
}

extension GoalTypePresentation on GoalType {
  String get label => switch (this) {
    GoalType.car => '买车',
    GoalType.travel => '旅行',
    GoalType.homeDownPayment => '买房首付',
    GoalType.emergencyFund => '应急金',
    GoalType.wedding => '结婚',
    GoalType.renovation => '装修',
    GoalType.digitalProduct => '数码产品',
    GoalType.education => '教育',
    GoalType.childrenFamily => '育儿与家庭',
    GoalType.healthcare => '医疗健康',
    GoalType.retirement => '退休养老',
    GoalType.debtRepayment => '偿还债务',
    GoalType.business => '创业经营',
    GoalType.caregiving => '赡养照护',
    GoalType.giftCharity => '礼物与公益',
    GoalType.majorPurchase => '大额购置',
    GoalType.custom => '自定义',
  };
}
