import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/ai/ai_assistant_service.dart';
import '../../core/ai/ai_models.dart';
import '../../core/ai/ai_settings_controller.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/state_views.dart';
import '../settings/ai_settings_page.dart';

/// P0 AI 助手：只读对话与数据快照，不直接写业务数据。
class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() => _error = null);
    try {
      await context.read<AiAssistantService>().send(text);
    } on AiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const AiSettingsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final AiSettingsController settings = context.watch<AiSettingsController>();
    final AiAssistantService service = context.watch<AiAssistantService>();
    final AppPalette palette = context.palette;

    if (!settings.isConfigured) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: <Widget>[
            const Expanded(
              child: EmptyState(
                icon: Icons.auto_awesome_outlined,
                title: '先配置 AI 助手',
                description: '填写 OpenAI 兼容的服务地址、模型与 API Key，即可开始对话。',
              ),
            ),
            AppPrimaryButton(label: '去设置', onPressed: _openSettings),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_awesome_rounded, size: 18, color: palette.accent),
              const SizedBox(width: 6),
              Text(settings.model, style: context.texts.titleSmall),
              const Spacer(),
              AppGhostButton(
                label: '设置',
                dense: true,
                onPressed: _openSettings,
              ),
              const SizedBox(width: 4),
              AppGhostButton(
                label: '清空',
                dense: true,
                onPressed: () async {
                  await settings.clearConversation();
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: settings.messages.isEmpty
                ? const EmptyState(
                    icon: Icons.forum_outlined,
                    title: '问点什么',
                    description: '可以让我梳理愿景、拆解任务、制定学习计划或给出复盘建议。',
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    itemCount: settings.messages.length,
                    itemBuilder: (BuildContext context, int index) =>
                        _bubble(context, settings.messages[index], palette),
                  ),
          ),
          if (service.busy)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 6),
                  Text('正在思考…', style: context.texts.labelSmall),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _error!,
                style: context.texts.labelSmall?.copyWith(
                  color: palette.danger,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  controller: _input,
                  dense: true,
                  hintText: '输入你的问题，回车发送',
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppPrimaryButton(
                label: '发送',
                onPressed: service.busy ? null : _send,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, AiMessage message, AppPalette palette) {
    final bool user = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: SelectableText(
              message.content,
              style: context.texts.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}
