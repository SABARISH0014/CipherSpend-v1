class TransactionModel {
  final String hash;
  final String sender;
  final String body;
  final double amount;
  final String category;
  final String type; // UPI, Card, etc.
  final String merchant; // [NEW] Zomato, Uber, etc.
  final int timestamp;

  TransactionModel({
    required this.hash,
    required this.sender,
    required this.body,
    required this.amount,
    required this.category,
    required this.type,
    this.merchant = "Unknown",
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'hash': hash,
      'sender': sender,
      'body': body,
      'amount': amount,
      'category': category,
      'type': type,
      'merchant': merchant,
      'timestamp': timestamp,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      hash: map['hash'],
      sender: map['sender'],
      body: map['body'],
      amount: map['amount'],
      category: map['category'],
      type: map['type'] ?? "Unknown",
      merchant: map['merchant'] ?? "Unknown",
      timestamp: map['timestamp'],
    );
  }
}
