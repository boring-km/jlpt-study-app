import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

const List<(String, String)> _hiraganaData = [
  // あ행
  ('あ', 'a'), ('い', 'i'), ('う', 'u'), ('え', 'e'), ('お', 'o'),
  // か행
  ('か', 'ka'), ('き', 'ki'), ('く', 'ku'), ('け', 'ke'), ('こ', 'ko'),
  // さ행
  ('さ', 'sa'), ('し', 'shi'), ('す', 'su'), ('せ', 'se'), ('そ', 'so'),
  // た행
  ('た', 'ta'), ('ち', 'chi'), ('つ', 'tsu'), ('て', 'te'), ('と', 'to'),
  // な행
  ('な', 'na'), ('に', 'ni'), ('ぬ', 'nu'), ('ね', 'ne'), ('の', 'no'),
  // は행
  ('は', 'ha'), ('ひ', 'hi'), ('ふ', 'fu'), ('へ', 'he'), ('ほ', 'ho'),
  // ま행
  ('ま', 'ma'), ('み', 'mi'), ('む', 'mu'), ('め', 'me'), ('も', 'mo'),
  // や행 (빈칸 포함)
  ('や', 'ya'), ('', ''), ('ゆ', 'yu'), ('', ''), ('よ', 'yo'),
  // ら행
  ('ら', 'ra'), ('り', 'ri'), ('る', 'ru'), ('れ', 're'), ('ろ', 'ro'),
  // わ행 (빈칸 포함)
  ('わ', 'wa'), ('', ''), ('', ''), ('', ''), ('を', 'wo'),
  // ん
  ('ん', 'n'), ('', ''), ('', ''), ('', ''), ('', ''),
];

const List<(String, String)> _katakanaData = [
  // ア행
  ('ア', 'a'), ('イ', 'i'), ('ウ', 'u'), ('エ', 'e'), ('オ', 'o'),
  // カ행
  ('カ', 'ka'), ('キ', 'ki'), ('ク', 'ku'), ('ケ', 'ke'), ('コ', 'ko'),
  // サ행
  ('サ', 'sa'), ('シ', 'shi'), ('ス', 'su'), ('セ', 'se'), ('ソ', 'so'),
  // タ행
  ('タ', 'ta'), ('チ', 'chi'), ('ツ', 'tsu'), ('テ', 'te'), ('ト', 'to'),
  // ナ행
  ('ナ', 'na'), ('ニ', 'ni'), ('ヌ', 'nu'), ('ネ', 'ne'), ('ノ', 'no'),
  // ハ행
  ('ハ', 'ha'), ('ヒ', 'hi'), ('フ', 'fu'), ('ヘ', 'he'), ('ホ', 'ho'),
  // マ행
  ('マ', 'ma'), ('ミ', 'mi'), ('ム', 'mu'), ('メ', 'me'), ('モ', 'mo'),
  // ヤ행
  ('ヤ', 'ya'), ('', ''), ('ユ', 'yu'), ('', ''), ('ヨ', 'yo'),
  // ラ행
  ('ラ', 'ra'), ('リ', 'ri'), ('ル', 'ru'), ('レ', 're'), ('ロ', 'ro'),
  // ワ행
  ('ワ', 'wa'), ('', ''), ('', ''), ('', ''), ('ヲ', 'wo'),
  // ン
  ('ン', 'n'), ('', ''), ('', ''), ('', ''), ('', ''),
];

class KanaScreen extends StatefulWidget {
  const KanaScreen({super.key});

  @override
  State<KanaScreen> createState() => _KanaScreenState();
}

class _KanaScreenState extends State<KanaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 탭 글자도 일본어라 본문과 같은 자형을 쓴다.
    final tabStyle = AppText.jaTitle(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('가나 표'),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: tabStyle,
          unselectedLabelStyle: tabStyle,
          tabs: const [
            Tab(text: 'ひらがな'),
            Tab(text: 'カタカナ'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabController,
          children: [
            _KanaGrid(data: _hiraganaData),
            _KanaGrid(data: _katakanaData),
          ],
        ),
      ),
    );
  }
}

class _KanaGrid extends StatelessWidget {
  final List<(String, String)> data;

  const _KanaGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 셀 높이를 정사각형으로 고정하면 큰 글자 설정에서 글자가 넘친다.
    final cellExtent = MediaQuery.textScalerOf(context).scale(72);

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisExtent: cellExtent,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final (kana, roman) = data[index];
        if (kana.isEmpty) {
          return const SizedBox.shrink();
        }
        return Material(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(kana, style: AppText.jaKana(context)),
              Text(roman, style: theme.textTheme.labelSmall),
            ],
          ),
        );
      },
    );
  }
}
