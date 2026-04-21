import 'package:flutter/material.dart';

class SleepEncyclopediaCategory {
  const SleepEncyclopediaCategory({
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.topicSlugs,
  });

  final String slug;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color accentColor;
  final List<String> topicSlugs;
}

class SleepEncyclopediaTopic {
  const SleepEncyclopediaTopic({
    required this.slug,
    required this.categorySlug,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.readTime,
    required this.heroLabel,
    required this.keyTakeaway,
    required this.whyItHappens,
    required this.tonightActions,
    required this.watchouts,
    required this.relatedTopicSlugs,
    this.imageAsset,
  });

  final String slug;
  final String categorySlug;
  final String title;
  final String subtitle;
  final String summary;
  final String readTime;
  final String heroLabel;
  final String keyTakeaway;
  final List<String> whyItHappens;
  final List<String> tonightActions;
  final List<String> watchouts;
  final List<String> relatedTopicSlugs;
  final String? imageAsset;
}

abstract final class SleepEncyclopediaContent {
  static const List<SleepEncyclopediaCategory> categories =
      <SleepEncyclopediaCategory>[
        SleepEncyclopediaCategory(
          slug: 'fall-asleep',
          title: '入睡这件事',
          subtitle: '适合睡前快速看',
          description: '围绕难入睡、越躺越清醒、睡前习惯调整这些真实场景展开。',
          icon: Icons.bedtime_rounded,
          accentColor: Color(0xFF1F8A70),
          topicSlugs: <String>[
            'cant-fall-asleep',
            'phone-before-sleep',
            'racing-thoughts',
          ],
        ),
        SleepEncyclopediaCategory(
          slug: 'schedule-reset',
          title: '作息调整',
          subtitle: '帮你把节奏拉回来',
          description: '针对熬夜、补觉、午睡和白天困倦做更实际的说明。',
          icon: Icons.schedule_rounded,
          accentColor: Color(0xFF3E7CB1),
          topicSlugs: <String>[
            'stay-up-late-recovery',
            'nap-length',
            'sleep-enough-still-tired',
          ],
        ),
        SleepEncyclopediaCategory(
          slug: 'dorm-environment',
          title: '宿舍与环境',
          subtitle: '解决外部干扰',
          description: '把噪声、灯光、温度和宿舍协作说清楚，方便直接落地。',
          icon: Icons.home_work_rounded,
          accentColor: Color(0xFFB86B4B),
          topicSlugs: <String>[
            'roommate-noise',
            'light-and-temperature',
            'sleep-routine-kit',
          ],
        ),
        SleepEncyclopediaCategory(
          slug: 'stress-and-dreams',
          title: '压力与梦境',
          subtitle: '读起来更轻一点',
          description: '解释梦多、压力感、夜里脑子停不下来时可以怎么理解。',
          icon: Icons.auto_stories_rounded,
          accentColor: Color(0xFF7A5EA6),
          topicSlugs: <String>[
            'dreaming-a-lot',
            'stress-and-sleep',
            'wake-up-at-night',
          ],
        ),
      ];

  static const List<SleepEncyclopediaTopic> topics = <SleepEncyclopediaTopic>[
    SleepEncyclopediaTopic(
      slug: 'cant-fall-asleep',
      categorySlug: 'fall-asleep',
      title: '今晚睡不着时，可以先做什么',
      subtitle: '不是立刻逼自己入睡，而是先把身体降速。',
      summary:
          '很多人一发现自己睡不着，就会开始焦虑地数时间、反复看手机，结果越急越清醒。更有效的做法是先从灯光、呼吸、动作节奏开始，让身体收到“现在可以休息”的信号。',
      readTime: '2 分钟',
      heroLabel: '睡前急救',
      keyTakeaway: '睡不着时先降刺激，不要一边焦虑一边硬熬在床上。',
      whyItHappens: <String>[
        '刚躺下时，大脑还停留在白天的任务模式，注意力没有顺利切换。',
        '担心“明天起不来”的压力，会让身体进入更警觉的状态。',
        '灯光、手机和反复看时间，都会强化“我还没睡着”这件事。',
      ],
      tonightActions: <String>[
        '先把屏幕亮度降下来，最好直接离开手机 10 到 15 分钟。',
        '如果躺了很久还清醒，可以起身做一件低刺激的小事，比如慢慢喝水或整理床边。',
        '回到床上后，先关注呼吸和肩颈放松，不要反复判断自己有没有睡意。',
      ],
      watchouts: <String>[
        '如果连续很多天都很难入睡，而且已经明显影响白天状态，就不要只靠临时技巧硬扛。',
        '如果你会因为失眠而频繁服用不明助眠产品，也需要更谨慎一些。',
      ],
      relatedTopicSlugs: <String>['racing-thoughts', 'phone-before-sleep'],
      imageAsset: 'assets/images/sleep_encyclopedia/topic_relax_neon.jpg',
    ),
    SleepEncyclopediaTopic(
      slug: 'phone-before-sleep',
      categorySlug: 'fall-asleep',
      title: '睡前总想刷手机，怎么调得没那么痛苦',
      subtitle: '不要一刀切，而是先缩短最后那段高刺激时间。',
      summary:
          '很多人不是不知道睡前少玩手机更好，而是很难一下停住。与其给自己设特别理想化的规则，不如先把“最后 20 分钟”变得更安静、更可执行。',
      readTime: '2 分钟',
      heroLabel: '习惯调整',
      keyTakeaway: '先减少睡前最后一段时间的刺激强度，比强行完全不用手机更容易坚持。',
      whyItHappens: <String>[
        '短视频、聊天和信息刷新会不断拉高大脑兴奋度。',
        '手机会让你误以为自己在放松，但注意力其实一直在被拉扯。',
        '一旦把刷手机当成固定睡前仪式，停下来就会感觉空落落的。',
      ],
      tonightActions: <String>[
        '把“刷到睡着”改成“刷到固定时间后切换到更轻的内容”，比如白噪音或舒缓播客。',
        '先只要求自己提前 15 分钟放下手机，连续几天后再慢慢拉长。',
        '把充电位置放远一点，避免躺下后又顺手拿回来。',
      ],
      watchouts: <String>[
        '不要一边告诉自己放松，一边继续看很刺激或很社交化的内容。',
        '如果你总在深夜因为工作消息或群聊被打断，通知管理也要一起调整。',
      ],
      relatedTopicSlugs: <String>['cant-fall-asleep', 'stay-up-late-recovery'],
      imageAsset: 'assets/images/sleep_encyclopedia/topic_books_mug.jpg',
    ),
    SleepEncyclopediaTopic(
      slug: 'racing-thoughts',
      categorySlug: 'fall-asleep',
      title: '脑子停不下来时，怎么帮自己慢下来',
      subtitle: '重点不是把念头清空，而是别继续追着它跑。',
      summary:
          '睡前想法多并不罕见，真正影响入睡的往往不是“有念头”，而是不断追着每个念头展开。这个时候，简单的承接和卸载，比逼自己什么都别想更有效。',
      readTime: '3 分钟',
      heroLabel: '情绪降速',
      keyTakeaway: '允许念头出现，但不要继续展开它们，是比较温和也更现实的做法。',
      whyItHappens: <String>[
        '晚上环境安静后，白天被压住的任务感和情绪更容易冒出来。',
        '一旦开始复盘、后悔或设想明天，很容易越想越清醒。',
        '压力累积时，大脑会把睡前当成唯一有空处理事情的时段。',
      ],
      tonightActions: <String>[
        '拿纸记下现在最占脑子的 1 到 3 件事，只写关键词，不展开。',
        '对自己说一句简单的话，比如“这件事我明天再处理”，帮助大脑暂时收尾。',
        '如果还是停不下来，可以配合缓慢呼吸或轻音乐，把注意力放回身体感受。',
      ],
      watchouts: <String>[
        '不要在床上继续做复杂计划，这会把休息空间变成工作空间。',
        '如果情绪反复强烈到难以自控，就不只是普通的睡前想太多了。',
      ],
      relatedTopicSlugs: <String>['cant-fall-asleep', 'stress-and-sleep'],
      imageAsset: 'assets/images/sleep_encyclopedia/topic_worry_less.jpg',
    ),
    SleepEncyclopediaTopic(
      slug: 'stay-up-late-recovery',
      categorySlug: 'schedule-reset',
      title: '熬夜之后，第二天怎么补救比较稳妥',
      subtitle: '重点是稳住节奏，而不是把作息补得更乱。',
      summary:
          '熬夜后的第二天，很多人会选择狂喝咖啡、白天睡很久、晚上再继续拖，结果节奏更乱。补救最有用的不是“补满”，而是把白天和晚上重新分开。',
      readTime: '2 分钟',
      heroLabel: '熬夜补救',
      keyTakeaway: '熬夜后的补救重点是保住晚上的主睡眠窗口，而不是白天无限补觉。',
      whyItHappens: <String>[
        '熬夜会同时消耗精力和打乱生物节律，所以第二天容易又困又乱。',
        '白天补得太多，晚上反而更难重新进入正常睡意。',
        '咖啡因、外卖和久坐常常会让疲惫感被拖得更长。',
      ],
      tonightActions: <String>[
        '白天如果一定要补觉，尽量控制在短时间，不要睡到傍晚。',
        '晚饭后开始把节奏放缓，别把“今天已经乱了”当成继续熬的理由。',
        '今晚尽量回到平时的上床时间附近，让身体重新找到熟悉节奏。',
      ],
      watchouts: <String>[
        '不要指望一次大补觉把几天的缺口全部补回来。',
        '如果熬夜已经变成长期模式，就要从日常安排上调整，而不是天天补救。',
      ],
      relatedTopicSlugs: <String>['nap-length', 'phone-before-sleep'],
      imageAsset: 'assets/images/sleep_encyclopedia/topic_daylight_chairs.jpg',
    ),
    SleepEncyclopediaTopic(
      slug: 'nap-length',
      categorySlug: 'schedule-reset',
      title: '午睡多久比较合适',
      subtitle: '午睡不是越久越赚，醒来舒服和晚上能睡才更重要。',
      summary:
          '午睡对恢复精神有帮助，但时间过长、太晚开始，都会影响晚上的主睡眠。一个更实用的判断标准是：睡醒后有没有更清醒，以及晚上有没有更难睡。',
      readTime: '2 分钟',
      heroLabel: '白天恢复',
      keyTakeaway: '午睡更像提神工具，时间控制比“睡得久”更重要。',
      whyItHappens: <String>[
        '白天短暂休息能降低疲劳感，但睡得太深后醒来反而更昏沉。',
        '午后太晚补觉，会削弱晚上积累起来的睡意。',
        '很多人午睡困难，不是因为不适合午睡，而是开始时间和环境不稳定。',
      ],
      tonightActions: <String>[
        '把午睡放在白天较早的时段，避免拖到傍晚。',
        '如果只是提神，可以把午睡目标设得更轻，不追求进入很深的睡眠。',
        '午睡后尽量晒一会儿自然光或活动一下，帮助身体切回白天状态。',
      ],
      watchouts: <String>[
        '如果你午睡后常常头晕、心慌或更累，也需要观察是不是其他因素在影响状态。',
        '不要因为白天睡得不错，就忽视晚上持续睡不好的问题。',
      ],
      relatedTopicSlugs: <String>[
        'stay-up-late-recovery',
        'sleep-enough-still-tired',
      ],
      imageAsset: 'assets/images/sleep_encyclopedia/topic_blue_chairs.jpg',
    ),
    SleepEncyclopediaTopic(
      slug: 'sleep-enough-still-tired',
      categorySlug: 'schedule-reset',
      title: '明明睡了挺久，为什么还是困',
      subtitle: '时长只是一个维度，恢复感更受节奏和质量影响。',
      summary:
          '很多人把“睡了几个小时”直接等同于“休息够了”，但真正的恢复感还和入睡时间、夜间醒来次数、起床节奏、白天活动量都有关系。睡得久但还是困，并不少见。',
      readTime: '3 分钟',
      heroLabel: '恢复感',
      keyTakeaway: '睡眠时长重要，但并不是唯一指标，睡得久不等于恢复得好。',
      whyItHappens: <String>[
        '作息时间很飘时，即使总时长够，身体也可能没恢复到最佳状态。',
        '夜里反复醒来、浅睡较多，会让整体恢复感打折。',
        '白天久坐、很少见光，也会让困倦感一直拖着不散。',
      ],
      tonightActions: <String>[
        '先回看最近几天是不是入睡时间太不稳定，而不是只盯着时长。',
        '睡前把房间亮度、温度和手机使用一起整理一下，帮助提升睡眠连续性。',
        '明天白天适当活动和接触自然光，别一直闷在室内补精神。',
      ],
      watchouts: <String>[
        '如果困倦持续很久，而且影响学习、工作或情绪，就需要进一步留意。',
        '伴随明显打鼾、呼吸不顺或长期晨起头痛时，也不建议只靠自调。',
      ],
      relatedTopicSlugs: <String>['nap-length', 'wake-up-at-night'],
      imageAsset: 'assets/images/sleep_encyclopedia/topic_tea_blanket.jpg',
    ),
    SleepEncyclopediaTopic(
      slug: 'roommate-noise',
      categorySlug: 'dorm-environment',
      title: '室友太吵影响睡眠，怎么处理更现实',
      subtitle: '不是只靠忍，而是靠提前协商和环境缓冲。',
      summary:
          '宿舍睡眠问题很少是某一个人完全解决的，更多时候需要一点协商、一点工具和一点边界感。真正有效的方案通常不是忍耐，而是把容易冲突的时段和动作提前说清楚。',
      readTime: '3 分钟',
      heroLabel: '宿舍场景',
      keyTakeaway: '先把规则说清楚，再做环境缓冲，比一味忍耐更能长期解决问题。',
      whyItHappens: <String>[
        '宿舍作息不一致时，晚睡的人和早睡的人天然容易互相影响。',
        '噪声不一定很大，但不确定、断断续续的声音特别容易打断入睡。',
        '很多矛盾不是因为声音本身，而是因为没有提前形成共识。',
      ],
      tonightActions: <String>[
        '先挑最影响你的 1 到 2 个点沟通，比如外放视频、关门声或开灯时间。',
        '给自己准备基础缓冲方案，比如耳塞、白噪音或固定睡前音乐。',
        '把“几点后尽量轻声”说成可执行的规则，而不是笼统地说“别太吵”。',
      ],
      watchouts: <String>[
        '不要等到自己已经很烦躁时才沟通，那样更容易变成情绪冲突。',
        '如果宿舍里每个人都很累，规则最好简单，不要设计得太复杂。',
      ],
      relatedTopicSlugs: <String>['light-and-temperature', 'sleep-routine-kit'],
      imageAsset: 'assets/images/sleep_encyclopedia/topic_relax_room.jpg',
    ),
    SleepEncyclopediaTopic(
      slug: 'light-and-temperature',
      categorySlug: 'dorm-environment',
      title: '灯光和温度，对睡意到底有多大影响',
      subtitle: '它们看起来像小事，但很容易决定你能不能顺利睡着。',
      summary:
          '很多人觉得自己睡不好主要是心理问题，但实际上环境信号非常直接。灯太亮、被窝太闷、空调忽冷忽热，都会让身体很难稳定进入休息状态。',
      readTime: '2 分钟',
      heroLabel: '环境信号',
      keyTakeaway: '舒服的环境不一定要完美，但最好稳定，别忽冷忽热、忽明忽暗。',
      whyItHappens: <String>[
        '身体很依赖光线变化来判断是否接近休息时间。',
        '过热或过冷都会让人更容易翻身、醒来或觉得烦躁。',
        '环境反复变化时，大脑更难完全放下警觉。',
      ],
      tonightActions: <String>[
        '睡前提前把主灯关掉，改成更柔和的小灯或床边光源。',
        '把被褥、空调和风扇调到一个更稳定的状态，避免半夜再反复调整。',
        '如果宿舍条件有限，至少先保证自己床位附近的光线和体感更舒服。',
      ],
      watchouts: <String>[
        '不要一边喊着要睡，一边继续开着很亮的顶灯整理东西。',
        '如果你总在夜里因为冷醒或热醒，环境问题就已经值得单独处理了。',
      ],
      relatedTopicSlugs: <String>['roommate-noise', 'cant-fall-asleep'],
      imageAsset: 'assets/images/sleep_encyclopedia/topic_hammock_garden.jpg',
    ),
    SleepEncyclopediaTopic(
      slug: 'sleep-routine-kit',
      categorySlug: 'dorm-environment',
      title: '宿舍睡前准备，可以固定成一套小流程',
      subtitle: '越简单越容易坚持，关键是重复和稳定。',
      summary:
          '当宿舍环境不完全可控时，一套固定的睡前小流程能帮你更快进入休息状态。它不需要复杂，也不需要每一步都完美，只要重复 enough，就会慢慢形成身体记忆。',
      readTime: '2 分钟',
      heroLabel: '睡前仪式',
      keyTakeaway: '睡前流程不是形式感，而是给身体一个稳定的“准备休息”提示。',
      whyItHappens: <String>[
        '重复的小动作会让大脑更快识别“今天快结束了”。',
        '固定流程能减少临睡前的犹豫和拖延。',
        '在宿舍这种共享环境里，个人流程越清楚，越能减少外部干扰感。',
      ],
      tonightActions: <String>[
        '先选 3 个你能稳定做到的小动作，比如洗漱、收手机、开轻音乐。',
        '把耗时长、容易拖住你的步骤移出最后 20 分钟。',
        '尽量让流程顺序固定，这样更容易形成习惯。',
      ],
      watchouts: <String>[
        '不要把流程做得太满，越复杂越容易半途放弃。',
        '如果流程里包含继续刷手机或做任务，它就很难真正起到降速作用。',
      ],
      relatedTopicSlugs: <String>['phone-before-sleep', 'roommate-noise'],
      imageAsset: 'assets/images/sleep_encyclopedia/topic_beach_swing.jpg',
    ),
    SleepEncyclopediaTopic(
      slug: 'dreaming-a-lot',
      categorySlug: 'stress-and-dreams',
      title: '最近总觉得梦很多，是睡不好了吗',
      subtitle: '梦多不一定等于差，但它可能在提醒你最近比较忙或比较紧绷。',
      summary:
          '很多人会把“梦多”直接理解为“没睡好”，但这两者并不完全等同。更值得观察的是：你醒来后是否疲惫、梦是否反复压迫感很强、最近是不是压力偏高。',
      readTime: '2 分钟',
      heroLabel: '梦境观察',
      keyTakeaway: '梦多本身不一定是问题，更重要的是它有没有伴随疲惫、紧张和持续不适。',
      whyItHappens: <String>[
        '近期压力、情绪波动或睡前信息量增加时，梦境体验会更鲜明。',
        '如果你在醒来前处于更容易记住梦的阶段，就会觉得自己“整晚都在做梦”。',
        '睡前内容太杂、太刺激，也会让梦的情节更跳跃。',
      ],
      tonightActions: <String>[
        '如果你愿意，可以简单记下梦里的关键词，帮助分辨它是随机整理还是持续压力。',
        '睡前把信息输入降下来，比如少刷高刺激内容，让大脑别带着太多碎片入睡。',
        '醒来后别急着立刻判断自己睡得差，先感受身体和情绪状态。',
      ],
      watchouts: <String>[
        '如果反复出现压迫感很强的梦，或者醒来后一直心慌，就值得更重视。',
        '梦境只是信号之一，不建议单靠“梦多”判断全部睡眠质量。',
      ],
      relatedTopicSlugs: <String>['stress-and-sleep', 'wake-up-at-night'],
      imageAsset: 'assets/images/sleep_encyclopedia/topic_dusk_ocean.jpg',
    ),
    SleepEncyclopediaTopic(
      slug: 'stress-and-sleep',
      categorySlug: 'stress-and-dreams',
      title: '压力大的时候，睡眠为什么会先乱掉',
      subtitle: '睡眠往往是最先被压力牵动的那部分。',
      summary:
          '压力不一定总是表现成明显情绪，它也可能先表现成晚睡、浅睡、容易醒、早上起不来。很多时候你以为自己只是最近忙，其实睡眠已经在替你发出提醒。',
      readTime: '3 分钟',
      heroLabel: '压力关联',
      keyTakeaway: '压力会先改变睡眠节奏和恢复感，睡眠变化本身就值得被看见。',
      whyItHappens: <String>[
        '压力状态下，身体更容易维持警觉，放松速度会变慢。',
        '白天压住的情绪和任务，常常在夜里集中冒出来。',
        '当恢复感变差时，第二天又更难应对压力，于是形成循环。',
      ],
      tonightActions: <String>[
        '先别急着解决所有事，睡前只做“收尾”和“减速”两件事。',
        '给明天留一个最小行动清单，帮助自己停止在夜里继续计划。',
        '如果最近特别紧绷，睡前安排可以比平时更简单、更轻一点。',
      ],
      watchouts: <String>[
        '如果你已经连续很久都睡不踏实，而且情绪波动明显，就别只把它当作普通忙碌。',
        '靠熬夜、暴食或刷手机来缓冲压力，通常只会把睡眠拉得更乱。',
      ],
      relatedTopicSlugs: <String>['racing-thoughts', 'dreaming-a-lot'],
      imageAsset: 'assets/images/sleep_encyclopedia/topic_sunrise_bridge.jpg',
    ),
    SleepEncyclopediaTopic(
      slug: 'wake-up-at-night',
      categorySlug: 'stress-and-dreams',
      title: '半夜容易醒，是哪些因素在捣乱',
      subtitle: '有时是环境，有时是节奏，有时是白天压力在延续。',
      summary:
          '半夜醒来并不一定稀奇，但如果醒来后很难再睡，或者出现得越来越频繁，就值得回头看一看最近的睡前节奏、宿舍环境和白天压力有没有一起在推高这个问题。',
      readTime: '2 分钟',
      heroLabel: '夜间醒来',
      keyTakeaway: '夜里容易醒通常不是单一原因，节奏、环境和压力常常会叠加。',
      whyItHappens: <String>[
        '噪声、光线、冷热变化都可能在夜里把人拉醒。',
        '入睡前太疲惫或太兴奋，夜间睡眠连续性也可能受影响。',
        '当压力积累较多时，夜里醒来后会更容易重新开始想事情。',
      ],
      tonightActions: <String>[
        '先排查最基础的环境因素，比如灯光缝隙、空调温度和噪声来源。',
        '睡前不要让节奏忽快忽慢，尤其别在临睡前突然继续工作或激烈社交。',
        '如果夜里醒来，不要马上开始查看消息或时间，先给自己几分钟缓冲。',
      ],
      watchouts: <String>[
        '如果夜醒越来越频繁，而且伴随明显不适，就不建议只靠经验硬调。',
        '夜里清醒后反复刷手机，通常会让再次入睡更难。',
      ],
      relatedTopicSlugs: <String>[
        'light-and-temperature',
        'sleep-enough-still-tired',
      ],
      imageAsset: 'assets/images/sleep_encyclopedia/topic_lake_bench.jpg',
    ),
  ];

  static final Map<String, SleepEncyclopediaCategory> _categoryBySlug =
      <String, SleepEncyclopediaCategory>{
        for (final SleepEncyclopediaCategory category in categories)
          category.slug: category,
      };

  static final Map<String, SleepEncyclopediaTopic> _topicBySlug =
      <String, SleepEncyclopediaTopic>{
        for (final SleepEncyclopediaTopic topic in topics) topic.slug: topic,
      };

  static SleepEncyclopediaCategory? categoryBySlug(String slug) =>
      _categoryBySlug[slug];

  static SleepEncyclopediaTopic? topicBySlug(String slug) => _topicBySlug[slug];

  static List<SleepEncyclopediaTopic> topicsForCategory(String categorySlug) {
    return topics
        .where(
          (SleepEncyclopediaTopic topic) => topic.categorySlug == categorySlug,
        )
        .toList(growable: false);
  }

  static List<SleepEncyclopediaTopic> relatedTopics(
    SleepEncyclopediaTopic topic,
  ) {
    return topic.relatedTopicSlugs
        .map(topicBySlug)
        .whereType<SleepEncyclopediaTopic>()
        .toList(growable: false);
  }

  static List<SleepEncyclopediaTopic> featuredTopics() {
    const List<String> slugs = <String>[
      'cant-fall-asleep',
      'stay-up-late-recovery',
      'roommate-noise',
      'stress-and-sleep',
    ];
    return slugs
        .map(topicBySlug)
        .whereType<SleepEncyclopediaTopic>()
        .toList(growable: false);
  }
}
