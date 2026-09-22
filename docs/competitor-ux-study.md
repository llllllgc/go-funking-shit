# 同类产品 UX 参考

更新时间：2026-09-22

这份笔记把市场上成熟的健康记录产品拆成可借鉴的交互模式，再映射到“拉了么？”当前的离线、无评判和快速记录定位。竞品的功能描述来自产品官方页面或应用商店页面；它们说明了用户期待，不代表本产品应全部照搬。

## 可借鉴的模式

| 产品 | 已验证的模式 | 对“拉了么？”的启发 |
| --- | --- | --- |
| [Apple Health](https://www.apple.com/health/) | 把当天摘要和长期趋势放在同一个健康视图；强调数据由设备密码、Touch ID 或 Face ID 保护 | 首页先给少量可读摘要，另设“观察”详情；隐私是首屏产品价值，不放到设置深处 |
| [Daylio 统计](https://daylio.net/faq/docs/daylio-faq/about/activity-and-mood-statistics/) | 有频次、前后周期比较、图表和置信度；目标和提醒可选 | 先显示事实和样本量，再给“较上周期增加/减少”的克制文案；不足样本时不下结论 |
| [Bearable](https://bearable.app/) | 用几次点击记录症状、药物、习惯，之后看趋势、相关因素和报告；提醒与目标是可选项 | 记录页采用渐进式展开：Bristol 仍是一键完成，细节只在用户主动需要时出现 |
| [Bristol Stool Chart Tracker](https://bristolstoolchart.net/privacy.html) | 无账号、本地记录；用户主动分享 CSV，导出只包含日期/时间和类型 | 先做本地 CSV 导出，预览范围和记录数，分享动作由用户发起；不引入账号或后台同步 |
| [Number Two](https://apps.apple.com/gb/app/number-two-poop-tracker/id6759846071) | 两步快速记录、日历色彩概览、常见类型/规律性洞察、医生 PDF/CSV 报告、默认本地存储 | 先加“按上次类型记录”的快捷入口，再做 7/30 日观察和医生可读导出；日历颜色表示记录量，不表示健康好坏 |
| [Doody](https://apps.apple.com/gb/app/doody-poop-tracker-ibs-log/id6745105094) | 本地、离线、无账号；日历热力图；按食物/感受标记并生成周/月文字总结 | 日历可以变成记录节奏概览；总结要能追溯到具体记录，避免黑箱式健康评分 |

## 当前产品的决策

当前版本已经有 Bristol 视觉选择、快速保存、补记、历史和月历。下一步应把“记录后有什么用”做得更清楚，同时保持第一次使用的动作足够短。

### P0：快捷记录和观察

1. 在首页最近一笔下方增加「按上次类型记录（4 型）」。点击直接记录当前时间；完整 Bristol 选择仍可从主记录入口进入。无历史时不显示这个按钮。
2. 把现有七日摘要升级为可点击的“观察”卡。详情页先做 7 日/30 日切换，显示次数、活跃天数、Bristol 1–2/3–5/6–7 分布和常见时段。
3. 所有比较文案显示样本量；记录太少时写“再记录几次后再比较”，不生成健康分数或诊断。

### P1：可选细节和导出

1. 在记录页底部折叠「添加可选细节」。首版只做腹痛、腹胀、急迫、费力和备注；展开之前不增加任何步骤。血或黏液属于警示字段，应带克制的就医提示。
2. 为 SQLite 增加版本迁移后，在历史/设置提供「导出」。第一版支持日期范围预览和 CSV，包含日期、时间、Bristol 类型及已填写的可选字段；文件只在用户点击分享后生成，不上传。

### P2：隐私和回顾

1. 提供可选的 Face ID/Touch ID/系统生物识别或 PIN 锁，默认关闭；锁定页说明记录仍在本机。
2. 月历增加按每天记录数量的热力深浅，并保留点击查看当天记录。颜色只代表“记录了几次”，不要把它命名为健康等级。
3. 提醒保持默认关闭，只提供低压力的本地晚间补记提醒；不加入连续打卡惩罚、排名或必须完成的目标。

## 体验护栏

- 主流程必须是“打开 → 选 Bristol → 自动保存”，可选字段绝不能阻塞它。
- insight 文案使用“你的记录显示”“基于 X 笔记录”，避免“正常/不正常”和未经验证的因果判断。
- 导出、锁定和清空数据前都要显示范围、记录数量和后果；保持可撤销或可恢复路径。
- 视觉强度、图例和图案不能只依赖颜色；动态图表需要文字替代和系统大字支持。

## 参考链接

- Apple Health: <https://www.apple.com/health/>
- Daylio statistics: <https://daylio.net/faq/docs/daylio-faq/about/activity-and-mood-statistics/>
- Bearable: <https://bearable.app/>
- Bristol Stool Chart privacy: <https://bristolstoolchart.net/privacy.html>
- Number Two: <https://apps.apple.com/gb/app/number-two-poop-tracker/id6759846071>
- Doody: <https://apps.apple.com/gb/app/doody-poop-tracker-ibs-log/id6745105094>
