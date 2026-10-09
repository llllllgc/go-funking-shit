import '../domain/knowledge_tip.dart';

/// Bundled general education. Source checks do not constitute clinical review.
/// The home card links a shape to an observation topic, never to a diagnosis
/// or a recommended dietary treatment. See docs/knowledge-content-audit.md.
abstract final class KnowledgeBase {
  static const fiberDiet = KnowledgeSource(
    id: 'niddk-fiber',
    organization: 'NIDDK',
    title: '便秘的饮食与营养',
    url:
        'https://www.niddk.nih.gov/health-information/digestive-diseases/constipation/eating-diet-nutrition',
    checkedOn: '2026-10-09',
  );
  static const constipationCare = KnowledgeSource(
    id: 'niddk-constipation-care',
    organization: 'NIDDK',
    title: '便秘的生活方式与治疗',
    url:
        'https://www.niddk.nih.gov/health-information/digestive-diseases/constipation/treatment',
    checkedOn: '2026-10-09',
  );
  static const constipationSymptoms = KnowledgeSource(
    id: 'niddk-constipation-symptoms',
    organization: 'NIDDK',
    title: '便秘症状与就医时机',
    url:
        'https://www.niddk.nih.gov/health-information/digestive-diseases/constipation/symptoms-causes',
    checkedOn: '2026-10-09',
  );
  static const diarrheaFood = KnowledgeSource(
    id: 'niddk-food-diary',
    organization: 'NIDDK',
    title: '腹泻与饮食记录',
    url:
        'https://www.niddk.nih.gov/health-information/digestive-diseases/diarrhea/eating-diet-nutrition',
    checkedOn: '2026-10-09',
  );
  static const diarrheaSymptoms = KnowledgeSource(
    id: 'niddk-diarrhea-symptoms',
    organization: 'NIDDK',
    title: '腹泻、脱水与就医时机',
    url:
        'https://www.niddk.nih.gov/health-information/digestive-diseases/diarrhea/symptoms-causes',
    checkedOn: '2026-10-09',
  );
  static const bristol = KnowledgeSource(
    id: 'nhs-bristol',
    organization: 'University Hospitals Plymouth NHS Trust',
    title: '成人肠道资料中的 Bristol 形态表',
    url:
        'https://www.plymouthhospitals.nhs.uk/display-pil/pil-loss-of-bowel-motions-in-adults-4092/',
    checkedOn: '2026-10-09',
  );
  static const stoolColor = KnowledgeSource(
    id: 'medlineplus-color',
    organization: 'MedlinePlus',
    title: '黑色或柏油样便',
    url: 'https://medlineplus.gov/ency/article/003130.htm',
    checkedOn: '2026-10-09',
  );
  static const giBleeding = KnowledgeSource(
    id: 'niddk-bleeding',
    organization: 'NIDDK',
    title: '消化道出血的症状',
    url:
        'https://www.niddk.nih.gov/health-information/digestive-diseases/gastrointestinal-bleeding/symptoms-causes',
    checkedOn: '2026-10-09',
  );
  static const urgentBleeding = KnowledgeSource(
    id: 'nhs-bleeding',
    organization: 'NHS',
    title: '便血的就医与急救提示',
    url:
        'https://www.nhs.uk/symptoms/bleeding-from-the-bottom-rectal-bleeding/',
    checkedOn: '2026-10-09',
  );

  static const List<KnowledgeTip> tips = [
    KnowledgeTip(
      id: 'fiber-water',
      category: KnowledgeCategory.food,
      title: '纤维可以慢慢增加',
      summary: '全谷物、豆类、蔬果和坚果是纤维来源。逐步调整，比突然大量增加更容易适应。',
      details: [
        '便秘饮食建议同时考虑纤维和水分；适合的饮水量应结合健康情况向医护人员确认。',
        '已有饮食或饮水医嘱时，按医嘱安排，不用固定杯数套所有人。',
      ],
      sources: [fiberDiet],
      tags: ['纤维', '饮水'],
    ),
    KnowledgeTip(
      id: 'food-pattern',
      category: KnowledgeCategory.food,
      title: '食物日记记录线索，不证明原因',
      summary: '腹泻反复出现时，可以记下吃喝内容、症状和出现时间，带给医生讨论。',
      details: [
        '同一天发生，不等于食物就是原因。不要只凭一次记录自行长期排除某类食物。',
        '饮食调整要兼顾营养，需要时咨询医生或营养师。',
      ],
      sources: [diarrheaFood],
      tags: ['食物日记', '个体差异'],
    ),
    KnowledgeTip(
      id: 'bristol-firm',
      category: KnowledgeCategory.shape,
      title: '形态偏硬，也记下是否费力',
      summary: '1～2 型描述颗粒状或成块、偏硬的外观。可以同时记录费力、疼痛和持续时间。',
      details: ['便秘评估还要结合次数和症状，单次形态不能独立判断。', '若伴便血、持续腹痛、呕吐或无法排气，请尽快就医。'],
      sources: [bristol, constipationSymptoms],
      tags: ['Bristol', '观察'],
    ),
    KnowledgeTip(
      id: 'bristol-middle',
      category: KnowledgeCategory.shape,
      title: '形态是观察信息，不是健康评分',
      summary: 'Bristol 分类用于描述外观。成形、柔软的记录，也不能用来排除其他身体问题。',
      details: [
        '3 型表面可有裂纹，4 型较光滑、柔软；1～2 型偏硬，6～7 型偏松散或水样。',
        '无论哪种形态，都要结合伴随不适；有便血等变化时应联系医生。',
      ],
      sources: [bristol, giBleeding],
      tags: ['Bristol', '形态'],
    ),
    KnowledgeTip(
      id: 'bristol-loose',
      category: KnowledgeCategory.shape,
      title: '稀便时，留意次数和伴随不适',
      summary: '6～7 型描述松散、糊状或水样外观。记录次数、持续时间以及有无腹痛、发热等情况。',
      details: ['一次稀便不等于已经诊断为腹泻。', '明显口渴、口干、尿量减少或头晕可能提示脱水；出现这些情况请尽快联系医生。'],
      sources: [bristol, diarrheaSymptoms],
      tags: ['Bristol', '稀便'],
    ),
    KnowledgeTip(
      id: 'after-meal',
      category: KnowledgeCategory.habit,
      title: '有便意时，给自己一点时间',
      summary: '进食会促进结肠活动；有便意时及时去，尽量放松，不必为了打卡强行排便。',
      details: ['便秘管理中，医护人员有时会建议尝试固定的饭后时段。', '脚下有稳固支撑可能更舒适；是否调整习惯应结合自己的情况。'],
      sources: [constipationCare],
      tags: ['习惯', '放松'],
    ),
    KnowledgeTip(
      id: 'color-food',
      category: KnowledgeCategory.color,
      title: '食物会改颜色，但别自行排除出血',
      summary: '甜菜根、蓝莓、铁剂或含铋药物可能改变颜色；这不能用来排除出血。',
      details: [
        '出现血便、黑色柏油样便，或伴头晕、呕血时，请尽快就医，不要先等待观察饮食。',
        '带上近期食物、用药及变化时间，方便医生判断。不要自行停药。',
      ],
      sources: [stoolColor, constipationCare],
      tags: ['颜色', '用药'],
    ),
    KnowledgeTip(
      id: 'urgent-help',
      category: KnowledgeCategory.alert,
      title: '持续大量出血，请立即求助',
      summary: '出血不停、便中大量血液或大血块，或伴晕厥、意识不清时，请立即联系当地急救服务。',
      details: ['不要等待在 App 中完成记录或靠小纸条判断原因。', '呕血或像咖啡渣的呕吐物也需要立即就医。'],
      sources: [urgentBleeding, giBleeding],
      tags: ['立即求助'],
    ),
    KnowledgeTip(
      id: 'red-flag',
      category: KnowledgeCategory.alert,
      title: '这些变化应尽快联系医生',
      summary: '便血、黑色柏油样便、严重或持续腹痛、明显脱水等情况，不宜只靠记录观察。',
      details: [
        '成人腹泻超过 2 天、高热或一天 6 次及以上稀便，应立即联系医生；伴上述症状不必等够天数。',
        '便秘经自我照护仍未改善应就医；伴无意体重下降、呕吐或无法排气等变化时，应尽快就医。',
        '儿童腹泻、孕期、超过 65 岁、正在用抗生素或免疫功能较弱的人，需要更早咨询医生，不要套用成人等待时长。',
      ],
      sources: [diarrheaSymptoms, constipationSymptoms, giBleeding],
      tags: ['就医'],
    ),
  ];

  static KnowledgeTip? byId(String id) {
    for (final tip in tips) {
      if (tip.id == id) return tip;
    }
    return null;
  }

  static List<KnowledgeTip> forCategory(KnowledgeCategory category) =>
      category == KnowledgeCategory.all
      ? tips
      : tips.where((tip) => tip.category == category).toList(growable: false);

  static KnowledgeTip featuredFor(int? bristolType) {
    if (bristolType == 1 || bristolType == 2) return byId('bristol-firm')!;
    if (bristolType == 6 || bristolType == 7) return byId('bristol-loose')!;
    return byId('bristol-middle')!;
  }
}
