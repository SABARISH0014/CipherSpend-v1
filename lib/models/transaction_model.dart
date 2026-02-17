class TransactionModel {
  final int? id;
  final String hash; // Unique SHA-256 Hash
  final String sender; // e.g., "HDFCBK"
  final String body; // Raw SMS body
  final double amount; // Parsed Amount
  final String category; // e.g., "Food", "Travel"
  final String type; // [NEW] e.g., "UPI", "Card", "ATM"
  final int timestamp; // Milliseconds since epoch

  TransactionModel({
    this.id,
    required this.hash,
    required this.sender,
    required this.body,
    required this.amount,
    required this.category,
    required this.type,
    required this.timestamp,
  });

  // Convert to Map for SQL Insert
  Map<String, dynamic> toMap() {
    return {
      'hash': hash,
      'sender': sender,
      'body': body,
      'amount': amount,
      'category': category,
      'type': type,
      'timestamp': timestamp,
    };
  }

  // Create Object from SQL Query
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      hash: map['hash'],
      sender: map['sender'],
      body: map['body'],
      amount: map['amount'],
      category: map['category'],
      type: map['type'] ?? 'Unknown',
      timestamp: map['timestamp'],
    );
  }
}
