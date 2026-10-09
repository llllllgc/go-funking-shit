import '../domain/knowledge_tip.dart';

/// Bundled, offline-first notes for the small-paper knowledge cards.
///
/// These are short pieces of general education rather than diagnoses. The
/// wording intentionally avoids treating one food or one stool as proof of a
/// cause; the useful signal is a repeated pattern in the user's own log.
abstract final class KnowledgeBase {
  static const List<KnowledgeTip> tips = <KnowledgeTip>[
    KnowledgeTip(
      id: 'fiber-water',
      category: KnowledgeCategory.food,
      title: '纤维要慢慢加，水要跟上',
      summary: '全谷物、豆类、蔬果和坚果能提供纤维；增加时一步一步来，并配合足够饮水。',
      details: <String>[
        '一次把纤维加得太快，可能让胀气更明显。',
        '水分需求会受体型、活动量和健康情况影响，别用固定杯数套所有人。',
      ],
      source: '参考：美国国立糖尿病、消化和肾脏疾病研究所（NIDDK）',
      tags: <String>['便硬', '颗粒状', '饮水'],
      featured: true,
    ),
    KnowledgeTip(
      id: 'food-pattern',
      category: KnowledgeCategory.food,
      title: '食物影响，先记“自己的规律”',
      summary: '咖啡、乳制品、油腻或辛辣食物可能影响部分人的肠道，但没有一份菜单适合所有人。',
      details: <String>[
        '把当天吃喝和排便形态一起记几天，比凭一次经历下结论更可靠。',
        '如果某种食物反复让你不舒服，再带着记录和医生或营养师讨论。',
      ],
      source: '参考：NIDDK 肠道控制与饮食建议',
      tags: <String>['食物日记', '个体差异'],
    ),
    KnowledgeTip(
      id: 'bristol-middle',
      category: KnowledgeCategory.shape,
      title: '3～4 型通常更接近成形、柔软',
      summary: '布里斯托大便分类是观察形态的尺子，不是给身体打分的成绩单。',
      details: <String>[
        '1～2 型常见于偏干偏硬，6～7 型偏松散或水样。',
        '偶尔一次变化并不能说明问题，连续趋势和伴随症状更值得留意。',
      ],
      source: '参考：NHS 相关肠道健康资料与 Bristol Stool Chart',
      tags: <String>['Bristol', '形态'],
      featured: true,
    ),
    KnowledgeTip(
      id: 'after-meal',
      category: KnowledgeCategory.habit,
      title: '饭后给身体一个从容的时间',
      summary: '进食会带动结肠活动；固定在饭后留出一点时间，比憋着或用力更温和。',
      details: <String>['有便意时尽量及时去，不必强行追求每天同一时刻。', '规律走动、放松和脚下有支撑，可能让排便更舒服。'],
      source: '参考：NIDDK 便秘生活方式建议',
      tags: <String>['规律', '活动'],
    ),
    KnowledgeTip(
      id: 'color-food',
      category: KnowledgeCategory.color,
      title: '颜色会被食物和药物染出变化',
      summary: '甜菜根、深色浆果、铁剂或含铋药物等，可能让颜色暂时改变。',
      details: <String>[
        '通常的颜色范围是棕色系；单次颜色变化先回想最近吃了什么、用了什么药。',
        '颜色持续异常，或你无法解释时，记录下来并咨询专业人员。',
      ],
      source: '参考：MedlinePlus 黑色或柏油样大便说明',
      tags: <String>['颜色', '药物'],
    ),
    KnowledgeTip(
      id: 'red-flag',
      category: KnowledgeCategory.alert,
      title: '有些信号不适合只靠小纸条',
      summary: '看到鲜血、黑色柏油样便，或伴随明显腹痛、头晕、脱水迹象时，应及时寻求医疗帮助。',
      details: <String>[
        '持续腹泻、反复便秘、体重无故下降，也值得和医生聊聊。',
        '小纸条只能帮助整理观察，不能替代诊断；紧急不适请优先就医。',
      ],
      source: '参考：MedlinePlus 消化道出血与腹泻警示',
      tags: <String>['警示', '就医'],
      featured: true,
    ),
  ];

  static KnowledgeTip? byId(String id) {
    for (final tip in tips) {
      if (tip.id == id) return tip;
    }
    return null;
  }

  static List<KnowledgeTip> forCategory(KnowledgeCategory category) {
    if (category == KnowledgeCategory.all) return tips;
    return tips
        .where((tip) => tip.category == category)
        .toList(growable: false);
  }

  static KnowledgeTip featuredFor(int? bristolType) {
    if (bristolType != null && bristolType <= 2) {
      return byId('fiber-water')!;
    }
    if (bristolType != null && bristolType >= 6) {
      return byId('food-pattern')!;
    }
    return byId('bristol-middle')!;
  }
}
