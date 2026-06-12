import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/support_message.dart';
import '../services/support_service.dart';
import '../services/api_client.dart'; // for SessionExpiredException
import '../services/theme_service.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';
import 'login_page.dart';

class ChatBubble {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isSending;

  ChatBubble({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isSending = false,
  });
}

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _supportService = SupportService();
  final _inputCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<SupportMessage> _messages = [];
  bool _loadingInitial = true;
  bool _isSubmitting = false;
  String _pendingMessageText = '';
  String? _error;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _inputCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _error = null;
    });

    try {
      final list = await _supportService.getMessages(page: 1, pageSize: 50);
      if (!mounted) return;

      setState(() {
        _messages = list;
        _loadingInitial = false;
      });
      _scrollToBottom(animate: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingInitial = false;
        if (e is SessionExpiredException) {
          showSessionExpiredDialog(context, const LoginPage());
        } else {
          _error = e.toString().replaceFirst('Exception: ', '');
        }
      });
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _fetchUpdates();
    });
  }

  Future<void> _fetchUpdates() async {
    if (_isSubmitting || _loadingInitial) return;

    try {
      final updatedList = await _supportService.getMessages(page: 1, pageSize: 50);
      if (!mounted) return;

      // Check if the messages list has changed
      bool hasChanges = updatedList.length != _messages.length;
      if (!hasChanges) {
        for (int i = 0; i < updatedList.length; i++) {
          if (updatedList[i].id != _messages[i].id ||
              updatedList[i].status != _messages[i].status ||
              updatedList[i].reply != _messages[i].reply) {
            hasChanges = true;
            break;
          }
        }
      }

      if (hasChanges) {
        final wasAtBottom = _isAtBottom();
        setState(() {
          _messages = updatedList;
        });

        if (wasAtBottom) {
          _scrollToBottom();
        }
      }
    } catch (_) {
      // Fail silently on background poll errors to keep user experience smooth
    }
  }

  bool _isAtBottom() {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.pixels >= pos.maxScrollExtent - 100;
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();

    setState(() {
      _isSubmitting = true;
      _pendingMessageText = text;
      _error = null;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    // Generate subject based on first words of the message
    final words = text.split(RegExp(r'\s+'));
    final subject = words.take(5).join(' ') + (words.length > 5 ? '...' : '');

    try {
      final newTicket = await _supportService.submitMessage(subject, text);
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _messages.insert(0, newTicket); // Add new ticket to local list
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _inputCtrl.text = text; // Restore text on error
        if (e is SessionExpiredException) {
          showSessionExpiredDialog(context, const LoginPage());
        } else {
          _error = e.toString().replaceFirst('Exception: ', '');
        }
      });
    }
  }

  List<ChatBubble> get _chatBubbles {
    final list = <ChatBubble>[];
    // Backend returns messages sorted newest first; we process them to build chronological order
    for (final msg in _messages) {
      list.add(ChatBubble(
        text: msg.message,
        isUser: true,
        timestamp: msg.createdAt,
      ));
      if (msg.status == 'replied' && msg.reply != null) {
        list.add(ChatBubble(
          text: msg.reply!,
          isUser: false,
          timestamp: msg.repliedAt ?? msg.createdAt,
        ));
      }
    }
    // Sort oldest first so it reads as a direct thread top-to-bottom
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Append pending/sending bubble at the very end
    if (_isSubmitting) {
      list.add(ChatBubble(
        text: _pendingMessageText,
        isUser: true,
        timestamp: DateTime.now(),
        isSending: true,
      ));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, _, __) {
        final textTheme = Theme.of(context).textTheme;
        final bubbles = _chatBubbles;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderSoft),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            leadingWidth: 64,
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Support Chat',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Online Refreshing',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: Stack(
              children: [
                // Ambient design background
                Positioned(
                  top: -90,
                  right: -50,
                  child: IgnorePointer(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.08),
                            AppColors.primary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 100,
                  left: -60,
                  child: IgnorePointer(
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.accent.withValues(alpha: 0.05),
                            AppColors.accent.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    // Chat messages list
                    Expanded(
                      child: _loadingInitial
                          ? Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )
                          : bubbles.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 40),
                                  child: AnimatedEmptyState(
                                    icon: Icons.forum_outlined,
                                    title: 'Start the Conversation',
                                    subtitle: 'Send a message below to connect with support. Our administrators will reply directly in this chat thread.',
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                                  itemCount: bubbles.length,
                                  itemBuilder: (context, index) {
                                    final bubble = bubbles[index];
                                    final showDateDivider = index == 0 ||
                                        !_isSameDay(bubbles[index - 1].timestamp, bubble.timestamp);

                                    return Column(
                                      children: [
                                        if (showDateDivider)
                                          _buildDateDivider(bubble.timestamp),
                                        _buildBubbleRow(bubble, index),
                                      ],
                                    );
                                  },
                                ),
                    ),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ErrorBanner(
                          message: _error!,
                          onRetry: _loadInitial,
                        ),
                      ),

                    // Bottom chat input area
                    _buildInputBar(),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    final d1 = date1.toLocal();
    final d2 = date2.toLocal();
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  Widget _buildDateDivider(DateTime timestamp) {
    final local = timestamp.toLocal();
    final now = DateTime.now();
    String text;

    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      text = 'Today';
    } else if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.subtract(const Duration(days: 1)).day) {
      text = 'Yesterday';
    } else {
      text = DateFormat('MMMM d, yyyy').format(local);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.borderSoft)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.borderSoft)),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _buildBubbleRow(ChatBubble bubble, int index) {
    final isUser = bubble.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              margin: EdgeInsets.only(
                left: isUser ? 50 : 0,
                right: isUser ? 0 : 50,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser ? AppColors.primaryGradient : null,
                color: isUser ? null : AppColors.surfaceSoft,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: isUser
                    ? null
                    : Border.all(color: AppColors.borderSoft),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bubble.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('h:mm a').format(bubble.timestamp.toLocal()),
                        style: TextStyle(
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.70)
                              : AppColors.textMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (bubble.isSending) ...[
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 8,
                          height: 8,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.2,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 250.ms)
        .slideY(begin: 0.08, end: 0, duration: 250.ms, curve: Curves.easeOut);
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderSoft),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              maxLines: 4,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _isSubmitting ? null : _sendMessage(),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Type a support message...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                fillColor: AppColors.surfaceSoft,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.borderSoft),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.primary, width: 1.2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isSubmitting ? null : _sendMessage,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.24),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
