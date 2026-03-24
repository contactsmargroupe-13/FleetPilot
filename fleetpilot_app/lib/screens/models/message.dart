class Message {
  final String id;

  /// 'manager' ou nom du chauffeur
  final String senderName;

  /// 'manager' ou nom du chauffeur
  final String receiverName;

  final String content;
  final DateTime date;
  final bool read;

  const Message({
    required this.id,
    required this.senderName,
    required this.receiverName,
    required this.content,
    required this.date,
    this.read = false,
  });

  /// Identifiant de conversation (toujours le nom du chauffeur)
  String get conversationId {
    if (senderName == 'manager') return receiverName;
    return senderName;
  }

  bool get isFromManager => senderName == 'manager';

  Message copyWith({bool? read}) => Message(
        id: id,
        senderName: senderName,
        receiverName: receiverName,
        content: content,
        date: date,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderName': senderName,
        'receiverName': receiverName,
        'content': content,
        'date': date.toIso8601String(),
        'read': read,
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        senderName: json['senderName'] as String,
        receiverName: json['receiverName'] as String,
        content: json['content'] as String,
        date: DateTime.parse(json['date'] as String),
        read: json['read'] as bool? ?? false,
      );
}
