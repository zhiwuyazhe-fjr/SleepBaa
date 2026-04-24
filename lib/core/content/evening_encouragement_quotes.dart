import 'dart:math';

import 'package:sleep_dorm_app/core/models/app_models.dart';

/// Picks one random line for the profile encouragement card for this 20:00 period.
///
/// [mood] is `null` when the user skipped welcome — uses the impatient/unknown pool.
String pickRandomEncouragementLine({NightMood? mood, Random? random}) {
  final Random r = random ?? Random();
  final List<String> pool = mood == null ? quotesForUnknown() : quotesFor(mood);
  return pool[r.nextInt(pool.length)];
}

List<String> quotesFor(NightMood mood) {
  return switch (mood) {
    NightMood.happy => _happyQuotes,
    NightMood.calm => _calmQuotes,
    NightMood.sad => _sadQuotes,
  };
}

List<String> quotesForUnknown() => _impatientQuotes;

const List<String> _happyQuotes = <String>[
  '“人生得意须尽欢，莫使金樽空对月。”——李白',
  '“春风得意马蹄疾，一日看尽长安花。”——孟郊',
  '“笑看人间沉浮事，淡观云卷云舒时。”——陈继儒',
  '“幸福不是拥有更多，而是对当下感到满足。”——Epictetus',
  '“快乐是你允许自己拥有的状态。”——Hugh Downs',
  '“人真正活着，是在他感到喜悦的时候。”——Romain Rolland',
  '“幸福存在于微小而确定的瞬间。”——Virginia Woolf',
  '“最简单的快乐，往往最持久。”——Tolstoy',
  '“笑，是人与世界最短的距离。”——Victor Borge',
  '“享受你已经拥有的，而不是追逐你没有的。”——Dale Carnegie',
  '“生活的美，在于你如何感受它。”——Thoreau',
  '“真正的快乐来自内心的平和。”——Dalai Lama',
  '“幸福不是终点，而是一种走路的方式。”——Margaret Lee Runbeck',
  '“你此刻的呼吸，就是生命的礼物。”——Thich Nhat Hanh',
  '“快乐不是偶然，而是一种选择。”——Jim Rohn',
  '“让自己快乐，是最基本的责任。”——Oscar Wilde',
  '“心轻一点，世界就亮一点。”——小眠',
  '“美好常常藏在最不起眼的地方。”——Proust',
  '“快乐的人，并不是拥有最多的人。”——Helen Keller',
  '“幸福来自你如何看待世界。”——Einstein',
  '“当下这一刻，已经足够完整。”——Eckhart Tolle',
  '“你感受到的，就是你的世界。”——William James',
  '“活在当下，是唯一真正的奢侈。”——小眠',
];

const List<String> _calmQuotes = <String>[
  '“自然从不匆忙，却万事已成。”——Lao Tzu',
  '“行到水穷处，坐看云起时。”——王维',
  '“心闲天地宽，意静岁月长。”——白居易',
  '“晚来天欲雪，能饮一杯无？”——白居易',
  '“平静，是内心的力量。”——Marcus Aurelius',
  '“不要试图控制浪潮，学会在上面呼吸。”——Jon Kabat-Zinn',
  '“安静，是灵魂的栖息地。”——Hermann Hesse',
  '“真正的自由，是不被情绪牵引。”——Epictetus',
  '“慢一点，世界不会消失。”——Carl Honoré',
  '“放下，并不是失去，而是轻盈。”——Buddha',
  '“越安静，越能听见自己。”——Rumi',
  '“你无需成为什么，才能安宁。”——Alan Watts',
  '“呼吸，就是你随时可以回家的路。”——Thich Nhat Hanh',
  '“平和不是没有风暴，而是在风暴中不被卷走。”——小眠',
  '“接受，是内心真正的松弛。”——Carl Rogers',
  '“当你停止对抗，世界也变柔软。”——Eckhart Tolle',
  '“安静下来，答案自然浮现。”——Lao Tzu',
  '“生活不需要被解决，只需要被体验。”——Kierkegaard',
  '“你可以什么都不做，也依然完整。”——Alan Watts',
  '“内心的节奏，比世界更重要。”——小眠',
  '“慢，是对生活的尊重。”——Milan Kundera',
  '“平静，是最高级的清醒。”——小眠',
  '“今晚，不必成为更好的人。”——小眠',
  '“泰山崩于前而色不变，麋鹿兴于左而目不瞬”——苏洵',
];

const List<String> _sadQuotes = <String>[
  '“伤口，是光进入你的地方。”——Rumi',
  '“天生我材必有用，千金散尽还复来。”——李白',
  '“山重水复疑无路，柳暗花明又一村。”——陆游',
  '“你所经历的，会成为你的一部分力量。”——Nietzsche',
  '“即使缓慢，也仍在前进。”——Confucius',
  '“夜越黑，星星越亮。”——Dostoevsky',
  '“疲惫不是失败，是你已经很努力。”——小眠',
  '“人不需要时时坚强。”——Brené Brown',
  '“低谷不是终点，而是转弯。”——小眠',
  '“你可以停下来，但不要否定自己。”——Carl Rogers',
  '“难过的时候，允许自己难过。”——小眠',
  '“生命的意义，常在困境中显现。”——Viktor Frankl',
  '“有些日子，本来就只适合活着。”——小眠',
  '“黑暗中走路，本身就是勇气。”——小眠',
  '“不要急着好起来。”——小眠',
  '“你不是问题，你只是正在经历问题。”——小眠',
  '“风会停的。”——小眠',
  '“你没有落后，你只是走在自己的节奏里。”——小眠',
  '“悲伤，是对重要事物的回应。”——小眠',
  '“一切都会过去，但你会留下来。”——小眠',
  '“你已经比昨天更接近出口。”——小眠',
  '“今晚，活下来就很好。”——小眠',
];

const List<String> _impatientQuotes = <String>[
  '“你无法加快时间，只能调整自己。”——Seneca',
  '“欲速则不达，见小利则大事不成。”——孔子',
  '“静而后能安，安而后能虑。”——《大学》',
  '“每临大事有静气，不信今时无古贤。”——翁同龢',
  '“耐心，是力量的一种形式。”——Tolstoy',
  '“焦虑来自想控制不可控的事。”——Epictetus',
  '“慢，是一种更快的方式。”——Zen proverb',
  '“不要为了未来，透支现在。”——小眠',
  '“速度，不等于方向。”——Einstein',
  '“急，只会让你更远离答案。”——小眠',
  '“事情会发生，在它该发生的时候。”——Taoism',
  '“控制越多，失去越多。”——Lao Tzu',
  '“你不需要马上解决一切。”——小眠',
  '“一步一步，已经足够。”——Confucius',
  '“真正重要的，从不仓促。”——Rilke',
  '“焦虑，是对未来的过度预支。”——小眠',
  '“停一下，并不会让你落后。”——小眠',
  '“慢下来，才看得清方向。”——小眠',
  '“世界不会因为你着急而变快。”——小眠',
  '“给事情一点时间。”——小眠',
  '“节奏对了，事情自然会发生。”——小眠',
  '“你不需要现在就证明一切。”——小眠',
  '“今晚，允许一切暂时没有答案。”——小眠',
];
