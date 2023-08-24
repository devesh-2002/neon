import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:neon/l10n/localizations.dart';
import 'package:neon/src/blocs/accounts.dart';
import 'package:neon/src/models/account.dart';
import 'package:neon/src/models/app_implementation.dart';
import 'package:neon/src/platform/platform.dart';
import 'package:neon/src/router.dart';
import 'package:neon/src/settings/widgets/account_settings_tile.dart';
import 'package:neon/src/settings/widgets/checkbox_settings_tile.dart';
import 'package:neon/src/settings/widgets/custom_settings_tile.dart';
import 'package:neon/src/settings/widgets/dropdown_button_settings_tile.dart';
import 'package:neon/src/settings/widgets/settings_category.dart';
import 'package:neon/src/settings/widgets/settings_list.dart';
import 'package:neon/src/settings/widgets/settings_tile.dart';
import 'package:neon/src/settings/widgets/text_settings_tile.dart';
import 'package:neon/src/theme/branding.dart';
import 'package:neon/src/theme/dialog.dart';
import 'package:neon/src/utils/confirmation_dialog.dart';
import 'package:neon/src/utils/global_options.dart';
import 'package:neon/src/utils/save_file.dart';
import 'package:neon/src/utils/settings_export_helper.dart';
import 'package:neon/src/widgets/exception.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

enum SettingsCageories {
  apps,
  theme,
  navigation,
  pushNotifications,
  startup,
  systemTray,
  accounts,
  other,
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    this.initialCategory,
    super.key,
  });

  final SettingsCageories? initialCategory;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(final BuildContext context) {
    final globalOptions = Provider.of<GlobalOptions>(context);
    final accountsBloc = Provider.of<AccountsBloc>(context, listen: false);
    final appImplementations = Provider.of<Iterable<AppImplementation>>(context);

    final appBar = AppBar(
      title: Text(AppLocalizations.of(context).settings),
      actions: [
        IconButton(
          onPressed: () async {
            if (await showConfirmationDialog(context, AppLocalizations.of(context).settingsResetAllConfirmation)) {
              globalOptions.reset();

              for (final appImplementation in appImplementations) {
                appImplementation.options.reset();
              }

              for (final account in accountsBloc.accounts.value) {
                accountsBloc.getOptionsFor(account).reset();
              }
            }
          },
          tooltip: AppLocalizations.of(context).settingsResetAll,
          icon: Icon(MdiIcons.cogRefresh),
        ),
      ],
    );
    final body = StreamBuilder<List<Account>>(
      stream: accountsBloc.accounts,
      initialData: accountsBloc.accounts.valueOrNull,
      builder: (
        final context,
        final accountsSnapshot,
      ) {
        final platform = Provider.of<NeonPlatform>(context, listen: false);
        return ValueListenableBuilder<bool>(
          valueListenable: globalOptions.pushNotificationsEnabled,
          builder: (
            final context,
            final _,
            final __,
          ) =>
              SettingsList(
            initialCategory: widget.initialCategory?.name,
            categories: [
              SettingsCategory(
                title: Text(AppLocalizations.of(context).settingsApps),
                key: ValueKey(SettingsCageories.apps.name),
                tiles: <SettingsTile>[
                  for (final appImplementation in appImplementations) ...[
                    if (appImplementation.options.options.isNotEmpty) ...[
                      CustomSettingsTile(
                        leading: appImplementation.buildIcon(),
                        title: Text(appImplementation.name(context)),
                        onTap: () {
                          NextcloudAppSettingsRoute(appid: appImplementation.id).go(context);
                        },
                      ),
                    ],
                  ],
                ],
              ),
              SettingsCategory(
                title: Text(AppLocalizations.of(context).optionsCategoryTheme),
                key: ValueKey(SettingsCageories.theme.name),
                tiles: [
                  DropdownButtonSettingsTile(
                    option: globalOptions.themeMode,
                  ),
                  CheckBoxSettingsTile(
                    option: globalOptions.themeOLEDAsDark,
                  ),
                  CheckBoxSettingsTile(
                    option: globalOptions.themeKeepOriginalAccentColor,
                  ),
                ],
              ),
              SettingsCategory(
                title: Text(AppLocalizations.of(context).optionsCategoryNavigation),
                key: ValueKey(SettingsCageories.navigation.name),
                tiles: [
                  DropdownButtonSettingsTile(
                    option: globalOptions.navigationMode,
                  ),
                ],
              ),
              if (platform.canUsePushNotifications) ...[
                SettingsCategory(
                  title: Text(AppLocalizations.of(context).optionsCategoryPushNotifications),
                  key: ValueKey(SettingsCageories.pushNotifications.name),
                  tiles: [
                    if (!globalOptions.pushNotificationsEnabled.enabled) ...[
                      TextSettingsTile(
                        text: AppLocalizations.of(context).globalOptionsPushNotificationsEnabledDisabledNotice,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    CheckBoxSettingsTile(
                      option: globalOptions.pushNotificationsEnabled,
                    ),
                    DropdownButtonSettingsTile(
                      option: globalOptions.pushNotificationsDistributor,
                    ),
                  ],
                ),
              ],
              if (platform.canUseWindowManager) ...[
                SettingsCategory(
                  title: Text(AppLocalizations.of(context).optionsCategoryStartup),
                  key: ValueKey(SettingsCageories.startup.name),
                  tiles: [
                    CheckBoxSettingsTile(
                      option: globalOptions.startupMinimized,
                    ),
                    CheckBoxSettingsTile(
                      option: globalOptions.startupMinimizeInsteadOfExit,
                    ),
                  ],
                ),
              ],
              if (platform.canUseWindowManager && platform.canUseSystemTray) ...[
                SettingsCategory(
                  title: Text(AppLocalizations.of(context).optionsCategorySystemTray),
                  key: ValueKey(SettingsCageories.systemTray.name),
                  tiles: [
                    CheckBoxSettingsTile(
                      option: globalOptions.systemTrayEnabled,
                    ),
                    CheckBoxSettingsTile(
                      option: globalOptions.systemTrayHideToTrayWhenMinimized,
                    ),
                  ],
                ),
              ],
              SettingsCategory(
                title: Text(AppLocalizations.of(context).optionsCategoryAccounts),
                key: ValueKey(SettingsCageories.accounts.name),
                tiles: [
                  if (accountsSnapshot.requireData.length > 1) ...[
                    CheckBoxSettingsTile(
                      option: globalOptions.rememberLastUsedAccount,
                    ),
                    DropdownButtonSettingsTile(
                      option: globalOptions.initialAccount,
                    ),
                  ],
                  for (final account in accountsSnapshot.requireData) ...[
                    AccountSettingsTile(
                      account: account,
                      onTap: () {
                        AccountSettingsRoute(accountid: account.id).go(context);
                      },
                    ),
                  ],
                  CustomSettingsTile(
                    title: ElevatedButton.icon(
                      onPressed: () async => const LoginRoute().push(context),
                      icon: Icon(MdiIcons.accountPlus),
                      label: Text(AppLocalizations.of(context).globalOptionsAccountsAdd),
                    ),
                  ),
                ],
              ),
              SettingsCategory(
                title: Text(AppLocalizations.of(context).optionsCategoryOther),
                key: ValueKey(SettingsCageories.other.name),
                tiles: <SettingsTile>[
                  CustomSettingsTile(
                    leading: Icon(
                      MdiIcons.scriptText,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(AppLocalizations.of(context).licenses),
                    onTap: () async {
                      final branding = Branding.of(context);
                      showLicensePage(
                        context: context,
                        applicationName: branding.name,
                        applicationIcon: branding.logo,
                        applicationLegalese: branding.legalese,
                        applicationVersion: Provider.of<PackageInfo>(context, listen: false).version,
                      );
                    },
                  ),
                  CustomSettingsTile(
                    leading: Icon(
                      MdiIcons.export,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(AppLocalizations.of(context).settingsExport),
                    onTap: () async {
                      final settingsExportHelper = _buildSettingsExportHelper(context);

                      try {
                        final fileName =
                            'nextcloud-neon-settings-${DateTime.now().millisecondsSinceEpoch ~/ 1000}.json.base64';
                        final data = base64.encode(
                          utf8.encode(
                            json.encode(
                              settingsExportHelper.toJsonExport(),
                            ),
                          ),
                        );
                        await saveFileWithPickDialog(fileName, utf8.encode(data) as Uint8List);
                      } catch (e, s) {
                        debugPrint(e.toString());
                        debugPrint(s.toString());
                        if (mounted) {
                          NeonException.showSnackbar(context, e);
                        }
                      }
                    },
                  ),
                  CustomSettingsTile(
                    leading: Icon(
                      MdiIcons.import,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(AppLocalizations.of(context).settingsImport),
                    onTap: () async {
                      final settingsExportHelper = _buildSettingsExportHelper(context);

                      try {
                        final result = await FilePicker.platform.pickFiles(
                          withData: true,
                        );

                        if (result == null) {
                          return;
                        }

                        if (!result.files.single.path!.endsWith('.json.base64')) {
                          if (mounted) {
                            NeonException.showSnackbar(
                              context,
                              AppLocalizations.of(context).settingsImportWrongFileExtension,
                            );
                          }
                          return;
                        }

                        final data = json.decode(utf8.decode(base64.decode(utf8.decode(result.files.single.bytes!))));

                        await settingsExportHelper.applyFromJson(data as Map<String, dynamic>);
                      } catch (e, s) {
                        debugPrint(e.toString());
                        debugPrint(s.toString());
                        if (mounted) {
                          NeonException.showSnackbar(context, e);
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: appBar,
      body: Center(
        child: ConstrainedBox(
          constraints: NeonDialogTheme.of(context).constraints,
          child: body,
        ),
      ),
    );
  }

  SettingsExportHelper _buildSettingsExportHelper(final BuildContext context) {
    final globalOptions = Provider.of<GlobalOptions>(context);
    final accountsBloc = Provider.of<AccountsBloc>(context, listen: false);
    final appImplementations = Provider.of<Iterable<AppImplementation>>(context);

    return SettingsExportHelper(
      globalOptions: globalOptions,
      appImplementations: appImplementations,
      accountSpecificOptions: accountsBloc.accounts.value.asMap().map(
            (final _, final account) => MapEntry(account, accountsBloc.getOptionsFor(account).options),
          ),
    );
  }
}

enum SettingsAccountAction {
  settings,
  delete,
}
