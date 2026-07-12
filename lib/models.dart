enum SmsCategory { personal, otp, transaction, promotion }

SmsCategory categoryFromString(String? s) => switch (s) {
      'otp' => SmsCategory.otp,
      'transaction' => SmsCategory.transaction,
      'promotion' => SmsCategory.promotion,
      _ => SmsCategory.personal,
    };

String categoryToString(SmsCategory c) => switch (c) {
      SmsCategory.otp => 'otp',
      SmsCategory.transaction => 'transaction',
      SmsCategory.promotion => 'promotion',
      SmsCategory.personal => 'personal',
    };

class Conversation {
  final int threadId;
  final String address;
  final String displayName;
  final bool isContact;
  final String snippet;
  final DateTime date;
  final int unread;
  final SmsCategory category;

  Conversation({
    required this.threadId,
    required this.address,
    required this.displayName,
    required this.isContact,
    required this.snippet,
    required this.date,
    required this.unread,
    required this.category,
  });

  factory Conversation.fromMap(Map<dynamic, dynamic> m) => Conversation(
        threadId: (m['threadId'] as num).toInt(),
        address: m['address'] as String? ?? '',
        displayName: m['displayName'] as String? ?? '',
        isContact: m['isContact'] as bool? ?? false,
        snippet: m['snippet'] as String? ?? '',
        date: DateTime.fromMillisecondsSinceEpoch((m['date'] as num?)?.toInt() ?? 0),
        unread: (m['unread'] as num?)?.toInt() ?? 0,
        category: categoryFromString(m['category'] as String?),
      );
}

class Message {
  final int id;
  final String address;
  final String body;
  final DateTime date;
  final bool isIncoming;
  final String? otp;

  Message({
    required this.id,
    required this.address,
    required this.body,
    required this.date,
    required this.isIncoming,
    this.otp,
  });

  factory Message.fromMap(Map<dynamic, dynamic> m) => Message(
        id: (m['id'] as num).toInt(),
        address: m['address'] as String? ?? '',
        body: m['body'] as String? ?? '',
        date: DateTime.fromMillisecondsSinceEpoch((m['date'] as num?)?.toInt() ?? 0),
        isIncoming: m['isIncoming'] as bool? ?? true,
        otp: m['otp'] as String?,
      );
}
