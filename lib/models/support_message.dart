class SupportMessage {
  final int id;
  final String subject;
  final String message;
  final String status; // 'pending' or 'replied'
  final DateTime createdAt;
  final String? reply;
  final DateTime? repliedAt;

  const SupportMessage({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    this.reply,
    this.repliedAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'] as int? ?? 0,
      subject: json['subject']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      reply: json['reply']?.toString(),
      repliedAt: json['replied_at'] != null
          ? DateTime.tryParse(json['replied_at'].toString())
          : null,
    );
  }
}
