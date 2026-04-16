class SmsTransaction {
  final String smsId;
  final String body;
  final double amount;
  final String? merchant;
  final bool isDebit;
  final bool isOtp;
  final DateTime receivedAt;
  final String sender;

  const SmsTransaction({
    required this.smsId,
    required this.body,
    required this.amount,
    this.merchant,
    required this.isDebit,
    this.isOtp = false,
    required this.receivedAt,
    required this.sender,
  });
}
