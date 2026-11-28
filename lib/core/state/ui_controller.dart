import 'package:flutter/foundation.dart';

/// 全局界面状态：当前模块、导航折叠、详情抽屉 / 任务池 / 已排班面板的开合，
/// 以及「跳到时间盒某个时间块」的一次性请求。
///
/// 只描述「界面处于什么状态」，不承载业务数据，避免与仓储职责混淆。
class UiController extends ChangeNotifier {
  UiController({String initialRoute = '/home'}) : _currentRoute = initialRoute;

  String _currentRoute;
  bool _navCollapsed = false;
  String? _detailItemId;
  bool _inboxOpen = false;
  bool _scheduleOpen = false;
  bool _aiOpen = false;
  DateTime? _focusDate;
  String? _focusBlockId;
  String? _learningTaskId;
  String? _learningReviewId;
  String? _focusCapabilityId;
  String? _focusTaskId;

  String get currentRoute => _currentRoute;

  bool get navCollapsed => _navCollapsed;

  String? get detailItemId => _detailItemId;

  bool get detailOpen => _detailItemId != null;

  bool get inboxOpen => _inboxOpen;

  bool get scheduleOpen => _scheduleOpen;

  bool get aiOpen => _aiOpen;

  /// 一次性跳转请求：目标日期与要定位的时间块。
  DateTime? get focusDate => _focusDate;

  String? get focusBlockId => _focusBlockId;

  /// 「输出式学习」的一次性跳转请求：要打开的任务。
  String? get learningTaskId => _learningTaskId;

  /// 「输出式学习」的一次性跳转请求：要打开的复习节点。
  String? get learningReviewId => _learningReviewId;

  /// 「图谱」的一次性聚焦请求：要定位的能力节点。
  String? get focusCapabilityId => _focusCapabilityId;

  /// 「图谱」的一次性聚焦请求：要定位的任务节点（复盘拆解用）。
  String? get focusTaskId => _focusTaskId;

  bool get hasOverlay => detailOpen || inboxOpen || _scheduleOpen || _aiOpen;

  void setRoute(String route) {
    if (_currentRoute == route) return;
    _currentRoute = route;
    _detailItemId = null;
    _inboxOpen = false;
    _scheduleOpen = false;
    _aiOpen = false;
    _focusDate = null;
    _focusBlockId = null;
    _learningTaskId = null;
    _learningReviewId = null;
    _focusCapabilityId = null;
    _focusTaskId = null;
    notifyListeners();
  }

  void toggleNav() {
    _navCollapsed = !_navCollapsed;
    notifyListeners();
  }

  void setNavCollapsed(bool collapsed) {
    if (_navCollapsed == collapsed) return;
    _navCollapsed = collapsed;
    notifyListeners();
  }

  void openDetail(String actionItemId) {
    if (_detailItemId == actionItemId && !_inboxOpen && !_scheduleOpen) return;
    _detailItemId = actionItemId;
    _inboxOpen = false;
    _scheduleOpen = false;
    _aiOpen = false;
    notifyListeners();
  }

  void closeDetail() {
    if (_detailItemId == null) return;
    _detailItemId = null;
    notifyListeners();
  }

  void openInbox() {
    if (_inboxOpen && _detailItemId == null && !_scheduleOpen) return;
    _inboxOpen = true;
    _detailItemId = null;
    _scheduleOpen = false;
    notifyListeners();
  }

  void closeInbox() {
    if (!_inboxOpen) return;
    _inboxOpen = false;
    notifyListeners();
  }

  void openSchedule() {
    if (_scheduleOpen && _detailItemId == null && !_inboxOpen) return;
    _scheduleOpen = true;
    _detailItemId = null;
    _inboxOpen = false;
    notifyListeners();
  }

  void closeSchedule() {
    if (!_scheduleOpen) return;
    _scheduleOpen = false;
    notifyListeners();
  }

  /// 桌面端右侧 AI 面板。
  void openAi() {
    if (_aiOpen && _detailItemId == null && !_inboxOpen && !_scheduleOpen) {
      return;
    }
    _aiOpen = true;
    _detailItemId = null;
    _inboxOpen = false;
    _scheduleOpen = false;
    notifyListeners();
  }

  void closeAi() {
    if (!_aiOpen) return;
    _aiOpen = false;
    notifyListeners();
  }

  /// 从「已排班」跳到时间盒指定日期的时间块。
  void jumpToSchedule(DateTime date, String blockId) {
    _focusDate = DateTime(date.year, date.month, date.day);
    _focusBlockId = blockId;
    _scheduleOpen = false;
    _inboxOpen = false;
    _detailItemId = null;
    _currentRoute = '/time-box';
    notifyListeners();
  }

  /// 时间盒消费一次跳转请求后清除，避免重复定位。
  void consumeScheduleFocus() {
    if (_focusDate == null && _focusBlockId == null) return;
    _focusDate = null;
    _focusBlockId = null;
    notifyListeners();
  }

  void openLearning(String actionItemId) {
    _learningTaskId = actionItemId;
    _detailItemId = null;
    _inboxOpen = false;
    _scheduleOpen = false;
    _aiOpen = false;
    _currentRoute = '/output-learning';
    notifyListeners();
  }

  void consumeLearningTask() {
    if (_learningTaskId == null) return;
    _learningTaskId = null;
    notifyListeners();
  }

  void openReview(String reviewId) {
    _learningReviewId = reviewId;
    _learningTaskId = null;
    _detailItemId = null;
    _inboxOpen = false;
    _scheduleOpen = false;
    _aiOpen = false;
    _currentRoute = '/output-learning';
    notifyListeners();
  }

  void consumeLearningReview() {
    if (_learningReviewId == null) return;
    _learningReviewId = null;
    notifyListeners();
  }

  /// 从复盘/统计跳到图谱并定位某个能力节点。
  void openCapability(String capabilityId) {
    _focusCapabilityId = capabilityId;
    _currentRoute = '/vision-map';
    _detailItemId = null;
    _inboxOpen = false;
    _scheduleOpen = false;
    _aiOpen = false;
    _focusDate = null;
    _focusBlockId = null;
    _learningTaskId = null;
    _learningReviewId = null;
    notifyListeners();
  }

  void consumeCapabilityFocus() {
    if (_focusCapabilityId == null) return;
    _focusCapabilityId = null;
    notifyListeners();
  }

  /// 从复盘「拆解任务」跳到图谱并定位该任务节点。
  void openTaskLocation(String taskId) {
    _focusTaskId = taskId;
    _focusCapabilityId = null;
    _currentRoute = '/vision-map';
    _detailItemId = null;
    _inboxOpen = false;
    _scheduleOpen = false;
    _aiOpen = false;
    _focusDate = null;
    _focusBlockId = null;
    _learningTaskId = null;
    _learningReviewId = null;
    notifyListeners();
  }

  void consumeTaskFocus() {
    if (_focusTaskId == null) return;
    _focusTaskId = null;
    notifyListeners();
  }

  void closeOverlays() {
    if (!hasOverlay) return;
    _detailItemId = null;
    _inboxOpen = false;
    _scheduleOpen = false;
    _aiOpen = false;
    notifyListeners();
  }
}
