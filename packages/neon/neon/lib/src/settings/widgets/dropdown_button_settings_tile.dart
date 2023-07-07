import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:neon/src/settings/models/select_option.dart';
import 'package:neon/src/settings/widgets/label_builder.dart';
import 'package:neon/src/settings/widgets/option_builder.dart';
import 'package:neon/src/settings/widgets/settings_tile.dart';

@internal
class DropdownButtonSettingsTile<T> extends InputSettingsTile<SelectOption<T>> {
  const DropdownButtonSettingsTile({
    required super.option,
    super.key,
  });

  @override
  Widget build(final BuildContext context) => OptionBuilder<T>(
        option: option,
        builder: (
          final context,
          final value,
        ) =>
            StreamBuilder<bool>(
          stream: option.enabled,
          builder: (
            final context,
            final enabledSnapshot,
          ) =>
              StreamBuilder<Map<T, LabelBuilder>>(
            stream: option.values,
            builder: (
              final context,
              final valuesSnapshot,
            ) =>
                LayoutBuilder(
              builder: (final context, final constraints) => ListTile(
                title: Text(
                  option.label(context),
                  style: enabledSnapshot.data ?? false
                      ? null
                      : Theme.of(context).textTheme.titleMedium!.copyWith(color: Theme.of(context).disabledColor),
                ),
                trailing: valuesSnapshot.hasData
                    ? ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.5,
                        ),
                        child: IntrinsicWidth(
                          child: DropdownButton<T>(
                            isExpanded: true,
                            value: value,
                            items: valuesSnapshot.requireData.keys
                                .map(
                                  (final k) => DropdownMenuItem(
                                    value: k,
                                    child: Text(
                                      valuesSnapshot.requireData[k]!(context),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: enabledSnapshot.data ?? false
                                ? (final value) async {
                                    await option.set(value as T);
                                  }
                                : null,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      );
}