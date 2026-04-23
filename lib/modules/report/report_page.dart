import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/im_constants.dart';
import '../../data/models/report.dart';
import '../../service/api/file_api.dart';
import '../../service/api/report_api.dart';

class ReportPage extends StatefulWidget {
  final String channelId;
  final int channelType;
  final String? targetName;
  final String title;

  const ReportPage({
    super.key,
    required this.channelId,
    required this.channelType,
    required this.title,
    this.targetName,
  });

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _remarkController = TextEditingController();

  List<ReportCategory> _categories = const <ReportCategory>[];
  List<XFile> _evidenceImages = const <XFile>[];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  ReportCategory? _selectedRootCategory;
  ReportCategory? _selectedLeafCategory;

  String get _targetTypeLabel {
    switch (widget.channelType) {
      case ChannelType.group:
        return '群聊';
      case ChannelType.personal:
        return '用户';
      default:
        return '频道';
    }
  }

  String get _targetDisplayName {
    final name = widget.targetName?.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    return widget.channelId;
  }

  bool get _canPickMoreImages => !_isSubmitting && _evidenceImages.length < 9;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final categories = await ReportApi.instance.getCategories(
        languageCode: _resolveLanguageCode(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  String _resolveLanguageCode() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final languageCode = locale.languageCode.trim();
    final countryCode = locale.countryCode?.trim() ?? '';
    if (languageCode.isEmpty) {
      return 'zh-CN';
    }
    if (countryCode.isEmpty) {
      return languageCode;
    }
    return '$languageCode-$countryCode';
  }

  void _selectCategory(ReportCategory category) {
    if (category.hasChildren) {
      setState(() {
        _selectedRootCategory = category;
        _selectedLeafCategory = null;
      });
      return;
    }

    setState(() {
      _selectedRootCategory ??= category.parentCategoryNo.isEmpty
          ? category
          : null;
      _selectedLeafCategory = category;
    });
  }

  void _resetCategorySelection() {
    setState(() {
      _selectedRootCategory = null;
      _selectedLeafCategory = null;
    });
  }

  Future<void> _pickEvidenceImages() async {
    if (!_canPickMoreImages) {
      return;
    }

    try {
      final images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (images.isEmpty || !mounted) {
        return;
      }

      final remainingSlots = 9 - _evidenceImages.length;
      final appendedImages = images.take(remainingSlots).toList();
      setState(() {
        _evidenceImages = <XFile>[..._evidenceImages, ...appendedImages];
      });

      if (images.length > remainingSlots) {
        _showMessage('最多只能上传 9 张证据图片，已自动截断');
      }
    } catch (e) {
      _showMessage('选择证据图片失败: $e');
    }
  }

  void _removeEvidenceImage(int index) {
    if (index < 0 || index >= _evidenceImages.length || _isSubmitting) {
      return;
    }

    setState(() {
      _evidenceImages = <XFile>[
        for (var i = 0; i < _evidenceImages.length; i++)
          if (i != index) _evidenceImages[i],
      ];
    });
  }

  Future<void> _submitReport() async {
    final selectedCategory = _selectedLeafCategory;
    if (selectedCategory == null) {
      _showMessage('请先选择举报原因');
      return;
    }
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final imageUrls = <String>[];
      for (var i = 0; i < _evidenceImages.length; i++) {
        final uploadedUrl = await FileApi.instance.uploadReportImage(
          _evidenceImages[i].path,
        );
        if (uploadedUrl.trim().isEmpty) {
          throw Exception('第 ${i + 1} 张证据图片上传失败');
        }
        imageUrls.add(uploadedUrl);
      }

      await ReportApi.instance.submitReport(
        channelId: widget.channelId,
        channelType: widget.channelType,
        categoryNo: selectedCategory.categoryNo,
        remark: _remarkController.text.trim(),
        imgs: imageUrls,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        _showMessage('提交举报失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _buildBody(),
      bottomNavigationBar: _selectedLeafCategory == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                child: Text(_isSubmitting ? '提交中...' : '提交举报'),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('加载举报分类失败', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadCategories,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildTargetCard(),
            const SizedBox(height: 16),
            if (_selectedLeafCategory == null)
              _buildCategorySelector()
            else
              _buildReportForm(),
          ],
        ),
        if (_isSubmitting)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Widget _buildTargetCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('举报对象', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('类型：$_targetTypeLabel'),
            const SizedBox(height: 4),
            Text('名称：$_targetDisplayName'),
            const SizedBox(height: 4),
            Text(
              'ID：${widget.channelId}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    final rootCategory = _selectedRootCategory;
    final visibleCategories = rootCategory?.children.isNotEmpty == true
        ? rootCategory!.children
        : _categories;
    final title = rootCategory == null ? '请选择举报原因' : '请选择具体原因';

    if (visibleCategories.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '服务端当前没有返回可用的举报分类，暂时无法提交举报。',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _loadCategories, child: const Text('重新加载')),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (rootCategory != null)
              ListTile(
                leading: const Icon(Icons.arrow_back),
                title: const Text('重新选择大类'),
                subtitle: Text(rootCategory.categoryName),
                onTap: _resetCategorySelection,
              ),
            for (final category in visibleCategories)
              ListTile(
                title: Text(category.categoryName),
                subtitle: category.parentCategoryNo.isEmpty
                    ? null
                    : Text('分类编号：${category.categoryNo}'),
                trailing: Icon(
                  category.hasChildren
                      ? Icons.chevron_right
                      : Icons.radio_button_unchecked,
                ),
                onTap: () => _selectCategory(category),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportForm() {
    final selectedCategory = _selectedLeafCategory!;
    final rootCategory = _selectedRootCategory;
    final selectedReason =
        rootCategory != null &&
            rootCategory.categoryNo != selectedCategory.categoryNo
        ? '${rootCategory.categoryName} / ${selectedCategory.categoryName}'
        : selectedCategory.categoryName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('举报原因'),
                subtitle: Text(selectedReason),
                trailing: TextButton(
                  onPressed: _isSubmitting ? null : _resetCategorySelection,
                  child: const Text('重选'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '图片证据（选填）',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < _evidenceImages.length; i++)
                      _EvidenceImageTile(
                        filePath: _evidenceImages[i].path,
                        onRemove: _isSubmitting
                            ? null
                            : () => _removeEvidenceImage(i),
                      ),
                    if (_canPickMoreImages)
                      _EvidenceAddTile(
                        count: _evidenceImages.length,
                        onTap: _pickEvidenceImages,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '补充说明（选填）',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _remarkController,
                  maxLength: 300,
                  maxLines: 5,
                  minLines: 4,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    hintText: '请输入更多说明，帮助平台判断问题',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '说明：举报原因必选，图片证据和补充说明按需填写。提交后会按服务端真实结果返回。',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EvidenceImageTile extends StatelessWidget {
  final String filePath;
  final VoidCallback? onRemove;

  const _EvidenceImageTile({required this.filePath, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(filePath),
            width: 88,
            height: 88,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 88,
              height: 88,
              color: Colors.grey[200],
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _EvidenceAddTile extends StatelessWidget {
  final VoidCallback onTap;
  final int count;

  const _EvidenceAddTile({required this.onTap, required this.count});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.grey.shade50,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined),
            const SizedBox(height: 6),
            Text('$count/9', style: TextStyle(color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}
