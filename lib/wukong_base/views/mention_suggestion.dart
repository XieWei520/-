import 'package:flutter/material.dart';

/// Mention suggestion data
class MentionSuggestion {
  final String id;
  final String name;
  final String? avatar;
  final String? remark;
  final int type; // 0: user, 1: group

  MentionSuggestion({
    required this.id,
    required this.name,
    this.avatar,
    this.remark,
    this.type = 0,
  });
}

/// Mention suggestion overlay
class MentionSuggestionOverlay extends StatelessWidget {
  final List<MentionSuggestion> suggestions;
  final int selectedIndex;
  final Function(MentionSuggestion) onSelected;
  final VoidCallback? onDismiss;

  const MentionSuggestionOverlay({
    super.key,
    required this.suggestions,
    required this.selectedIndex,
    required this.onSelected,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(
          maxHeight: 250,
          maxWidth: 300,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '@提及',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Suggestions list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  final isSelected = index == selectedIndex;

                  return InkWell(
                    onTap: () => onSelected(suggestion),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      color: isSelected ? Colors.blue[50] : null,
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: suggestion.avatar != null
                                ? NetworkImage(suggestion.avatar!)
                                : null,
                            child: suggestion.avatar == null
                                ? Text(
                                    suggestion.name.isNotEmpty
                                        ? suggestion.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),

                          // Name and remark
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  suggestion.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (suggestion.remark != null)
                                  Text(
                                    suggestion.remark!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Type icon
                          if (suggestion.type == 1)
                            Icon(
                              Icons.group,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mention suggestion controller
class MentionSuggestionController extends ChangeNotifier {
  bool _isShowing = false;
  String _query = '';
  List<MentionSuggestion> _suggestions = [];
  int _selectedIndex = 0;

  bool get isShowing => _isShowing;
  String get query => _query;
  List<MentionSuggestion> get suggestions => _suggestions;
  int get selectedIndex => _selectedIndex;
  MentionSuggestion? get selectedSuggestion =>
      _suggestions.isNotEmpty ? _suggestions[_selectedIndex] : null;

  void show(List<MentionSuggestion> suggestions) {
    _isShowing = true;
    _suggestions = suggestions;
    _selectedIndex = 0;
    notifyListeners();
  }

  void hide() {
    _isShowing = false;
    _suggestions = [];
    _selectedIndex = 0;
    notifyListeners();
  }

  void updateSuggestions(List<MentionSuggestion> suggestions) {
    _suggestions = suggestions;
    _selectedIndex = 0;
    notifyListeners();
  }

  void setQuery(String query) {
    _query = query;
  }

  void selectNext() {
    if (_suggestions.isNotEmpty) {
      _selectedIndex = (_selectedIndex + 1) % _suggestions.length;
      notifyListeners();
    }
  }

  void selectPrevious() {
    if (_suggestions.isNotEmpty) {
      _selectedIndex = (_selectedIndex - 1 + _suggestions.length) % _suggestions.length;
      notifyListeners();
    }
  }

  void selectIndex(int index) {
    if (index >= 0 && index < _suggestions.length) {
      _selectedIndex = index;
      notifyListeners();
    }
  }
}
