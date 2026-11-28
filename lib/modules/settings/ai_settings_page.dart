import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/ai/ai_models.dart';
import '../../core/ai/ai_settings_controller.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_text_field.dart';
import 'settings_rows.dart';
import 'settings_sub_page.dart';

/// 设置 → AI 助手：OpenAI 兼容配置、Key 安全存储、模型获取与连通性测试。
class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _key;
  bool _testing = false;
  bool _fetchingModels = false;

  @override
  void initState() {
    super.initState();
    final AiSettingsController settings = context.read<AiSettingsController>();
    _baseUrl = TextEditingController(text: settings.baseUrl);
    _model = TextEditingController(text: settings.model);
    _key = TextEditingController();
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _save({bool quiet = false}) async {
    final AiSettingsController settings = context.read<AiSettingsController>();
    await settings.saveProfile(baseUrl: _baseUrl.text, model: _model.text);
    if (_key.text.trim().isNotEmpty) {
      await settings.saveKey(_key.text);
      _key.clear();
    }
    if (!mounted) return;
    if (!quiet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已保存'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _test() async {
    if (_testing) return;
    setState(() => _testing = true);
    await _save(quiet: true);
    if (!mounted) return;
    final AiSettingsController settings = context.read<AiSettingsController>();
    final String result = await settings.testConnection();
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _fetchModels() async {
    if (_fetchingModels) return;
    setState(() => _fetchingModels = true);
    String? error;
    List<String> models = const <String>[];
    try {
      await _save(quiet: true);
      if (!mounted) return;
      models = await context.read<AiSettingsController>().fetchModels();
    } on AiException catch (error0) {
      error = error0.message;
    } finally {
      if (mounted) setState(() => _fetchingModels = false);
    }
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (models.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('没有可用模型'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final String? picked = await showAppSheet<String>(
      context,
      builder: (BuildContext sheetContext) => AppSheetContent(
        title: '选择模型',
        heightFactor: 0.6,
        maxWidth: 520,
        scrollable: false,
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final String model in models)
              ListTile(
                title: Text(model, style: sheetContext.texts.bodyMedium),
                onTap: () => Navigator.of(sheetContext).pop(model),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _model.text = picked;
    await context.read<AiSettingsController>().saveProfile(
      baseUrl: _baseUrl.text,
      model: picked,
    );
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AiSettingsController settings = context.watch<AiSettingsController>();
    final AppPalette palette = context.palette;

    return SettingsSubPage(
      title: 'AI 助手',
      subtitle: '支持 OpenAI 兼容 / Anthropic / Gemini；模型可拉取或手填。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (kIsWeb) ...<Widget>[
            Text(
              'Web 端提示：多数 AI 厂商不允许浏览器直连（CORS），请填写自建代理地址；API Key 在 Web 的安全存储也受限。',
              style: context.texts.bodySmall?.copyWith(color: palette.warning),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          SettingsCardGroup(
            children: <Widget>[
              SettingsControlRow(
                icon: Icons.hub_outlined,
                title: '接口协议',
                subtitle: 'OpenAI 兼容 / Anthropic / Gemini',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final AiProviderKind kind in AiProviderKind.values)
                      AppChip(
                        label: kind.label,
                        dense: true,
                        filled: settings.providerKind == kind,
                        color: palette.accent,
                        onTap: () => settings.setProviderKind(kind),
                      ),
                  ],
                ),
              ),
              SettingsControlRow(
                icon: Icons.link_rounded,
                title: '服务地址',
                subtitle: '例：${settings.providerKind.hintBaseUrl}',
                child: AppTextField(
                  controller: _baseUrl,
                  dense: true,
                  hintText: settings.providerKind.hintBaseUrl,
                ),
              ),
              SettingsControlRow(
                icon: Icons.key_rounded,
                title: 'API Key',
                subtitle: settings.hasKey ? '已保存到系统安全存储' : '未保存',
                child: AppTextField(
                  controller: _key,
                  dense: true,
                  obscureText: true,
                  hintText: settings.hasKey ? '••••••••（输入新 Key 可覆盖）' : 'sk-…',
                ),
              ),
              SettingsControlRow(
                icon: Icons.memory_rounded,
                title: '模型',
                subtitle: '点「获取」从服务端拉取并下拉选择，也可手动填写',
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        controller: _model,
                        dense: true,
                        hintText: 'deepseek-chat',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppGhostButton(
                      label: _fetchingModels ? '获取中…' : '获取',
                      dense: true,
                      onPressed: _fetchingModels ? null : _fetchModels,
                    ),
                  ],
                ),
              ),
              SettingsRow(
                icon: Icons.bolt_rounded,
                title: '测试连接',
                subtitle: _testing ? '正在请求模型…' : '保存配置并发一条最小请求',
                trailing: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right_rounded, size: 16),
                onTap: _testing ? null : _test,
              ),
              SettingsRow(
                icon: Icons.lock_outline_rounded,
                title: '只读模式',
                subtitle: '当前版本只分析与建议，不直接修改数据',
                trailing: Switch(
                  value: settings.readOnly,
                  onChanged: settings.setReadOnly,
                ),
              ),
              SettingsRow(
                icon: Icons.delete_sweep_outlined,
                title: '清空会话',
                subtitle: '只删除本地对话记录，不影响业务数据',
                danger: true,
                showDivider: false,
                onTap: () async {
                  await settings.clearConversation();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已清空本地会话'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              AppPrimaryButton(label: '保存配置', onPressed: _save),
              const SizedBox(width: AppSpacing.sm),
              if (settings.hasKey)
                AppGhostButton(
                  label: '删除 Key',
                  tone: palette.danger,
                  onPressed: settings.clearKey,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '隐私说明：对话时会把愿景、能力、任务与复盘摘要发送给你选择的模型服务；API Key 仅保存在本机安全存储，不会进入备份。',
            style: context.texts.bodySmall,
          ),
        ],
      ),
    );
  }
}
