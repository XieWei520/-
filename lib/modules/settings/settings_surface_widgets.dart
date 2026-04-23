import 'package:flutter/material.dart';

import 'settings_strings.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_theme.dart';

class SettingsScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onSave;
  final List<Widget>? actions;
  final Key? saveActionKey;
  final bool loading;

  const SettingsScaffold({
    super.key,
    required this.title,
    required this.child,
    this.onSave,
    this.actions,
    this.saveActionKey,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final strings = resolveSettingsStrings(
      locale: Localizations.localeOf(context),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (onSave != null)
            TextButton(
              key: saveActionKey,
              onPressed: onSave,
              child: Text(strings.save),
            ),
          ...?actions,
        ],
      ),
      body: Stack(
        children: [
          child,
          if (loading)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class SettingsHero extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const SettingsHero({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(WKSpace.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [WKColors.brand50, WKColors.surface],
        ),
        borderRadius: BorderRadius.circular(WKRadius.xl),
        border: Border.all(color: WKColors.outline),
        boxShadow: WKShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: WKTheme.brandGradient,
              borderRadius: BorderRadius.circular(WKRadius.lg),
            ),
            child: Icon(icon, color: WKColors.white),
          ),
          const SizedBox(width: WKSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.xl),
        border: Border.all(color: WKColors.outline),
        boxShadow: WKShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WKSpace.lg,
              WKSpace.lg,
              WKSpace.lg,
              WKSpace.sm,
            ),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const Divider(indent: 72, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class SettingsInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isError;
  final Widget? trailing;

  const SettingsInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isError = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isError ? WKColors.danger : WKColors.brand500;
    final accentBackground = isError
        ? WKColors.danger.withValues(alpha: 0.08)
        : WKColors.brand50;
    return Container(
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.xl),
        border: Border.all(color: WKColors.outline),
        boxShadow: WKShadows.soft,
      ),
      padding: const EdgeInsets.all(WKSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentBackground,
              borderRadius: BorderRadius.circular(WKRadius.lg),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accentColor),
          ),
          const SizedBox(width: WKSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: WKSpace.xs),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: WKColors.color999),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: WKSpace.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class SettingsSearchCard extends StatelessWidget {
  final TextEditingController controller;
  final Key? fieldKey;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  const SettingsSearchCard({
    super.key,
    required this.controller,
    this.fieldKey,
    required this.hintText,
    required this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.xl),
        border: Border.all(color: WKColors.outline),
        boxShadow: WKShadows.soft,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: WKSpace.md,
        vertical: WKSpace.sm,
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          return TextField(
            key: fieldKey,
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: WKColors.color999,
              ),
              suffixIcon: onClear != null && value.text.trim().isNotEmpty
                  ? IconButton(
                      key: const ValueKey<String>('settings-search-clear'),
                      onPressed: onClear,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: WKColors.color999,
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class SwitchSettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SwitchSettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: _LeadingIcon(icon: icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class ActionSettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ActionSettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _LeadingIcon(icon: icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  final IconData icon;

  const _LeadingIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: WKColors.surfaceSoft,
        borderRadius: BorderRadius.circular(WKRadius.md),
      ),
      child: Icon(icon),
    );
  }
}
