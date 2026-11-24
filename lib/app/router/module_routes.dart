/// 模块路由常量。路由由插件注册中心动态挂载，关闭模块即从导航中移除。
class AppRoutes {
  const AppRoutes._();

  static const String visionMap = '/vision-map';
  static const String projects = '/projects';
  static const String timeBox = '/time-box';
  static const String outputLearning = '/output-learning';
  static const String foggHabit = '/fogg-habit';
  static const String review = '/review';
  static const String settings = '/settings';

  static const List<String> all = <String>[
    visionMap,
    projects,
    timeBox,
    outputLearning,
    foggHabit,
    review,
    settings,
  ];
}