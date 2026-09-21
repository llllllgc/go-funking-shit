# 小纸条知识库

这是一份随 App 一起发布的离线生活知识卡片，内容用于帮助用户观察自己的排便规律，不用于诊断。对应的运行时数据位于 `lib/data/knowledge_base.dart`。

## 内容范围

- **吃什么**：纤维来源、逐步增加与饮水；咖啡、乳制品、油腻和辛辣食物对不同人的影响可能不同，优先记录自己的重复规律。
- **形态**：Bristol 1–7 型是记录形态的工具，3–4 型通常更接近成形、柔软；偶尔一次变化不等于疾病。
- **习惯**：饭后留出从容时间、及时响应便意、规律走动和放松，帮助用户建立可观察的生活节奏。
- **颜色**：食物、铁剂和含铋药物都可能暂时改变颜色；持续异常或无法解释的变化需要咨询专业人员。
- **要留意**：鲜血、黑色柏油样便、明显腹痛、头晕、脱水迹象，以及持续腹泻或反复便秘，应优先寻求医疗帮助。

## UI 决策

首页只放一张与最近记录相关的纸条，避免把健康信息变成打卡压力；点击后进入完整知识库。知识库用主题筛选和逐张展开，先看一句话，再按需要阅读细节。底部保留红色边框的就医提示，让生活建议和风险信号分开呈现。

## 参考

- NIDDK, *Eating, Diet, & Nutrition for Constipation*：<https://www.niddk.nih.gov/health-information/digestive-diseases/constipation/eating-diet-nutrition>
- NIDDK, *Treatment for Constipation*：<https://www.niddk.nih.gov/health-information/digestive-diseases/constipation/treatment>
- NIDDK, *Eating, Diet, & Nutrition for Fecal Incontinence*：<https://www.niddk.nih.gov/health-information/digestive-diseases/bowel-control-problems-fecal-incontinence/eating-diet-nutrition>
- MedlinePlus, *Black or tarry stools*：<https://medlineplus.gov/ency/article/003130.htm>
