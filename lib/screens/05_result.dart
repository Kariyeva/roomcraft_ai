import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/saved_works_service.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  Widget _buildResultImage({
    required bool hasImage,
    required String? imagePath,
  }) {
    if (!hasImage || imagePath == null) {
      return Container(
        color: const Color(0xFFE9EEF6),
        child: const Center(
          child: Icon(Icons.image, size: 64, color: Color(0xFFB8C4D6)),
        ),
      );
    }

    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;

          return Container(
            color: const Color(0xFFE9EEF6),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E90FA)),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFFE9EEF6),
            child: const Center(
              child: Icon(
                Icons.broken_image,
                size: 64,
                color: Color(0xFFB8C4D6),
              ),
            ),
          );
        },
      );
    }

    if (!kIsWeb) {
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFFE9EEF6),
            child: const Center(
              child: Icon(Icons.image, size: 64, color: Color(0xFFB8C4D6)),
            ),
          );
        },
      );
    }

    return Container(
      color: const Color(0xFFE9EEF6),
      child: const Center(
        child: Icon(Icons.image, size: 64, color: Color(0xFFB8C4D6)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final String? rawStyle = args?['style'] as String?;
    final String selectedStyle =
        (rawStyle != null && rawStyle.trim().isNotEmpty)
        ? rawStyle.trim()
        : 'Не выбран';

    final String prompt = ((args?['prompt'] as String?) ?? '').trim();

    final String? imagePath = args?['imagePath'] as String?;
    final bool hasImage = imagePath != null && imagePath.isNotEmpty;

    final List<Map<String, dynamic>> placedItems =
        (args?['placedItems'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    final bool isManual = selectedStyle == 'Ручной режим';
    final String mode = isManual ? 'Ручной режим' : 'ИИ дизайн комнаты';

    final Color accentColor = _accentColor(selectedStyle);
    final String description = _descriptionText(selectedStyle, prompt);

    final now = DateTime.now();
    final day = now.day.toString();
    const months = [
      'Янв',
      'Фев',
      'Мар',
      'Апр',
      'Май',
      'Июн',
      'Июл',
      'Авг',
      'Сен',
      'Окт',
      'Ноя',
      'Дек',
    ];
    final month = months[now.month - 1];
    final dateLabel = '$day $month';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Результат",
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 340,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final areaWidth = constraints.maxWidth;
                  final areaHeight = constraints.maxHeight;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildResultImage(
                        hasImage: hasImage,
                        imagePath: imagePath,
                      ),
                      if (isManual)
                        ...placedItems.map((item) {
                          final double rawX =
                              ((item['x'] as num?)?.toDouble() ?? 0.0);
                          final double rawY =
                              ((item['y'] as num?)?.toDouble() ?? 0.0);

                          final double x = rawX > 1 ? rawX : rawX * areaWidth;
                          final double y = rawY > 1 ? rawY : rawY * areaHeight;

                          return Positioned(
                            left: x.clamp(0.0, areaWidth - 90),
                            top: y.clamp(0.0, areaHeight - 42),
                            child: _resultPlacedChip(
                              title: item['title'] as String,
                              iconCodePoint: item['iconCodePoint'] as int,
                            ),
                          );
                        }),

                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isManual
                                    ? Icons.edit_outlined
                                    : Icons.auto_awesome,
                                size: 18,
                                color: accentColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                mode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (!isManual &&
                          selectedStyle != 'Не выбран' &&
                          selectedStyle.isNotEmpty)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              selectedStyle,
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.w800,
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

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Ваш новый\nинтерьер",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isManual
                            ? "Собрано в режиме\nРучной режим"
                            : selectedStyle != 'Не выбран'
                            ? "Сгенерировано в стиле\n$selectedStyle"
                            : "Сгенерировано по вашему\nAI-запросу",
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                      if (prompt.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFDBE4F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "AI-запрос",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                prompt,
                                style: const TextStyle(
                                  color: Color(0xFF111827),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    "$day\n$month",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/mode',
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F2A37),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.home),
              label: const Text(
                "На главную",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () {
                if (isManual) {
                  Navigator.pushReplacementNamed(
                    context,
                    '/editor',
                    arguments: {
                      'imagePath': imagePath,
                      'placedItems': placedItems,
                    },
                  );
                } else {
                  Navigator.pushReplacementNamed(
                    context,
                    '/ai_create',
                    arguments: {
                      'imagePath': imagePath,
                      'style': selectedStyle != 'Не выбран'
                          ? selectedStyle
                          : null,
                      'prompt': prompt,
                    },
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDBE4F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.refresh, color: Color(0xFF111827)),
              label: const Text(
                "Переделать",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: hasImage
                  ? () async {
                      await SavedWorksService.saveWork(
                        SavedWork(
                          imagePath: imagePath,
                          style: selectedStyle,
                          mode: mode,
                          dateLabel: dateLabel,
                          prompt: prompt,
                          description: description,
                          placedItems: placedItems,
                        ),
                      );

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Работа сохранена в последние работы'),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E90FA),
                disabledBackgroundColor: const Color(0xFFBFD9F8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                "Сохранить в галерею",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDBE4F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.download, color: Color(0xFF111827)),
                  label: const Text(
                    "Скачать",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDBE4F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.share, color: Color(0xFF111827)),
                  label: const Text(
                    "Поделиться",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _resultPlacedChip({
    required String title,
    required int iconCodePoint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDBE4F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              IconData(iconCodePoint, fontFamily: 'MaterialIcons'),
              size: 18,
              color: const Color(0xFF111827),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
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

  static String _descriptionText(String style, String prompt) {
    if (prompt.isNotEmpty && style == 'Не выбран') {
      return 'Результат собран на основе вашего текстового запроса.';
    }

    switch (style) {
      case 'Minimalist':
        return 'Больше света, чистые линии и спокойная палитра.';
      case 'Modern':
        return 'Современные акценты, чистая композиция и контраст.';
      case 'Scandi':
        return 'Мягкий свет, уют и лёгкая северная эстетика.';
      case 'Classic':
        return 'Более тёплая подача, элегантность и спокойный баланс.';
      case 'Industrial':
        return 'Чуть более холодная, графичная и строгая атмосфера.';
      case 'Boho':
        return 'Тёплый творческий характер и более живое настроение.';
      case 'Loft':
        return 'Городская атмосфера, глубина и немного драматичности.';
      case 'Zen':
        return 'Спокойствие, мягкость и расслабленная гармония.';
      case 'Ручной режим':
        return 'Комната собрана вручную из выбранных вами элементов.';
      default:
        return prompt.isNotEmpty
            ? 'Результат собран на основе вашего текстового запроса.'
            : 'Результат готов для просмотра и сохранения.';
    }
  }
}
