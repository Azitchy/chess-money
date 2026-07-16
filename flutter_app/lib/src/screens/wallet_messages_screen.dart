import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_colors.dart';
import '../dashboard_widgets.dart';
import '../services/api_client.dart';
import '../wallet_conversation.dart';

class WalletMessagesScreen extends StatefulWidget {
  const WalletMessagesScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<WalletMessagesScreen> createState() => _WalletMessagesScreenState();
}

class _WalletMessagesScreenState extends State<WalletMessagesScreen> {
  final _requestAmount = TextEditingController();
  final _requestBody = TextEditingController();
  final _replyBody = TextEditingController();
  final _imagePicker = ImagePicker();

  Timer? _poller;
  List<WalletConversation> _conversations = const [];
  WalletConversation? _selectedConversation;
  bool _sendingRequest = false;
  bool _sendingReply = false;
  String? _error;
  Uint8List? _requestAttachmentBytes;
  String? _requestAttachmentName;
  Uint8List? _replyAttachmentBytes;
  String? _replyAttachmentName;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _poller = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _poller?.cancel();
    _requestAmount.dispose();
    _requestBody.dispose();
    _replyBody.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text(
          'Wallet Messages',
          style: TextStyle(
            color: AppColors.heading,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: AppColors.blue,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            const _IntroCard(),
            const SizedBox(height: 14),
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: 14),
            ],
            _buildNewRequestCard(),
            const SizedBox(height: 14),
            _buildConversationList(),
            const SizedBox(height: 14),
            if (_selectedConversation != null) _buildThreadCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildNewRequestCard() {
    return SectionCard(
      title: 'Start a wallet request',
      icon: Icons.request_page_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardInputField(
            controller: _requestAmount,
            label: 'Amount',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _requestBody,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Message',
              filled: true,
              fillColor: const Color(0xFFF7FAFF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFDCE9FF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFDCE9FF)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AttachmentBar(
            attachmentName: _requestAttachmentName,
            onGallery: _pickRequestAttachment,
            onCamera: () => _pickRequestAttachment(source: ImageSource.camera),
            onClear: () => setState(() {
              _requestAttachmentBytes = null;
              _requestAttachmentName = null;
            }),
          ),
          const SizedBox(height: 14),
          PrimaryActionButton(
            label: _sendingRequest ? 'Sending...' : 'Send to admin',
            onPressed: _sendingRequest ? () {} : _sendRequest,
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    return SectionCard(
      title: 'Conversations',
      icon: Icons.chat_bubble_outline_rounded,
      child: Column(
        children: _conversations.isEmpty
            ? const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No wallet messages yet.'),
                ),
              ]
            : _conversations.map((conversation) {
                final selected = _selectedConversation?.id == conversation.id;
                final latest = conversation.latestMessage;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _selectConversation(conversation.id),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFF7FAFF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected
                              ? AppColors.blue
                              : const Color(0xFFDDE9FF),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.blue, AppColors.lavender],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  conversation.subject,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.heading,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Amount: ${conversation.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.mutedText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _StatusChip(
                                      label: conversation.status.toUpperCase(),
                                      background:
                                          conversation.status == 'approved'
                                          ? const Color(0xFFE8FFF2)
                                          : conversation.status == 'rejected'
                                          ? const Color(0xFFFFEEF0)
                                          : const Color(0xFFFFF4E5),
                                      foreground:
                                          conversation.status == 'approved'
                                          ? const Color(0xFF16794C)
                                          : conversation.status == 'rejected'
                                          ? const Color(0xFFB42318)
                                          : const Color(0xFFB45309),
                                    ),
                                    if (latest != null)
                                      _StatusChip(
                                        label: _preview(latest.body),
                                        background: const Color(0xFFEFF6FF),
                                        foreground: const Color(0xFF355C9A),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.arrow_forward_ios_rounded,
                            size: 18,
                            color: selected
                                ? AppColors.blue
                                : AppColors.mutedText,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
      ),
    );
  }

  Widget _buildThreadCard() {
    final conversation = _selectedConversation!;
    final compact = MediaQuery.sizeOf(context).width < 390;
    return SectionCard(
      title: 'Conversation #${conversation.id}',
      icon: Icons.forum_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Status: ${conversation.status.toUpperCase()}',
            style: const TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...conversation.messages.map(
            (message) => _buildMessageBubble(message, compact: compact),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _replyBody,
            minLines: compact ? 2 : 3,
            maxLines: compact ? 4 : 5,
            style: const TextStyle(fontSize: 14, height: 1.25),
            decoration: InputDecoration(
              labelText: 'Reply to admin',
              filled: true,
              fillColor: const Color(0xFFF7FAFF),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 14,
                vertical: compact ? 10 : 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFDCE9FF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFDCE9FF)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AttachmentBar(
            attachmentName: _replyAttachmentName,
            onGallery: _pickReplyAttachment,
            onCamera: () => _pickReplyAttachment(source: ImageSource.camera),
            onClear: () => setState(() {
              _replyAttachmentBytes = null;
              _replyAttachmentName = null;
            }),
          ),
          const SizedBox(height: 14),
          PrimaryActionButton(
            label: _sendingReply ? 'Sending...' : 'Send reply',
            onPressed: _sendingReply ? () {} : _sendReply,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(WalletMessage message, {required bool compact}) {
    final isUser = message.senderRole == 'user';
    final isAdmin = message.senderRole == 'admin';
    final background = isUser
        ? const Color(0xFFEFF6FF)
        : isAdmin
        ? const Color(0xFFE8FFF2)
        : const Color(0xFFF8FAFC);
    final textColor = isAdmin
        ? const Color(0xFF16794C)
        : const Color(0xFF334155);
    final horizontalPadding = compact ? 11.0 : 14.0;
    final verticalPadding = compact ? 10.0 : 12.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE9FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUser
                ? 'You'
                : isAdmin
                ? 'Admin'
                : 'System',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 13 : 14,
            ),
          ),
          const SizedBox(height: 5),
          if (message.body.trim().isNotEmpty)
            Text(
              message.body,
              style: TextStyle(
                height: 1.25,
                fontSize: compact ? 13 : 14,
                color: AppColors.heading,
              ),
            ),
          if (message.hasAttachment) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                message.attachmentUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: compact ? 96 : 120,
                  color: const Color(0xFFF1F5F9),
                  alignment: Alignment.center,
                  child: const Text(
                    'Attachment unavailable',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            message.createdAt == null ? '' : _formatDate(message.createdAt!),
            style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _loadConversations({bool preserveSelection = true}) async {
    setState(() {
      _error = null;
    });

    try {
      final conversations = await widget.apiClient.getWalletConversations();
      if (!mounted) return;
      final selectedId = preserveSelection ? _selectedConversation?.id : null;
      setState(() {
        _conversations = conversations;
      });

      if (conversations.isEmpty) {
        setState(() => _selectedConversation = null);
      } else {
        final nextSelectedId =
            selectedId != null &&
                conversations.any(
                  (conversation) => conversation.id == selectedId,
                )
            ? selectedId
            : conversations.first.id;
        await _selectConversation(nextSelectedId);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyAppErrorMessage(error));
      }
    }
  }

  Future<void> _refresh() async {
    await _loadConversations();
  }

  Future<void> _selectConversation(int conversationId) async {
    try {
      final detail = await widget.apiClient.getWalletConversation(
        conversationId,
      );
      if (!mounted) return;
      setState(() {
        _selectedConversation = detail;
        _replyBody.clear();
        _replyAttachmentBytes = null;
        _replyAttachmentName = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyAppErrorMessage(error));
      }
    }
  }

  Future<void> _sendRequest() async {
    if (_sendingRequest) return;
    final amount = double.tryParse(_requestAmount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }

    setState(() {
      _sendingRequest = true;
      _error = null;
    });

    try {
      final conversation = await widget.apiClient.createWalletConversation(
        amount: amount,
        body: _requestBody.text.trim(),
        attachmentBytes: _requestAttachmentBytes,
        attachmentFilename: _requestAttachmentName,
      );
      if (!mounted) return;
      setState(() {
        _requestAmount.clear();
        _requestBody.clear();
        _requestAttachmentBytes = null;
        _requestAttachmentName = null;
        _conversations = [conversation, ..._conversations];
        _selectedConversation = conversation;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message sent to admin')));
      await _loadConversations();
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyAppErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _sendingRequest = false);
      }
    }
  }

  Future<void> _sendReply() async {
    final conversation = _selectedConversation;
    if (_sendingReply || conversation == null) return;

    final body = _replyBody.text.trim();
    if (body.isEmpty && _replyAttachmentBytes == null) {
      setState(() => _error = 'Write a message or attach a photo.');
      return;
    }

    setState(() {
      _sendingReply = true;
      _error = null;
    });

    try {
      final updated = await widget.apiClient.sendWalletConversationMessage(
        conversation.id,
        body: body.isEmpty ? null : body,
        attachmentBytes: _replyAttachmentBytes,
        attachmentFilename: _replyAttachmentName,
      );
      if (!mounted) return;
      setState(() {
        _selectedConversation = updated;
        _replyBody.clear();
        _replyAttachmentBytes = null;
        _replyAttachmentName = null;
      });
      await _loadConversations();
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyAppErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _sendingReply = false);
      }
    }
  }

  Future<void> _pickRequestAttachment({
    ImageSource source = ImageSource.gallery,
  }) async {
    final image = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _requestAttachmentBytes = bytes;
      _requestAttachmentName = image.name;
    });
  }

  Future<void> _pickReplyAttachment({
    ImageSource source = ImageSource.gallery,
  }) async {
    final image = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _replyAttachmentBytes = bytes;
      _replyAttachmentName = image.name;
    });
  }

  String _preview(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Attachment only';
    return trimmed.length > 44 ? '${trimmed.substring(0, 44)}...' : trimmed;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF61B6FF), Color(0xFF7B74F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Text(
        'Send funding requests as messages, keep the thread open, and let admin reply right here. You can attach a photo from gallery or camera.',
        style: TextStyle(
          color: Colors.white,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AttachmentBar extends StatelessWidget {
  const _AttachmentBar({
    required this.attachmentName,
    required this.onGallery,
    required this.onCamera,
    required this.onClear,
  });

  final String? attachmentName;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        MiniActionButton(label: 'Gallery', onPressed: onGallery),
        MiniActionButton(label: 'Camera', onPressed: onCamera),
        if (attachmentName != null)
          Chip(
            label: Text(attachmentName!),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: onClear,
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
