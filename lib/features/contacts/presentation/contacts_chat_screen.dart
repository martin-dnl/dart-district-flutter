import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_colors.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/contacts_controller.dart';
import '../models/contact_models.dart';

class ContactsChatScreen extends ConsumerStatefulWidget {
  const ContactsChatScreen({super.key, required this.contact});

  final ContactModel contact;

  @override
  ConsumerState<ContactsChatScreen> createState() => _ContactsChatScreenState();
}

class _ContactsChatScreenState extends ConsumerState<ContactsChatScreen> {
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(contactsControllerProvider.notifier)
          .selectFriend(widget.contact);
    });
  }

  @override
  void dispose() {
    ref.read(contactsControllerProvider.notifier).clearSelectedFriend();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsControllerProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
    final selected = contacts.selectedFriend ?? widget.contact;
    final messages =
        contacts.messagesByContact[selected.id] ?? const <ContactMessage>[];

    return AppScaffold(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    selected.username,
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final msg = messages[messages.length - 1 - index];
                    final isMine = msg.fromUserId == currentUserId;
                    final time = DateFormat.Hm().format(
                      msg.createdAt.toLocal(),
                    );

                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        constraints: const BoxConstraints(maxWidth: 260),
                        decoration: BoxDecoration(
                          color: isMine
                              ? AppColors.primary.withValues(alpha: 0.95)
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              msg.content,
                              style: GoogleFonts.manrope(
                                color: isMine
                                    ? AppColors.background
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              time,
                              style: GoogleFonts.manrope(
                                color: isMine
                                    ? AppColors.background.withValues(
                                        alpha: 0.8,
                                      )
                                    : AppColors.textHint,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: GoogleFonts.manrope(
                            color: AppColors.textPrimary,
                          ),
                          minLines: 1,
                          maxLines: 4,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Votre message...',
                            hintStyle: GoogleFonts.manrope(
                              color: AppColors.textHint,
                            ),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: AppColors.stroke.withValues(alpha: 0.9),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: AppColors.stroke.withValues(alpha: 0.9),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppColors.ctaGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: AppColors.background,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text;
    ref.read(contactsControllerProvider.notifier).sendMessage(text);
    _messageController.clear();
  }
}
