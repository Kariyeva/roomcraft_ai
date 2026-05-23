import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  String selectedTab = 'Мебель';
  File? selectedImage;
  final List<_PlacedItem> placedItems = [];
  bool _restoredArgs = false;

  final Map<String, List<_EditorItem>> itemsByTab = {
    'Мебель': const [
      _EditorItem('ДИВАН', Icons.weekend),
      _EditorItem('СТОЛ', Icons.table_restaurant),
      _EditorItem('КРЕСЛО', Icons.chair_alt),
    ],
    'Декор': const [
      _EditorItem('РАСТЕНИЕ', Icons.local_florist),
      _EditorItem('КАРТИНА', Icons.image_outlined),
      _EditorItem('ВАЗА', Icons.emoji_nature),
    ],
    'Свет': const [
      _EditorItem('ЛАМПА', Icons.lightbulb_outline),
      _EditorItem('ЛЮСТРА', Icons.highlight),
      _EditorItem('БРА', Icons.wb_incandescent_outlined),
    ],
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_restoredArgs) return;
    _restoredArgs = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final String? imagePath = args?['imagePath'] as String?;
    final List<Map<String, dynamic>> restoredPlacedItems =
        (args?['placedItems'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    if (imagePath != null && imagePath.isNotEmpty) {
      selectedImage = File(imagePath);
    }

    if (restoredPlacedItems.isNotEmpty) {
      placedItems.clear();
      placedItems.addAll(
        restoredPlacedItems.map((item) {
          final double rawX = ((item['x'] as num?)?.toDouble() ?? 0.08);
          final double rawY = ((item['y'] as num?)?.toDouble() ?? 0.08);

          return _PlacedItem(
            id: (item['id'] ?? DateTime.now().microsecondsSinceEpoch)
                .toString(),
            title: (item['title'] ?? '').toString(),
            iconCodePoint: (item['iconCodePoint'] as num).toInt(),
            x: rawX > 1 ? (rawX / 350).clamp(0.0, 0.85) : rawX.clamp(0.0, 0.85),
            y: rawY > 1 ? (rawY / 420).clamp(0.0, 0.90) : rawY.clamp(0.0, 0.90),
          );
        }),
      );
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'heic'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        selectedImage = File(result.files.single.path!);
        placedItems.clear();
      });
    }
  }

  void _removeImage() {
    setState(() {
      selectedImage = null;
      placedItems.clear();
    });
  }

  void _undoLastItem() {
    if (placedItems.isNotEmpty) {
      setState(() {
        placedItems.removeLast();
      });
    }
  }

  void _addItem(_EditorItem item) {
    final int index = placedItems.length;

    setState(() {
      placedItems.add(
        _PlacedItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: item.title,
          iconCodePoint: item.icon.codePoint,
          x: (0.06 + (index % 3) * 0.30).clamp(0.0, 0.85),
          y: (0.06 + (index ~/ 3) * 0.18).clamp(0.0, 0.90),
        ),
      );
    });
  }

  void _removePlacedItem(String id) {
    setState(() {
      placedItems.removeWhere((item) => item.id == id);
    });
  }

  void _movePlacedItem(String id, Offset delta, Size areaSize) {
    setState(() {
      final index = placedItems.indexWhere((item) => item.id == id);
      if (index == -1) return;

      final current = placedItems[index];

      placedItems[index] = current.copyWith(
        x: (current.x + delta.dx / areaSize.width).clamp(0.0, 0.85),
        y: (current.y + delta.dy / areaSize.height).clamp(0.0, 0.90),
      );
    });
  }

  List<Map<String, dynamic>> _buildPlacedItemsArgs() {
    return placedItems
        .map(
          (item) => {
            'id': item.id,
            'title': item.title,
            'iconCodePoint': item.iconCodePoint,
            'x': item.x,
            'y': item.y,
          },
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentItems = itemsByTab[selectedTab] ?? [];
    final bool canSave = selectedImage != null && placedItems.isNotEmpty;

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
          "Редактор комнаты",
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _undoLastItem,
            icon: const Icon(Icons.undo, color: Color(0xFF111827)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
              ),
              child: selectedImage == null
                  ? InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(26),
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 42,
                                color: Color(0xFF2E90FA),
                              ),
                              SizedBox(height: 14),
                              Text(
                                "Нажмите, чтобы загрузить фото\nкомнаты для ручного редактирования",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "PNG, JPG или HEIC",
                                style: TextStyle(color: Color(0xFF9CA3AF)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final areaSize = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );

                          return Stack(
                            children: [
                              Positioned.fill(
                                child: Image.file(
                                  selectedImage!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Row(
                                  children: [
                                    _topActionButton(
                                      icon: Icons.delete_outline,
                                      onTap: _removeImage,
                                    ),
                                    const SizedBox(width: 8),
                                    _topActionButton(
                                      icon: Icons.edit_outlined,
                                      onTap: _pickImage,
                                    ),
                                  ],
                                ),
                              ),
                              ...placedItems.map(
                                (item) => Positioned(
                                  left: item.x * areaSize.width,
                                  top: item.y * areaSize.height,
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      _movePlacedItem(
                                        item.id,
                                        details.delta,
                                        areaSize,
                                      );
                                    },
                                    child: _draggablePlacedChip(
                                      item: item,
                                      onDelete: () =>
                                          _removePlacedItem(item.id),
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
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _tab(
                      "Мебель",
                      selected: selectedTab == 'Мебель',
                      onTap: () => setState(() => selectedTab = 'Мебель'),
                    ),
                    const SizedBox(width: 10),
                    _tab(
                      "Декор",
                      selected: selectedTab == 'Декор',
                      onTap: () => setState(() => selectedTab = 'Декор'),
                    ),
                    const SizedBox(width: 10),
                    _tab(
                      "Свет",
                      selected: selectedTab == 'Свет',
                      onTap: () => setState(() => selectedTab = 'Свет'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(currentItems.length, (index) {
                    final item = currentItems[index];
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index == currentItems.length - 1 ? 0 : 12,
                        ),
                        child: _item(
                          item.title,
                          item.icon,
                          onTap: () => _addItem(item),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: canSave
                        ? () {
                            Navigator.of(context).pushNamed(
                              '/result',
                              arguments: {
                                'style': 'Ручной режим',
                                'imagePath': selectedImage!.path,
                                'placedItems': _buildPlacedItemsArgs(),
                              },
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
                    icon: const Icon(Icons.save),
                    label: const Text(
                      "Сохранить комнату",
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _topActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.92),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: const Color(0xFF111827)),
        ),
      ),
    );
  }

  static Widget _draggablePlacedChip({
    required _PlacedItem item,
    required VoidCallback onDelete,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Icon(
              IconData(item.iconCodePoint, fontFamily: 'MaterialIcons'),
              size: 18,
              color: const Color(0xFF111827),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              item.title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _tab(
    String text, {
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _item(
    String title,
    IconData icon, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 86,
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF111827)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorItem {
  final String title;
  final IconData icon;

  const _EditorItem(this.title, this.icon);
}

class _PlacedItem {
  final String id;
  final String title;
  final int iconCodePoint;
  final double x;
  final double y;

  const _PlacedItem({
    required this.id,
    required this.title,
    required this.iconCodePoint,
    required this.x,
    required this.y,
  });

  _PlacedItem copyWith({
    String? id,
    String? title,
    int? iconCodePoint,
    double? x,
    double? y,
  }) {
    return _PlacedItem(
      id: id ?? this.id,
      title: title ?? this.title,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }
}
