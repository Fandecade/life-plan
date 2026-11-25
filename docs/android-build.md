# 安卓打包与调试指南

本文记录 2026-11-25 在这台 Mac 上补齐 Android 构建环境的过程，以及后续打包、签名、调试的标准操作。

## 一、环境现状

检查前的状态是 Flutter 3.50.1 已经装好，但完全没有 JDK、Android SDK、adb 和模拟器，`flutter doctor` 的 Android 一栏直接失败。

本次已补齐的组件：

| 组件 | 版本 / 路径 |
| --- | --- |
| JDK | OpenJDK 21.0.13，`/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home` |
| Android SDK | `/opt/homebrew/share/android-commandlinetools` |
| platform-tools（含 adb） | 37.0.3 |
| SDK Platform | android-36（构建过程中 AGP 又自动补了 android-35） |
| Build-Tools | 36.0.0 |
| NDK | 28.2.13676358 |
| 模拟器 | 37.3.10 |
| 系统镜像 | `system-images;android-36;google_apis;arm64-v8a` |
| AVD | `life_planner_api36`（1080×2400 / 420dpi） |

Flutter 侧已经写入配置，不需要每次指定路径：

```bash
flutter config --android-sdk /opt/homebrew/share/android-commandlinetools
flutter config --jdk-dir /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
flutter doctor -v   # Android toolchain 应为 ✓
```

项目里的依赖极简，没有原生插件（Hive 是纯 Dart 实现），所以 Android 侧只需要上面这套标准工具链，不需要额外装 CocoaPods 之类的东西。

## 二、打包

所有命令都在项目根目录执行。

```bash
flutter pub get

# 调试包，可以 attach 调试器
flutter build apk --debug

# 发布包，默认打成一个包含 arm64-v8a / armeabi-v7a / x86_64 的通用 APK
flutter build apk --release

# 发布包按 CPU 架构拆分，单个包更小，适合分渠道分发
flutter build apk --release --split-per-abi

# 上架 Google Play 用
flutter build appbundle --release
```

产物位置：

| 命令 | 产物 |
| --- | --- |
| `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk`（约 56 MB） |
| `--split-per-abi` | 同目录下 `app-armeabi-v7a-release.apk`、`app-arm64-v8a-release.apk`、`app-x86_64-release.apk` |
| `flutter build appbundle --release` | `build/app/outputs/bundle/release/app-release.aab`（约 55 MB） |
| `flutter build apk --debug` | `build/app/outputs/flutter-apk/app-debug.apk` |

版本号在 `pubspec.yaml` 里改，格式是 `版本名+构建号`：

```yaml
version: 0.1.0+1
```

`0.1.0` 是用户看到的版本名，`+1` 是 Android 的 versionCode。每次发新版都要把 `+1` 往上加，否则安卓会拒绝覆盖安装，应用商店也会拒收。

## 三、签名

项目原来用的是 Flutter 模板的调试签名，只能自己临时装。现在已经换成正式签名：

- 密钥库文件 `android/app/life-planner-release.jks`，别名 `lifeplanner`，有效期 10000 天
- 密码与路径写在 `android/key.properties`，该文件已被 `android/.gitignore` 忽略，不会进仓库
- `android/app/build.gradle.kts` 会读取 `key.properties`，缺失时自动回退到调试签名，方便换机器直接出包

两个必须注意的点：

1. `life-planner-release.jks` 和 `android/key.properties` 要单独备份到网盘或密码管理器。密钥丢了，已安装的用户就无法升级，只能卸载重装，Google Play 上的应用也再也不能更新。
2. 调试签名和正式签名的包互相不能覆盖安装。换签名后第一次安装需要先卸载旧包，而卸载会清空 Hive 存在应用私有目录里的全部数据。

查看某个包用的是哪张证书：

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
$ANDROID_HOME/build-tools/36.0.0/apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

## 四、真机调试

1. 手机打开「开发者选项」和「USB 调试」，用数据线连 Mac。
2. 手机上弹出「允许 USB 调试吗」时勾选始终允许。
3. 确认设备被识别：

```bash
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export PATH=$ANDROID_HOME/platform-tools:$PATH

adb devices          # 状态应为 device，不是 unauthorized
flutter devices
```

4. 启动调试：

```bash
flutter run -d <设备ID>
```

运行后控制台支持这些快捷键：

| 按键 | 作用 |
| --- | --- |
| `r` | 热重载，保留当前页面状态 |
| `R` | 热重启，回到首页并重建状态 |
| `d` | 断开调试，应用继续留在手机上 |
| `q` | 退出调试并关闭应用 |

`flutter run` 会同时输出 Dart VM Service 和 DevTools 地址，浏览器打开就能用 Widget Inspector 看布局层级、改颜色试效果，也能看帧耗时。

只想把正式包装到手机上，不接调试器：

```bash
flutter install --release
# 或者
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

常见失败：

| 现象 | 原因与处理 |
| --- | --- |
| `adb devices` 列表为空 | 换数据线或 USB 口，确认手机端已授权 |
| `unauthorized` | 手机上重新确认授权，或执行 `adb kill-server && adb start-server` |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | 新旧包签名不一致，先 `adb uninstall com.lifelab.life_planner` 再装 |
| `INSTALL_FAILED_VERSION_DOWNGRADE` | 装的包 versionCode 比已装的小，提升 `pubspec.yaml` 的 `+N` |

## 五、模拟器

启动已有的模拟器：

```bash
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
$ANDROID_HOME/emulator/emulator -avd life_planner_api36
```

不需要窗口时加 `-no-window`，适合只跑自动化或截图。首次启动约 1 分钟，之后可以用快照秒开。关闭模拟器：

```bash
adb emu kill
```

重建一个同配置的模拟器：

```bash
avdmanager create avd -n life_planner_api36 -k "system-images;android-36;google_apis;arm64-v8a" -d pixel_7
```

如果模拟器顶部状态栏的时间、电量被裁掉一截，是 AVD 的刘海区域配置问题，执行下面这行即可修复：

```bash
adb shell cmd overlay enable com.android.internal.display.cutout.emulation.corner
```

## 六、调试手段

```bash
flutter analyze                 # 静态检查，Android 打包前建议先跑
flutter test                    # 全部单测与组件测试
flutter logs                    # 实时看应用日志
adb logcat -s flutter           # 只看 Flutter 输出
```

没有 DevTools 时的辅助手段：

```bash
adb exec-out screencap -p > shot.png    # 截图
adb shell input tap 540 1200            # 点击坐标
adb shell input keyevent KEYCODE_BACK   # 模拟返回键
adb shell dumpsys activity activities | grep -m1 topResumedActivity
```

布局溢出在 debug 包上会显示黄黑条纹，同时日志里出现 `A RenderFlex overflowed by ...`。release 包不会显示条纹，只会静默裁切，所以窄屏适配要在 debug 包或模拟器上验收。

## 七、可选的环境变量

当前 Flutter 的 SDK 和 JDK 路径已经写进 Flutter 自己的配置，`flutter build` 不依赖 shell 环境变量。直接调用 `adb`、`avdmanager`、`emulator` 时才需要下面三行。想省事可以加到 `~/.zshrc`：

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export PATH=$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH
```

## 八、为安卓做的代码改动

在模拟器上跑第一版 release 包时发现两个手机端问题，已修复：

1. 顶栏内容画到了状态栏下面，标题和系统时间重叠。`lib/app/shell/app_shell.dart` 给 `TopBar` 包了 `SafeArea`。
2. 底部滑出的任务池、详情、安排记录面板，标题同样被状态栏压住。`lib/app/shell/slide_over_panel.dart` 对竖排面板加了 `SafeArea`。
3. 安卓返回键原来会直接退出应用。`AppShell` 增加了 `PopScope`，有面板打开时先关面板，没有面板时才退出。
4. 桌面图标名从 `life_planner` 改成「人生规划」，见 `android/app/src/main/AndroidManifest.xml`。
5. release 构建接入正式签名，见 `android/app/build.gradle.kts`。

验证结果：`flutter analyze` 无 error / warning（只有 Flutter 3.50 关于 `material.dart` 迁移的 info 提示），`flutter test` 119 个用例全部通过，release 包在 Pixel 7 尺寸的模拟器上安装启动正常，返回键与面板开合正常。
