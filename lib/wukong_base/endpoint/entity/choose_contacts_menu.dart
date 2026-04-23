import 'base_endpoint.dart';
import '../../entity/channel.dart';

/// Callback when selection is complete
typedef ChooseBackCallback = void Function(List<WKChannel> selectedList);

/// Used for selecting contacts in various scenarios
class ChooseContactsMenu extends BaseEndpoint {
  /// Maximum number of selections allowed
  final int maxCount;

  /// Default selected contacts
  final List<WKChannel>? defaultSelected;

  /// Callback when selection is complete
  final ChooseBackCallback? onChooseBack;

  /// Whether default selections can be deselected
  final bool isCanDeselect;

  /// Whether to show save label dialog
  final bool isShowSaveLabelDialog;

  ChooseContactsMenu({
    required super.sid,
    required this.maxCount,
    this.defaultSelected,
    this.onChooseBack,
    this.isCanDeselect = false,
    this.isShowSaveLabelDialog = false,
  });
}
