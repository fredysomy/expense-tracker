import 'package:flutter/material.dart';

class IconHelper {
  static const Map<String, IconData> _icons = {
    // Food
    'restaurant': Icons.restaurant,
    'delivery_dining': Icons.delivery_dining,
    'shopping_cart': Icons.shopping_cart,
    'coffee': Icons.coffee,
    // Transport
    'directions_car': Icons.directions_car,
    'local_gas_station': Icons.local_gas_station,
    'local_taxi': Icons.local_taxi,
    'directions_bus': Icons.directions_bus,
    'two_wheeler': Icons.two_wheeler,
    // Shopping
    'shopping_bag': Icons.shopping_bag,
    'checkroom': Icons.checkroom,
    'phone_android': Icons.phone_android,
    // Bills
    'receipt_long': Icons.receipt_long,
    'bolt': Icons.bolt,
    'wifi': Icons.wifi,
    'phone': Icons.phone,
    'home': Icons.home,
    // Entertainment
    'movie': Icons.movie,
    'subscriptions': Icons.subscriptions,
    'sports_esports': Icons.sports_esports,
    // Health
    'local_hospital': Icons.local_hospital,
    'medication': Icons.medication,
    'medical_services': Icons.medical_services,
    'fitness_center': Icons.fitness_center,
    // Travel
    'flight': Icons.flight,
    'hotel': Icons.hotel,
    'luggage': Icons.luggage,
    // Finance
    'credit_card': Icons.credit_card,
    'account_balance_wallet': Icons.account_balance_wallet,
    'savings': Icons.savings,
    'trending_up': Icons.trending_up,
    'stars': Icons.stars,
    // Work
    'work': Icons.work,
    'business_center': Icons.business_center,
    // Other
    'replay': Icons.replay,
    'attach_money': Icons.attach_money,
    'school': Icons.school,
    'pets': Icons.pets,
    'child_care': Icons.child_care,
    'more_horiz': Icons.more_horiz,
  };

  static IconData getIcon(String name) =>
      _icons[name] ?? Icons.circle_outlined;

  static List<String> get allIconNames => _icons.keys.toList();
}
