import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import '../models/custom_item.dart';
import '../services/custom_items_service.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  String selectedTab = 'Мебель';

  File? selectedImage;
  Uint8List? selectedImageBytes;
  String? selectedImageName;

  final List<_PlacedItem> placedItems = [];
  final List<CustomItem> customItems = [];

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
    'Текстиль': const [
      _EditorItem('КОВЕР', Icons.texture),
      _EditorItem('ШТОРЫ', Icons.curtains),
      _EditorItem('ПОДУШКА', Icons.bed),
    ],
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_restoredArgs) return;
    _restoredArgs = true;

    _loadCustomItems();

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final String? imagePath = args?['imagePath'] as String?;
    final List<Map<String, dynamic>> restoredPlacedItems =
        (args?['placedItems'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    if (!kIsWeb && imagePath != null && imagePath.isNotEmpty) {
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
            iconCodePoint: (item['iconCodePoint'] as num?)?.toInt(),
            imagePath: item['imagePath'] as String?,
            imageBase64: item['imageBase64'] as String?,
            isCustom: item['isCustom'] == true,
            x: rawX > 1 ? (rawX / 350).clamp(0.0, 0.85) : rawX.clamp(0.0, 0.85),
            y: rawY > 1 ? (rawY / 420).clamp(0.0, 0.90) : rawY.clamp(0.0, 0.90),
            scale: ((item['scale'] as num?)?.toDouble() ?? 1.0).clamp(0.3, 4.0),
            rotation: ((item['rotation'] as num?)?.toDouble() ?? 0.0),
          );
        }),
      );
    }
  }

  Future<void> _loadCustomItems() async {
    final items = await CustomItemsService.getItems();

    if (!mounted) return;

    setState(() {
      customItems
        ..clear()
        ..addAll(items);
    });
  }

  String get _backendBaseUrl {
    if (kIsWeb) return 'http://localhost:3000';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000';
      default:
        return 'http://localhost:3000';
    }
  }

  Future<String?> _removeBackgroundWithReplicate(Uint8List imageBytes) async {
    try {
      final uri = Uri.parse('$_backendBaseUrl/remove-background');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'custom_item.png',
        ),
      );

      final response = await request.send().timeout(
        const Duration(seconds: 90),
      );
      final body = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        _showSnack('Не удалось удалить фон');
        debugPrint('Remove background error: $body');
        return null;
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final imageBase64 = decoded['imageBase64'] as String?;

      if (imageBase64 == null || imageBase64.isEmpty) {
        _showSnack('Фон не удалён: пустой ответ сервера');
        return null;
      }

      return imageBase64;
    } catch (e) {
      debugPrint('Remove background exception: $e');
      _showSnack('Ошибка удаления фона');
      return null;
    }
  }

  Future<void> _pickCustomItemImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null) return;

    final file = result.files.single;

    if (file.bytes == null) {
      _showSnack('Не удалось загрузить изображение');
      return;
    }

    final nameController = TextEditingController(
      text: file.name.split('.').first,
    );

    String category = selectedTab;

    if (!itemsByTab.keys.contains(category)) {
      category = 'Мебель';
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                'Добавить предмет',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Название предмета',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(
                      labelText: 'Категория',
                      border: OutlineInputBorder(),
                    ),
                    items: itemsByTab.keys
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        category = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'После сохранения фон будет автоматически удалён через ИИ.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E90FA),
                  ),
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      nameController.dispose();
      return;
    }

    final name = nameController.text.trim().isEmpty
        ? 'Мой предмет'
        : nameController.text.trim();

    nameController.dispose();

    _showSnack('Удаляем фон...');

    final String? removedBackgroundBase64 =
        await _removeBackgroundWithReplicate(file.bytes!);

    if (!mounted) return;

    final item = CustomItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      category: category,
      imagePath: null,
      imageBase64: removedBackgroundBase64 ?? base64Encode(file.bytes!),
      createdAt: DateTime.now(),
    );

    await CustomItemsService.saveItem(item);
    await _loadCustomItems();

    if (!mounted) return;

    setState(() {
      selectedTab = category;
    });

    _showSnack(
      removedBackgroundBase64 != null
          ? 'Предмет успешно добавлен'
          : 'Предмет добавлен (без обработки фона)',
    );
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null) return;

    final file = result.files.single;

    setState(() {
      if (!kIsWeb && file.path != null) {
        selectedImage = File(file.path!);
      }

      selectedImageBytes = file.bytes;
      selectedImageName = file.name;

      placedItems.clear();
    });
  }

  void _removeImage() {
    setState(() {
      selectedImage = null;
      selectedImageBytes = null;
      selectedImageName = null;
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
          isCustom: false,
          x: (0.06 + (index % 3) * 0.30).clamp(0.0, 0.85),
          y: (0.06 + (index ~/ 3) * 0.18).clamp(0.0, 0.90),
        ),
      );
    });
  }

  void _addCustomItem(CustomItem item) {
    final int index = placedItems.length;

    setState(() {
      placedItems.add(
        _PlacedItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: item.name,
          iconCodePoint: null,
          imagePath: item.imagePath,
          imageBase64: item.imageBase64,
          isCustom: true,
          x: (0.08 + (index % 3) * 0.22).clamp(0.0, 0.85),
          y: (0.08 + (index ~/ 3) * 0.16).clamp(0.0, 0.90),
        ),
      );
    });
  }

  Future<void> _deleteCustomItem(CustomItem item) async {
    await CustomItemsService.deleteItem(item.id);
    await _loadCustomItems();

    if (!mounted) return;

    _showSnack('Предмет удален из каталога');
  }

  void _resizePlacedItem(String id, double delta) {
    setState(() {
      final index = placedItems.indexWhere((item) => item.id == id);
      if (index == -1) return;

      final current = placedItems[index];

      placedItems[index] = current.copyWith(
        scale: (current.scale + delta).clamp(0.3, 4.0),
      );
    });
  }

  void _setPlacedItemScale(String id, double scale) {
    setState(() {
      final index = placedItems.indexWhere((item) => item.id == id);
      if (index == -1) return;

      placedItems[index] = placedItems[index].copyWith(
        scale: scale.clamp(0.3, 4.0),
      );
    });
  }

  void _rotatePlacedItem(String id) {
    setState(() {
      final index = placedItems.indexWhere((item) => item.id == id);
      if (index == -1) return;

      final current = placedItems[index];

      placedItems[index] = current.copyWith(rotation: current.rotation + 0.15);
    });
  }

  void _setPlacedItemRotation(String id, double rotation) {
    setState(() {
      final index = placedItems.indexWhere((item) => item.id == id);
      if (index == -1) return;

      placedItems[index] = placedItems[index].copyWith(rotation: rotation);
    });
  }

  void _selectPlacedItem(String id) {
    setState(() {
      for (int i = 0; i < placedItems.length; i++) {
        placedItems[i] = placedItems[i].copyWith(
          selected: placedItems[i].id == id,
        );
      }
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
            'imagePath': item.imagePath,
            'imageBase64': item.imageBase64,
            'isCustom': item.isCustom,
            'x': item.x,
            'y': item.y,
            'scale': item.scale,
            'rotation': item.rotation,
          },
        )
        .toList();
  }

  _PlacedItem? get _selectedPlacedItem {
    try {
      return placedItems.firstWhere((item) => item.selected);
    } catch (_) {
      return null;
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final currentItems = itemsByTab[selectedTab] ?? [];
    final currentCustomItems = customItems
        .where((item) => item.category == selectedTab)
        .toList();

    final bool canSave =
        (selectedImage != null || selectedImageBytes != null) &&
        placedItems.isNotEmpty;

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
              child: selectedImage == null && selectedImageBytes == null
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
                                child: kIsWeb
                                    ? Image.memory(
                                        selectedImageBytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
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
                                    onTap: () => _selectPlacedItem(item.id),
                                    onPanUpdate: (details) {
                                      _movePlacedItem(
                                        item.id,
                                        details.delta,
                                        areaSize,
                                      );
                                    },
                                    child: _draggablePlacedObject(
                                      item: item,
                                      onDelete: () =>
                                          _removePlacedItem(item.id),
                                      onIncrease: () =>
                                          _resizePlacedItem(item.id, 0.1),
                                      onDecrease: () =>
                                          _resizePlacedItem(item.id, -0.1),
                                      onRotate: () =>
                                          _rotatePlacedItem(item.id),
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
                if (_selectedPlacedItem != null) ...[
                  _objectAdjustPanel(_selectedPlacedItem!),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    _tab(
                      "Мебель",
                      selected: selectedTab == 'Мебель',
                      onTap: () => setState(() => selectedTab = 'Мебель'),
                    ),
                    const SizedBox(width: 8),
                    _tab(
                      "Декор",
                      selected: selectedTab == 'Декор',
                      onTap: () => setState(() => selectedTab = 'Декор'),
                    ),
                    const SizedBox(width: 8),
                    _tab(
                      "Свет",
                      selected: selectedTab == 'Свет',
                      onTap: () => setState(() => selectedTab = 'Свет'),
                    ),
                    const SizedBox(width: 8),
                    _tab(
                      "Текстиль",
                      selected: selectedTab == 'Текстиль',
                      onTap: () => setState(() => selectedTab = 'Текстиль'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _pickCustomItemImage,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF2E90FA)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Color(0xFF2E90FA),
                    ),
                    label: Text(
                      "Добавить предмет в раздел «$selectedTab»",
                      style: const TextStyle(
                        color: Color(0xFF2E90FA),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 104,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...currentItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _catalogIconItem(
                            title: item.title,
                            icon: item.icon,
                            onTap: () => _addItem(item),
                          ),
                        ),
                      ),
                      ...currentCustomItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _catalogCustomItem(
                            item: item,
                            onTap: () => _addCustomItem(item),
                            onDelete: () => _deleteCustomItem(item),
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
                    onPressed: canSave
                        ? () {
                            Navigator.of(context).pushNamed(
                              '/result',
                              arguments: {
                                'style': 'Ручной режим',
                                'imagePath': selectedImage?.path,
                                'imageBytes': selectedImageBytes,
                                'imageName': selectedImageName,
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

  Widget _objectAdjustPanel(_PlacedItem item) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDBE4F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Настройка предмета',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  setState(() {
                    for (int i = 0; i < placedItems.length; i++) {
                      placedItems[i] = placedItems[i].copyWith(selected: false);
                    }
                  });
                },
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.open_in_full, size: 16),
              const SizedBox(width: 6),
              const Text('Размер'),
              Expanded(
                child: Slider(
                  value: item.scale.clamp(0.3, 4.0),
                  min: 0.3,
                  max: 4.0,
                  onChanged: (value) => _setPlacedItemScale(item.id, value),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.rotate_right, size: 16),
              const SizedBox(width: 6),
              const Text('Поворот'),
              Expanded(
                child: Slider(
                  value: item.rotation.clamp(-3.14, 3.14),
                  min: -3.14,
                  max: 3.14,
                  onChanged: (value) => _setPlacedItemRotation(item.id, value),
                ),
              ),
            ],
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

  static Widget _draggablePlacedObject({
    required _PlacedItem item,
    required VoidCallback onDelete,
    required VoidCallback onIncrease,
    required VoidCallback onDecrease,
    required VoidCallback onRotate,
  }) {
    final Widget content;

    if (item.isCustom &&
        item.imageBase64 != null &&
        item.imageBase64!.isNotEmpty) {
      content = Image.memory(
        base64Decode(item.imageBase64!),
        width: 120,
        fit: BoxFit.contain,
      );
    } else if (item.isCustom &&
        item.imagePath != null &&
        item.imagePath!.isNotEmpty &&
        !kIsWeb) {
      content = Image.file(
        File(item.imagePath!),
        width: 120,
        fit: BoxFit.contain,
      );
    } else {
      content = Container(
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
                IconData(
                  item.iconCodePoint ?? Icons.category.codePoint,
                  fontFamily: 'MaterialIcons',
                ),
                size: 18,
                color: const Color(0xFF111827),
              ),
              const SizedBox(width: 8),
              Text(
                item.title,
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

    return Transform.rotate(
      angle: item.rotation,
      child: Transform.scale(
        scale: item.scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                content,
                Positioned(
                  top: -10,
                  right: -10,
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (item.selected)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _miniControlButton(icon: Icons.remove, onTap: onDecrease),
                    _miniControlButton(icon: Icons.add, onTap: onIncrease),
                    _miniControlButton(
                      icon: Icons.rotate_right,
                      onTap: onRotate,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _miniControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: const BoxDecoration(
          color: Color(0xFFF3F4F6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 17, color: Color(0xFF111827)),
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
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _catalogIconItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEEF2F7)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF111827)),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _catalogCustomItem({
    required CustomItem item,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    Widget image;

    if (item.imageBase64 != null && item.imageBase64!.isNotEmpty) {
      image = Image.memory(
        base64Decode(item.imageBase64!),
        height: 48,
        fit: BoxFit.contain,
      );
    } else if (item.imagePath != null &&
        item.imagePath!.isNotEmpty &&
        !kIsWeb) {
      image = Image.file(
        File(item.imagePath!),
        height: 48,
        fit: BoxFit.contain,
      );
    } else {
      image = const Icon(Icons.image_not_supported_outlined);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 104,
            height: 96,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F7FB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDBE4F0)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: Center(child: image)),
                const SizedBox(height: 4),
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ),
      ],
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
  final int? iconCodePoint;
  final String? imagePath;
  final String? imageBase64;
  final bool isCustom;
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final bool selected;

  const _PlacedItem({
    required this.id,
    required this.title,
    this.iconCodePoint,
    this.imagePath,
    this.imageBase64,
    this.isCustom = false,
    required this.x,
    required this.y,

    this.scale = 1.0,
    this.rotation = 0.0,
    this.selected = false,
  });

  _PlacedItem copyWith({
    String? id,
    String? title,
    int? iconCodePoint,
    String? imagePath,
    String? imageBase64,
    bool? isCustom,
    double? x,
    double? y,

    double? scale,
    double? rotation,
    bool? selected,
  }) {
    return _PlacedItem(
      id: id ?? this.id,
      title: title ?? this.title,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      imagePath: imagePath ?? this.imagePath,
      imageBase64: imageBase64 ?? this.imageBase64,
      isCustom: isCustom ?? this.isCustom,
      x: x ?? this.x,
      y: y ?? this.y,

      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      selected: selected ?? this.selected,
    );
  }
}
