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
      id: 'balanced-diet',
      category: KnowledgeCategory.food,
      title: '不必因为一次变化就忌口',
      summary: '饮食影响因人而异；先保持均衡，留意反复出现的变化，再决定是否需要调整。',
      details: <String>[
        '把食物、饮料和形态放在一起回看，才更容易发现属于自己的线索。',
        '如果某种食物反复与不适同时出现，可以带着记录咨询医生或营养师。',
      ],
      source: '参考：NIDDK 肠道控制与饮食建议',
      tags: <String>['均衡饮食', '个体差异'],
    ),
    KnowledgeTip(
      id: 'loose-hydration',
      category: KnowledgeCategory.food,
      title: '偏稀时，先留意补水',
      summary: '水样便可能带走水分和电解质；留意口干、尿少、头晕等脱水迹象。',
      details: <String>[
        '偏稀时可以补充水分；如果水样便反复出现，补水之外也要观察其他症状。',
        '若有脱水迹象、血便、黑色柏油样便或明显腹痛，应尽快就医。',
      ],
      source: '参考：NIDDK 腹泻治疗及症状说明',
      tags: <String>['偏稀', '补水', '脱水'],
      featured: true,
    ),
    KnowledgeTip(
      id: 'bristol-middle',
      category: KnowledgeCategory.shape,
      title: '成形、柔软的形态',
      summary: '布里斯托大便分类是观察形态的尺子，不是给身体打分的成绩单。',
      details: <String>[
        '颗粒或成块的形态偏干偏硬，松散或水样的形态偏稀。',
        '偶尔一次变化并不能说明问题，连续趋势和伴随症状更值得留意。',
      ],
      source: '参考：NHS 相关肠道健康资料与 Bristol Stool Chart',
      tags: <String>['Bristol', '形态'],
      featured: true,
    ),
    KnowledgeTip(
      id: 'hard-observe',
      category: KnowledgeCategory.shape,
      title: '偏硬时，也记下是否费力',
      summary: '形态只是线索；排出费力、疼痛或排不尽感，也值得一起留意。',
      details: <String>[
        '回看这几天的形态、次数和不适，比只凭一条记录判断更有帮助。',
        '如果不适持续，或伴随便血、持续腹痛等情况，应咨询医生。',
      ],
      source: '参考：NIDDK 便秘症状与成因说明',
      tags: <String>['偏硬', '费力', '观察'],
    ),
    KnowledgeTip(
      id: 'loose-observe',
      category: KnowledgeCategory.shape,
      title: '偏稀时，看看是否反复',
      summary: '记录水样便的次数，以及是否有腹痛、急迫感；单凭形态无法判断原因。',
      details: <String>[
        '偶尔一次和短时间内多次水样便，适合分开记录与回看。',
        '如果水样便持续，或出现发热、血便、脱水迹象，应及时咨询医生。',
      ],
      source: '参考：NIDDK 腹泻症状与成因说明',
      tags: <String>['偏稀', '反复', '观察'],
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
      id: 'move-gently',
      category: KnowledgeCategory.habit,
      title: '适度活动，也是一种尝试',
      summary: '规律活动可能帮助改善偏硬、费力的情况；不用把步数变成打卡目标。',
      details: <String>[
        '可以从自己舒服的散步或日常活动开始，观察一段时间是否有变化。',
        '如果自我调整后仍持续不适，应和医生讨论，不必独自反复试错。',
      ],
      source: '参考：NIDDK 便秘治疗建议',
      tags: <String>['活动', '偏硬'],
    ),
    KnowledgeTip(
      id: 'toilet-comfort',
      category: KnowledgeCategory.habit,
      title: '给如厕留一点从容',
      summary: '有便意时尽量及时去；放松身体、让双脚有支撑，可能更舒服。',
      details: <String>[
        '饭后可以留一点不匆忙的时间，但不必强求每天同一时刻。',
        '如厕时不必把排出当成任务；如果经常费力或疼痛，可以记录并咨询医生。',
      ],
      source: '参考：NIDDK 便秘治疗与排便习惯建议',
      tags: <String>['如厕', '便意', '放松'],
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
      id: 'red-color',
      category: KnowledgeCategory.color,
      title: '红色变化，别只凭食物解释',
      summary: '甜菜根等食物可能改变颜色；如果看到鲜血，应及时寻求医疗建议。',
      details: <String>['可以回想近期饮食和用药，但不能只靠回忆判断是否出血。', '记录颜色变化与伴随不适，方便就医时清楚描述。'],
      source: '参考：MedlinePlus 黑色或柏油样便说明',
      tags: <String>['红色', '便血', '饮食'],
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
    KnowledgeTip(
      id: 'dehydration-signs',
      category: KnowledgeCategory.alert,
      title: '反复水样便，留意脱水信号',
      summary: '明显口渴或口干、尿少、头晕等，可能提示脱水；出现时应尽快就医。',
      details: <String>[
        '腹泻时身体会流失水分和电解质，不要只看形态是否变化。',
        '如果还伴随频繁呕吐、严重腹痛或血便，应及时寻求医疗帮助。',
      ],
      source: '参考：NIDDK 腹泻症状与治疗说明',
      tags: <String>['脱水', '水样便', '就医'],
    ),
    KnowledgeTip(
      id: 'persistent-change',
      category: KnowledgeCategory.alert,
      title: '持续变化，带着记录去问',
      summary: '偏硬、偏稀或排便习惯的变化若持续不适，适合带着记录咨询医生。',
      details: <String>[
        '就医时可以说明变化从何时开始、出现过多少次，以及是否伴随腹痛或用药变化。',
        '如果有便血、黑色柏油样便、明显腹痛或无故体重下降，不要等着自己观察很久。',
      ],
      source: '参考：NIDDK 便秘及腹泻症状说明',
      tags: <String>['持续变化', '就医', '记录'],
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
      return byId('loose-hydration')!;
    }
    return byId('bristol-middle')!;
  }
}
