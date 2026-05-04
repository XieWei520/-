import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../widgets/wk_colors.dart';
import '../../../../widgets/wk_design_tokens.dart';
import 'auth_copy.dart';

@immutable
class AuthAreaCodeOption {
  const AuthAreaCodeOption({required this.zoneCode, required this.countryName});

  final String zoneCode;
  final String countryName;

  String get normalizedZoneCode {
    final digits = zoneCode.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return '0000';
    }
    if (digits.startsWith('00')) {
      return digits;
    }
    final prefixed = digits.startsWith('0') ? '0$digits' : '00$digits';
    return prefixed.padLeft(4, '0');
  }

  String get displayDialCode {
    final stripped = normalizedZoneCode
        .replaceFirst(RegExp(r'^00'), '')
        .replaceFirst(RegExp(r'^0+'), '');
    return '+$stripped';
  }
}

class AuthAreaCodePicker extends StatelessWidget {
  const AuthAreaCodePicker({
    super.key,
    required this.selectedZoneCode,
    required this.onChanged,
    this.options = defaultOptions,
  });

  final String selectedZoneCode;
  final ValueChanged<AuthAreaCodeOption> onChanged;
  final List<AuthAreaCodeOption> options;

  static const String mainlandChinaZoneCode = '0086';

  static const List<AuthAreaCodeOption> defaultOptions = [
    AuthAreaCodeOption(zoneCode: mainlandChinaZoneCode, countryName: '中国'),
    AuthAreaCodeOption(zoneCode: '0001', countryName: '美国'),
    AuthAreaCodeOption(zoneCode: '0044', countryName: '英国'),
    AuthAreaCodeOption(zoneCode: '0081', countryName: '日本'),
    AuthAreaCodeOption(zoneCode: '0082', countryName: '韩国'),
    AuthAreaCodeOption(zoneCode: '0852', countryName: '中国香港'),
    AuthAreaCodeOption(zoneCode: '0886', countryName: '中国台湾'),
    AuthAreaCodeOption(zoneCode: '0065', countryName: '新加坡'),
    AuthAreaCodeOption(zoneCode: '0060', countryName: '马来西亚'),
    AuthAreaCodeOption(zoneCode: '0061', countryName: '澳大利亚'),
  ];

  AuthAreaCodeOption get _selectedOption {
    final normalized = selectedZoneCode.replaceAll(RegExp(r'[^0-9]'), '');
    return options.firstWhere(
      (option) => option.normalizedZoneCode == normalized,
      orElse: () => options.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final option = _selectedOption;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('auth_login_zone_trigger'),
        borderRadius: BorderRadius.circular(WKRadius.md),
        onTap: () async {
          final selected = await showAuthAreaCodePicker(
            context: context,
            options: options,
            selectedZoneCode: option.normalizedZoneCode,
          );
          if (selected == null) {
            return;
          }
          onChanged(selected);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: WKColors.surfaceSoft,
            borderRadius: BorderRadius.circular(WKRadius.md),
            border: Border.all(color: WKColors.colorLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                option.displayDialCode,
                style: const TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 14,
                  color: WKColors.colorDark,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: WKColors.color999,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<AuthAreaCodeOption?> showAuthAreaCodePicker({
  required BuildContext context,
  required List<AuthAreaCodeOption> options,
  required String selectedZoneCode,
}) {
  return showModalBottomSheet<AuthAreaCodeOption>(
    context: context,
    backgroundColor: WKColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(WKRadius.xl)),
    ),
    builder: (sheetContext) {
      final maxHeight = math.min(
        MediaQuery.of(context).size.height * 0.72,
        420.0,
      );
      final selected = selectedZoneCode.replaceAll(RegExp(r'[^0-9]'), '');

      return SafeArea(
        child: SizedBox(
          key: const ValueKey('auth_area_code_sheet'),
          height: maxHeight,
          child: Column(
            children: [
              const SizedBox(height: 14),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: WKColors.colorE8E7E7,
                  borderRadius: BorderRadius.circular(WKRadius.pill),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                AuthCopy.areaCodePickerTitle,
                style: TextStyle(
                  fontFamily: WKFontFamily.title,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: WKColors.colorDark,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final option = options[index];
                    final optionKey = option.normalizedZoneCode;
                    final isSelected = selected == optionKey;
                    return ListTile(
                      key: ValueKey('auth_area_code_option_$optionKey'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        option.countryName,
                        style: const TextStyle(
                          fontFamily: WKFontFamily.primary,
                          fontSize: 14,
                          color: WKColors.colorDark,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            option.displayDialCode,
                            style: const TextStyle(
                              fontFamily: WKFontFamily.primary,
                              fontSize: 14,
                              color: WKColors.color999,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: isSelected
                                ? WKColors.brand500
                                : Colors.transparent,
                          ),
                        ],
                      ),
                      onTap: () => Navigator.of(sheetContext).pop(option),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
