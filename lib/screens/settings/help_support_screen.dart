import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wanderlens/services/support_service.dart';

import '../../responsive/constrained_scaffold.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    SupportService.markAsRead();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _controller.text;
    if (text.trim().isEmpty) return;

    setState(() => _sending = true);
    try {
      await SupportService.sendUserMessage(text);
      _controller.clear();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final uid = auth.FirebaseAuth.instance.currentUser?.uid;

    return ConstrainedScaffold(
      appBar: AppBar(
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: uid == null
          ? const Center(child: Text('Sign in to contact support.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Send us a message. Our team will reply here when your ticket is updated.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: SupportService.messagesStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        SupportService.markAsRead();
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No messages yet.\nDescribe your issue below and tap Send.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[docs.length - 1 - index].data();
                          return _MessageBubble(data: data, currentUserId: uid);
                        },
                      );
                    },
                  ),
                ),
                _buildComposer(colorScheme),
              ],
            ),
    );
  }

  Widget _buildComposer(ColorScheme colorScheme) {
    return Material(
      elevation: 8,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 4,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Type your message…',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.data,
    required this.currentUserId,
  });

  final Map<String, dynamic> data;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final role = (data['senderRole'] as String?) ?? 'user';
    final isUser = role == 'user';
    final senderId = data['senderId'] as String? ?? '';
    final senderName = data['senderName'] as String? ?? (isUser ? 'User' : 'WanderLens Support');
    final text = data['text'] as String? ?? '';
    final createdAtMs = data['createdAtMs'] as int?;
    final timeStr = createdAtMs != null
        ? DateFormat('MMM d, h:mm a').format(
            DateTime.fromMillisecondsSinceEpoch(createdAtMs),
          )
        : '';

    // Apna message hamesha 'user' role k sath hoga aur senderId match kregi
    final isMine = isUser && senderId == currentUserId;

    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final bg = isMine ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest;
    final fg = isMine ? colorScheme.onPrimaryContainer : colorScheme.onSurface;

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Card(
          color: bg,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      isUser ? senderName : 'WanderLens Support',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: fg.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                Text(text, style: TextStyle(color: fg, fontSize: 14, height: 1.35)),
                if (timeStr.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: fg.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
