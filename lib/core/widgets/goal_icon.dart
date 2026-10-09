import 'package:flutter/material.dart';

import '../models/goal.dart';

IconData goalTypeIcon(GoalType type) => switch (type) {
  GoalType.car => Icons.directions_car_filled,
  GoalType.travel => Icons.flight_takeoff,
  GoalType.homeDownPayment => Icons.home_outlined,
  GoalType.emergencyFund => Icons.health_and_safety_outlined,
  GoalType.wedding => Icons.favorite_outline,
  GoalType.renovation => Icons.handyman_outlined,
  GoalType.digitalProduct => Icons.devices_outlined,
  GoalType.education => Icons.school_outlined,
  GoalType.childrenFamily => Icons.child_care_outlined,
  GoalType.healthcare => Icons.medical_services_outlined,
  GoalType.retirement => Icons.beach_access_outlined,
  GoalType.debtRepayment => Icons.receipt_long_outlined,
  GoalType.business => Icons.storefront_outlined,
  GoalType.caregiving => Icons.volunteer_activism_outlined,
  GoalType.giftCharity => Icons.redeem_outlined,
  GoalType.majorPurchase => Icons.shopping_bag_outlined,
  GoalType.custom => Icons.flag_outlined,
};
