import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AiCreateScreen extends StatefulWidget {
  const AiCreateScreen({super.key});

  @override
  State<AiCreateScreen> createState() => _AiCreateScreenState();
}

class _AiCreateScreenState extends State<AiCreateScreen> {
  String? selectedStyle;
  File? selectedImage;
  bool _restoredArgs = false;
  bool isGenerating = false;

  final TextEditingController promptController = TextEditingController();

  final List<String> styles = const [
    'Minimalist',
    'Modern',
    'Scandi',
    'Classic',
    'Industrial',
    'Boho',
    'Loft',
    'Zen',
  ];

  @override
  void dispose() {
    promptController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_restoredArgs) return;
    _restoredArgs = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final String? imagePath = args?['imagePath'] as String?;
    final String? style = args?['style'] as String?;
    final String? prompt = args?['prompt'] as String?;

    if (imagePath != null &&
        imagePath.isNotEmpty &&
        !imagePath.startsWith('http')) {
      selectedImage = File(imagePath);
    }

    if (style != null && style.isNotEmpty) {
      selectedStyle = style;
    }

    if (prompt != null && prompt.isNotEmpty) {
      promptController.text = prompt;
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
      });
    }
  }

  void _removeImage() {
    setState(() {
      selectedImage = null;
      selectedStyle = null;
      promptController.clear();
    });
  }

  void _appendPrompt(String text) {
    final current = promptController.text.trim();

    setState(() {
      promptController.text = current.isEmpty ? text : '$current, $text';
      promptController.selection = TextSelection.fromPosition(
        TextPosition(offset: promptController.text.length),
      );
    });
  }

  Future<void> _generateDesign() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Войдите в аккаунт, чтобы использовать ИИ'),
        ),
      );
      return;
    }

    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала загрузите фото комнаты')),
      );
      return;
    }

    setState(() {
      isGenerating = true;
    });

    try {
      final uri = Uri.parse('http://10.0.2.2:3000/generate-room');

      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath('image', selectedImage!.path),
      );

      request.fields['prompt'] = promptController.text.trim();
      request.fields['style'] = selectedStyle ?? '';
      request.fields['userId'] = user.uid;

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      Map<String, dynamic> decoded = {};

      if (responseData.isNotEmpty) {
        decoded = jsonDecode(responseData) as Map<String, dynamic>;
      }

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.pushNamed(
          context,
          '/result',
          arguments: {
            'imagePath': decoded['imageUrl'],
            'style': selectedStyle,
            'prompt': promptController.text.trim(),
          },
        );
      } else if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Лимит генераций исчерпан')),
        );
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Войдите в аккаунт')));
      } else {
        final message = decoded['error'] ?? 'Ошибка генерации';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message.toString())));
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка генерации: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color previewAccent = _accentColor(selectedStyle);
    final Color previewOverlay = _overlayColor(selectedStyle);

    final bool canGenerate =
        selectedImage != null &&
        !isGenerating &&
        (selectedStyle != null || promptController.text.trim().isNotEmpty);

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
          "Создать дизайн",
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: const [
              Text(
                "1. Загрузите фото",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              SizedBox(width: 10),
              Chip(
                label: Text(
                  "ОБЯЗАТЕЛЬНО",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                backgroundColor: Color(0xFFE8F1FF),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (selectedImage == null)
            InkWell(
              onTap: isGenerating ? null : _pickImage,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFDBE4F0)),
                ),
                child: Column(
                  children: const [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 42,
                      color: Color(0xFF2E90FA),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Нажмите, чтобы загрузить фото\nкомнаты",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "PNG, JPG или HEIC (до 10MB)",
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFDBE4F0)),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      children: [
                        Image.file(
                          selectedImage!,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                          color: previewOverlay,
                          colorBlendMode: BlendMode.softLight,
                        ),
                        if (selectedStyle != null)
                          Positioned(
                            top: 12,
                            right: 12,
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
                                selectedStyle!,
                                style: TextStyle(
                                  color: previewAccent,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        if (selectedStyle != null)
                          Positioned(
                            left: 12,
                            bottom: 12,
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
                                    Icons.auto_awesome,
                                    size: 16,
                                    color: previewAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _previewLabel(selectedStyle!),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isGenerating ? null : _removeImage,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFDBE4F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFF111827),
                          ),
                          label: const Text(
                            "Удалить",
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isGenerating ? null : _pickImage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E90FA),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text(
                            "Заменить",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            "2. Опишите интерьер",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDBE4F0)),
            ),
            child: TextField(
              controller: promptController,
              enabled: !isGenerating,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    "Например: уютная гостиная в скандинавском стиле с тёплым светом и растениями",
                hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PromptChip(text: "уютно", onTap: () => _appendPrompt("уютно")),
              _PromptChip(text: "светло", onTap: () => _appendPrompt("светло")),
              _PromptChip(
                text: "современно",
                onTap: () => _appendPrompt("современно"),
              ),
              _PromptChip(
                text: "с растениями",
                onTap: () => _appendPrompt("с растениями"),
              ),
              _PromptChip(
                text: "тёплый свет",
                onTap: () => _appendPrompt("тёплый свет"),
              ),
              _PromptChip(
                text: "минимализм",
                onTap: () => _appendPrompt("минимализм"),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            "3. Выберите стиль",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: styles.map((style) {
              final isSelected = selectedStyle == style;

              return _StyleChip(
                text: style,
                isSelected: isSelected,
                onTap: () {
                  if (isGenerating) return;

                  setState(() {
                    selectedStyle = style;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: canGenerate ? _generateDesign : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E90FA),
                disabledBackgroundColor: const Color(0xFFBFD9F8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                isGenerating
                    ? "Генерируем..."
                    : promptController.text.trim().isNotEmpty
                    ? "Создать интерьер"
                    : "Сгенерировать дизайн",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _previewLabel(String style) {
    switch (style) {
      case 'Minimalist':
        return 'Светлый и чистый';
      case 'Modern':
        return 'Современный акцент';
      case 'Scandi':
        return 'Мягкий сканди';
      case 'Classic':
        return 'Тёплая классика';
      case 'Industrial':
        return 'Строже и холоднее';
      case 'Boho':
        return 'Творчески и тепло';
      case 'Loft':
        return 'Глубже и темнее';
      case 'Zen':
        return 'Спокойнее и мягче';
      default:
        return 'Предпросмотр стиля';
    }
  }

  static Color _accentColor(String? style) {
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
      default:
        return const Color(0xFF2E90FA);
    }
  }

  static Color _overlayColor(String? style) {
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
}

class _StyleChip extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _StyleChip({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E90FA) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2E90FA)
                : const Color(0xFFDBE4F0),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF111827),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _PromptChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
