# 每日提醒

## 产品行为

入口为“设置与隐私 → 每日提醒”。默认关闭，初始候选时间为 20:00；可以先选择时间，再决定是否开启。只有主动开启时才请求系统通知权限，拒绝后仍可记录、查看和管理数据。

开关表示用户保存的提醒偏好；系统禁止通知时，界面另行说明“暂时不会提醒”，提供系统通知设置入口。返回前台后重新核对权限和安排。关闭会取消待发送的每日提醒并移除本应用已送达的提醒；时间偏好保留，重新开启时沿用。

通知标题为“记录提醒”，内容为“有空时，记下今天的情况。按自己的节奏来。”不读取记录，不显示次数、形态、备注或不适，也不根据是否有记录推断是否排便。用户可主动发送测试提醒，点击通知只返回应用，不能跳过应用锁。

## 调度与持久化

- Android：原生 AlarmManager 非精确定时，不请求精确闹钟权限。每次按设备当地日期重新计算下一次时间，处理启动、升级、时区和手动时间变化的系统广播。保存最近送达的当地日期，避免同一天因时钟回拨而重复提醒。旧配置代次/旧触发时间的广播不会直接发送通知。
- iOS：原生 UNCalendarNotificationTrigger，每日匹配小时和分钟，不固定时区或日期。系统处理当地时间匹配；不开启远程推送能力。
- 提醒偏好分别保存在应用自己的 SharedPreferences / UserDefaults 中，以便原生系统调度不依赖 Flutter 是否运行；与健康记录的 SQLite 表独立。备份导入或清空日志不改变提醒开关。
- 系统接口调用失败时显示状态待确认，重新读取前禁止继续修改。提醒初始化异步进行，不阻塞主应用。权限窗口返回后若应用已锁定或控制器销毁，不继续开启提醒。
- 时间到了之后可能因省电、专注模式、通知渠道设置或系统限制而延后/静音。Android 被用户强制停止后需要重新打开应用。应用重新检查时从当前时间安排下一次，不补发已经过去的提醒。

## 验证边界

- Flutter：默认关闭/不请求权限、拒绝与重新允许、修改/关闭、状态不确定后的读回、重复请求、锁定或销毁后的旧回调、测试通知、320px 双倍字号。
- Android 原生：6 项日历测试，涵盖夏令时进入/退出、缺失时刻、跨年、当地午夜、时区变化及输入边界。
- iOS 原生：3 项测试，验证隔离偏好存取、日历触发器配置，以及实际通知中心的无权限读取/关闭操作；测试命名空间独立于正常提醒。
- 已实现不等于全部送达场景通过。真实权限对话框、实际提醒送达/点击、Android 重启/强制停止/厂家省电限制、双端真实时区切换仍需设备验收。

运行原生测试：Android 为 `cd android && ./gradlew :app:testDebugUnitTest`；iOS 先设置独立模拟器 UUID `LALEMA_QA_SIMULATOR`，再运行 `bash tool/test_ios_native.sh`。CI 同样执行两组测试。

## 平台依据

- [Android 闹钟调度与重启恢复](https://developer.android.com/develop/background-work/services/alarms)
- [Android 通知运行时权限](https://developer.android.com/develop/ui/compose/notifications/notification-permission)
- [Apple 日历通知触发器](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger)
- [Apple 隐私清单中 API 使用理由](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)：应用自己的提醒偏好使用 UserDefaults，Runner 隐私清单声明 CA92.1。
