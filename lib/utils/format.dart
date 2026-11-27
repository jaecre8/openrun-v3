String formatNumber(num n) {
  final isInt = n == n.roundToDouble();
  final s = isInt ? n.round().toString() : n.toStringAsFixed(2);
  final parts = s.split('.');
  final digits = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return parts.length > 1 ? '$digits.${parts[1]}' : digits;
}

String? formatPrice(num? price, String? currency) {
  if (price == null || currency == null) return null;
  if (price == 0) return '무료';
  switch (currency) {
    case 'KRW':
      return '${formatNumber(price)}원';
    case 'USD':
      return '\$${formatNumber(price)}';
    case 'JPY':
      return '¥${formatNumber(price)}';
    case 'EUR':
      return '€${formatNumber(price)}';
    case 'CNY':
      return '${formatNumber(price)}위안';
    default:
      return formatNumber(price);
  }
}

String timeAgo(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = n.difference(t);
  if (d.inMinutes < 1) return '방금';
  if (d.inMinutes < 60) return '${d.inMinutes}분 전';
  if (d.inHours < 24) return '${d.inHours}시간 전';
  if (d.inDays < 7) return '${d.inDays}일 전';
  return '${t.month}/${t.day}';
}

String formatCount(int n) {
  if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}만';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}천';
  return '$n';
}
