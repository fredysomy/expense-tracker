import 'sms_transaction.dart';

class SmsParser {
  // Matches: Rs.1,234.56 / Rs 1234 / INR 1234.50 / ₹500 / rs.99/-
  static final RegExp _amountRegex = RegExp(
    r'(?:rs\.?\s*|inr\s*|₹\s*)(\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // Words that indicate money left the account
  static const _debitWords = [
    'debited', 'debit', ' dr ', '.dr.', 'dr-',
    'spent', 'paid to', 'payment of', 'purchase',
    'withdrawn', 'deducted', 'charged', 'otp',
    'one time password',
  ];

  // Words that indicate money came into the account
  static const _creditWords = [
    'credited', 'credit', ' cr ', '.cr.', 'cr-',
    'received', 'deposited', 'refund', 'cashback',
    'reversal',
  ];

  // Must contain at least one of these to be considered a transaction SMS
  static const _transactionKeywords = [
    'debited', 'credited', 'upi', 'imps', 'neft', 'rtgs',
    'transaction', 'txn', 'payment', 'purchase', 'withdrawn',
    'otp', 'one time password', 'a/c', 'acct', 'account',
    'credit card', 'debit card', 'net banking',
  ];

  // Noise words that end a merchant name
  static const _merchantStopWords =
      r'using|via|on|for|ref|with|your|thru|through|from|dated|a\/c|acct|towards|by';

  // Merchant extraction patterns (in priority order)
  static final _merchantPatterns = [
    // "at MERCHANT [WORD]..." — stops before noise words, periods, or end
    // e.g. "at Bigtree Enterta using" → "Bigtree Enterta"
    RegExp(
      r'\bat\s+([A-Za-z0-9][A-Za-z0-9\-\.&/]*(?:\s+(?!(?:' +
          _merchantStopWords +
          r')\b)[A-Za-z0-9\-\.&/]+){0,3})',
      caseSensitive: false,
    ),
    // "to VPA/merchant" for UPI (no spaces — handles UPI IDs like name@upi)
    RegExp(r'\bto\s+([A-Za-z0-9][A-Za-z0-9.\-_@]{3,40})(?=\s|[.,\n]|$)',
        caseSensitive: false),
    // "paid to NAME" or "sent to NAME" — up to 3 words
    RegExp(
      r'\b(?:paid|sent|transferred)\s+to\s+([A-Za-z0-9][A-Za-z0-9\-\.]*(?:\s+(?!(?:' +
          _merchantStopWords +
          r')\b)[A-Za-z0-9\-\.]+){0,2})',
      caseSensitive: false,
    ),
  ];

  /// Returns null if this SMS is not a financial transaction.
  static SmsTransaction? parse({
    required String smsId,
    required String body,
    required String sender,
    required DateTime receivedAt,
  }) {
    final lower = body.toLowerCase();

    // Must contain an amount
    final amountMatch = _amountRegex.firstMatch(lower);
    if (amountMatch == null) return null;

    // Must contain at least one transaction keyword
    final hasKeyword = _transactionKeywords.any((kw) => lower.contains(kw));
    if (!hasKeyword) return null;

    // Parse the amount (remove commas)
    final rawAmount = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(rawAmount);
    if (amount == null || amount <= 0) return null;

    // Determine debit vs credit
    final isDebit = _debitWords.any((w) => lower.contains(w));
    final isCredit = _creditWords.any((w) => lower.contains(w));

    // OTPs without explicit debit/credit are treated as debit (pending transaction)
    // Ambiguous → default to debit (expense)
    final debit = isDebit || (!isCredit);

    // Extract merchant
    String? merchant;
    for (final pattern in _merchantPatterns) {
      final m = pattern.firstMatch(body);
      if (m != null) {
        final raw = m.group(1)?.trim() ?? '';
        if (raw.length >= 3) {
          merchant = _cleanMerchant(raw);
          break;
        }
      }
    }

    // Tag OTP-triggered SMS so the review UI can flag them
    final isOtp = lower.contains('otp') || lower.contains('one time password');

    return SmsTransaction(
      smsId: smsId,
      body: body,
      amount: amount,
      merchant: merchant,
      isDebit: debit,
      isOtp: isOtp,
      receivedAt: receivedAt,
      sender: sender,
    );
  }

  static String _cleanMerchant(String raw) {
    // Remove trailing noise words
    var cleaned = raw
        .replaceAll(RegExp(r'\b(via|on|for|ref|upi|imps|neft)\b.*$',
            caseSensitive: false), '')
        .trim();
    // Trim trailing punctuation
    cleaned = cleaned.replaceAll(RegExp(r'[.,\-/]+$'), '').trim();
    return cleaned.isEmpty ? raw.trim() : cleaned;
  }
}
