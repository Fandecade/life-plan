import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_service.dart';
import 'reminder_settings.dart';

/// 系统本地通知：Android / macOS 在应用关闭后仍能提醒。
///
/// Web 或插件不可用时自动降级（[supported] 为 false），
/// 应用内横幅仍由 [ReminderService] 负责。
class NotificationService {
  NotificationService({required this.reminders, required this.settings});

  static const String channelId = 'reminders';
  static const String taskCategory = 'reminder_task';
  static const String habitCategory = 'reminder_habit';

  final ReminderService reminders;
  final ReminderSettings settings;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _supported = false;
  String? _lastSignature;

  /// 用户点击通知或通知动作时回调：actionId 为空表示普通点击。
  void Function(String actionId, String payload)? onIntent;

  bool get supported => _supported;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;
    try {
      tz_data.initializeTimeZones();
      try {
        final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        // 拿不到时区名时保留默认 location，不影响后续初始化。
      }

      const AndroidInitializationSettings android =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      final DarwinInitializationSettings darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
        notificationCategories: <DarwinNotificationCategory>[
          DarwinNotificationCategory(
            taskCategory,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                'complete',
                '完成',
                options: const <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                'snooze',
                '稍后 10 分钟',
                options: const <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
            ],
          ),
          DarwinNotificationCategory(
            habitCategory,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                'open',
                '去打卡',
                options: const <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                'snooze',
                '稍后 10 分钟',
                options: const <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
            ],
          ),
        ],
      );

      await _plugin.initialize(
        InitializationSettings(android: android, macOS: darwin, iOS: darwin),
        onDidReceiveNotificationResponse: _handleResponse,
      );
      _supported = true;
      await _requestPermissions();
    } catch (_) {
      // Web、测试环境或未注册插件的平台：保持降级。
      _supported = false;
    }
  }

  /// 按当前数据重排未来 7 天的系统通知。
  Future<void> syncUpcoming({DateTime? now}) async {
    if (!_supported) return;
    if (!settings.enabled) {
      if (_lastSignature != 'disabled') {
        _lastSignature = 'disabled';
        await _plugin.cancelAll();
      }
      return;
    }

    final List<ReminderEvent> plan = reminders.upcoming(now: now);
    final String signature = plan
        .map(
          (ReminderEvent event) =>
              '${event.key}@${event.at.toIso8601String()}|${event.title}',
        )
        .join(';');
    if (signature == _lastSignature) return;
    _lastSignature = signature;

    await _plugin.cancelAll();
    for (int index = 0; index < plan.length; index++) {
      await _schedule(index, plan[index]);
    }
  }

  Future<void> cancelAll() async {
    if (!_supported) return;
    _lastSignature = null;
    await _plugin.cancelAll();
  }

  Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      await android.requestExactAlarmsPermission();
    }
    final MacOSFlutterLocalNotificationsPlugin? macos = _plugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
    if (macos != null) {
      await macos.requestPermissions(alert: true, badge: false, sound: true);
    }
  }

  Future<void> _schedule(int id, ReminderEvent event) async {
    final AndroidNotificationDetails android = AndroidNotificationDetails(
      channelId,
      '任务提醒',
      channelDescription: '时间盒任务与微习惯提醒',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      actions: event.canComplete
          ? const <AndroidNotificationAction>[
              AndroidNotificationAction(
                'complete',
                '完成',
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                'snooze',
                '稍后 10 分钟',
                showsUserInterface: true,
              ),
            ]
          : const <AndroidNotificationAction>[
              AndroidNotificationAction(
                'open',
                '去打卡',
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                'snooze',
                '稍后 10 分钟',
                showsUserInterface: true,
              ),
            ],
    );
    final DarwinNotificationDetails darwin = DarwinNotificationDetails(
      categoryIdentifier:
          event.canComplete ? taskCategory : habitCategory,
      presentAlert: false,
      presentSound: true,
    );
    final NotificationDetails details =
        NotificationDetails(android: android, macOS: darwin);
    final tz.TZDateTime scheduled = tz.TZDateTime.from(event.at, tz.local);
    final String payload = jsonEncode(event.toJson());

    try {
      await _plugin.zonedSchedule(
        id,
        event.title,
        event.subtitle.isEmpty ? '点按查看' : event.subtitle,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (_) {
      // 精确闹钟权限缺失时退化为非精确调度。
      await _plugin.zonedSchedule(
        id,
        event.title,
        event.subtitle.isEmpty ? '点按查看' : event.subtitle,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  void _handleResponse(NotificationResponse response) {
    final String payload = response.payload ?? '';
    if (payload.isEmpty) return;
    onIntent?.call(response.actionId ?? '', payload);
  }
}