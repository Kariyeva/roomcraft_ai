import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/saved_works_service.dart';
import '01_splash.dart';
import 'profile_screen.dart';

class ModeSelectScreen extends StatefulWidget {
  const ModeSelectScreen({super.key});

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen> {
  Future<void> _refreshWorks() async {
    setState(() {});
  }

  Future<void> _deleteWork(String workId) async {
    await SavedWorksService.deleteWork(workId);
  }

  bool _isRegisteredUser(User? user) {
    if (user == null) return false;
    if (user.isAnonymous) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF6F7FB),
        elevation: 0,
        title: const Text(
          "Выберите режим",
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const SplashScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.login, color: Color(0xFF111827)),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            icon: const Icon(Icons.person, color: Color(0xFF2E90FA)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshWorks,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 6),
            const Text(
              "Как вы хотите оформить комнату?",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Начните с ИИ или создайте вручную",
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),

            _bigCard(
              title: "ИИ дизайн комнаты",
              subtitle:
                  "Загрузите фото, и ИИ создаст\nготовый интерьер за секунды.",
              color: const Color(0xFF2E90FA),
              onTap: () async {
                await Navigator.pushNamed(context, '/ai_create');
                setState(() {});
              },
            ),

            const SizedBox(height: 14),

            _smallCard(
              title: "Ручной режим",
              subtitle: "Расставляйте мебель и декор в\nудобном 2D-редакторе.",
              onTap: () async {
                await Navigator.pushNamed(context, '/editor');
                setState(() {});
              },
            ),

            const SizedBox(height: 22),
            const Text(
              "ПОСЛЕДНИЕ РАБОТЫ",
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),

            StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, authSnapshot) {
                final user = authSnapshot.data;

                if (!_isRegisteredUser(user)) {
                  return Row(
                    children: [
                      Expanded(child: _placeholderBox()),
                      const SizedBox(width: 12),
                      Expanded(child: _placeholderBox()),
                    ],
                  );
                }

                return StreamBuilder<List<SavedWorkWithId>>(
                  stream: SavedWorksService.getWorksStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final savedWorks = snapshot.data ?? [];

                    if (savedWorks.isEmpty) {
                      return Row(
                        children: [
                          Expanded(child: _placeholderBox()),
                          const SizedBox(width: 12),
                          Expanded(child: _placeholderBox()),
                        ],
                      );
                    }

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: savedWorks.map((item) {
                        final work = item.work;

                        return _savedWorkCard(
                          context: context,
                          work: work,
                          onDelete: () => _deleteWork(item.id),
                          onOpen: () {
                            Navigator.pushNamed(
                              context,
                              '/result',
                              arguments: {
                                'style': work.style,
                                'imagePath': work.imagePath,
                                'placedItems': work.placedItems,
                              },
                            );
                          },
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  static Widget _placeholderBox() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Color(0xFFC7CEDB), size: 36),
      ),
    );
  }

  static Widget _savedWorkCard({
    required BuildContext context,
    required SavedWork work,
    required VoidCallback onDelete,
    required VoidCallback onOpen,
  }) {
    final bool isManual = work.style == 'Ручной режим';
    final Color overlayColor = _overlayColor(work.style);
    final Color accentColor = _accentColor(work.style);

    return SizedBox(
      width: (MediaQuery.of(context).size.width - 44) / 2,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 110,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final areaWidth = constraints.maxWidth;
                        final areaHeight = constraints.maxHeight;

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            File(work.imagePath).existsSync()
                                ? Image.file(
                                    File(work.imagePath),
                                    fit: BoxFit.cover,
                                    color: overlayColor,
                                    colorBlendMode: BlendMode.softLight,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: const Color(0xFFE9EEF6),
                                        child: const Center(
                                          child: Icon(
                                            Icons.image,
                                            color: Color(0xFFB8C4D6),
                                            size: 30,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: const Color(0xFFE9EEF6),
                                    child: const Center(
                                      child: Icon(
                                        Icons.image,
                                        color: Color(0xFFB8C4D6),
                                        size: 30,
                                      ),
                                    ),
                                  ),

                            if (!isManual && work.style.isNotEmpty)
                              Positioned(
                                left: 8,
                                top: 8,
                                child: _miniStyleChip(
                                  title: work.style,
                                  accentColor: accentColor,
                                ),
                              ),

                            if (isManual)
                              ...work.placedItems.map((item) {
                                final double rawX =
                                    ((item['x'] as num?)?.toDouble() ?? 0.0);
                                final double rawY =
                                    ((item['y'] as num?)?.toDouble() ?? 0.0);

                                final double x = rawX > 1
                                    ? rawX
                                    : rawX * areaWidth;
                                final double y = rawY > 1
                                    ? rawY
                                    : rawY * areaHeight;

                                return Positioned(
                                  left: x.clamp(2.0, areaWidth - 60),
                                  top: y.clamp(2.0, areaHeight - 24),
                                  child: _miniPlacedChip(
                                    title: item['title'] as String,
                                    iconCodePoint: item['iconCodePoint'] as int,
                                  ),
                                );
                              }),

                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: onDelete,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.95),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        work.mode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // 👇 если есть prompt (ИИ)
                      if (work.prompt.isNotEmpty)
                        Text(
                          work.prompt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        )
                      else
                        Text(
                          work.style,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        ),

                      const SizedBox(height: 4),

                      if (work.description.isNotEmpty)
                        Text(
                          work.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),

                      const SizedBox(height: 4),
                      Text(
                        work.dateLabel,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _miniStyleChip({
    required String title,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDBE4F0)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: accentColor,
        ),
      ),
    );
  }

  static Widget _miniPlacedChip({
    required String title,
    required int iconCodePoint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDBE4F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            IconData(iconCodePoint, fontFamily: 'MaterialIcons'),
            size: 10,
            color: const Color(0xFF111827),
          ),
          const SizedBox(width: 3),
          Text(
            title,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  static Color _accentColor(String style) {
    switch (style) {
      case 'Minimalist':
        return const Color(0xFF8FAFCF);
      case 'Modern':
        return const Color(0xFF2E90FA);
      case 'Scandi':
        return const Color(0xFF49A58A);
      case 'Classic':
        return const Color(0xFFB08968);
      case 'Industrial':
        return const Color(0xFF61656D);
      case 'Boho':
        return const Color(0xFFD28B5C);
      case 'Loft':
        return const Color(0xFF7A5C58);
      case 'Zen':
        return const Color(0xFF6E9E72);
      case 'Ручной режим':
        return const Color(0xFF1F2A37);
      default:
        return const Color(0xFF2E90FA);
    }
  }

  static Color _overlayColor(String style) {
    switch (style) {
      case 'Minimalist':
        return const Color(0x80EAF3FF);
      case 'Modern':
        return const Color(0x662E90FA);
      case 'Scandi':
        return const Color(0x8049A58A);
      case 'Classic':
        return const Color(0x66D9B38C);
      case 'Industrial':
        return const Color(0x996B7280);
      case 'Boho':
        return const Color(0x99D99A63);
      case 'Loft':
        return const Color(0x997A5C58);
      case 'Zen':
        return const Color(0x807FA37A);
      default:
        return Colors.transparent;
    }
  }

  static Widget _bigCard({
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.92)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.chevron_right, color: Color(0xFF2E90FA)),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _smallCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.edit, color: Color(0xFF111827)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.chevron_right, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
