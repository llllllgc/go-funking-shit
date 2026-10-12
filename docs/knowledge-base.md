# 小纸条知识库

这是一份随 App 一起发布的离线生活知识卡片，内容用于帮助用户观察自己的排便规律，不用于诊断。对应的运行时数据位于 `lib/data/knowledge_base.dart`。

## 内容范围

- **吃什么**：纤维来源、逐步增加与饮水；咖啡、乳制品、油腻和辛辣食物对不同人的影响可能不同，优先记录自己的重复规律。
- **形态**：形态分类帮助观察偏硬、成形或偏稀的变化；偶尔一次变化不等于疾病。记录页使用 01–07 的列表序号，其中光滑柔软显示为 01、颗粒偏硬显示为 04；已有记录仍按原始形态保存和读取。
- **习惯**：饭后留出从容时间、及时响应便意、规律走动和放松，帮助用户建立可观察的生活节奏。
- **颜色**：食物、铁剂和含铋药物都可能暂时改变颜色；持续异常或无法解释的变化需要咨询专业人员。
- **要留意**：鲜血、黑色柏油样便、明显腹痛、头晕、脱水迹象，以及持续腹泻或反复便秘，应优先寻求医疗帮助。

目前共有 15 张纸条。偏硬、费力与活动或如厕习惯分开讲；偏稀同时提供补水和脱水信号；颜色类区分食物可能造成的变化与真正需要就医的便血。首页仍只展示一张：保存的形态偏硬时显示纤维与饮水纸条，水样或松散时显示补水纸条，其他情况显示形态观察纸条。首页的 01、04 是列表序号，纸条按保存的真实形态匹配，不根据显示序号判断。

## UI 决策

首页在“近 7 天”统计下方放一条与最近记录相关的纸条入口，仅显示小图标、“小纸条”标签和一行标题；不使用卡片背景、粗边框、阴影或折角，以免抢占记录和趋势的视觉重心。入口保留至少 56dp 的点击高度，长标题省略，点击后进入完整知识库阅读详情。知识库用主题筛选和逐张展开，先看一句话，再按需要阅读细节。底部保留红色边框的就医提示，让生活建议和风险信号分开呈现。

## 参考

- 纤维、水分、活动和如厕习惯：[NIDDK 便秘饮食](https://www.niddk.nih.gov/health-information/digestive-diseases/constipation/eating-diet-nutrition)、[NIDDK 便秘治疗](https://www.niddk.nih.gov/health-information/digestive-diseases/constipation/treatment)、[NIDDK 便秘症状](https://www.niddk.nih.gov/health-information/digestive-diseases/constipation/symptoms-causes)。
- 食物差异和饮食记录：[NIDDK 肠道控制与饮食](https://www.niddk.nih.gov/health-information/digestive-diseases/bowel-control-problems-fecal-incontinence/eating-diet-nutrition)。
- 水样便、补水与脱水迹象：[NIDDK 腹泻治疗](https://www.niddk.nih.gov/health-information/digestive-diseases/diarrhea/treatment)、[NIDDK 腹泻症状](https://www.niddk.nih.gov/health-information/digestive-diseases/diarrhea/symptoms-causes)。
- 形态说明：[NHS Bristol Stool Chart](https://www.england.nhs.uk/wp-content/uploads/2015/04/07-cdi-diarrhoea.pdf)。此标准的类型编号与 App 自定义的列表序号不是同一回事。
- 颜色、便血和黑色柏油样便：[MedlinePlus Black or tarry stools](https://medlineplus.gov/ency/article/003130.htm)。
