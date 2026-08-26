import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:omds/omds.dart';

import '../core/config/internal_release_policy.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'internal_devtool_semantics.dart';
import 'internal_devtool_services.dart';

class InternalDevToolApp extends StatelessWidget {
  const InternalDevToolApp({
    super.key,
    this.unlocker,
    this.statusReader,
    this.localDataClearer,
    this.closer,
    this.locale,
    this.localizationsDelegateOverride,
  });

  final InternalDeviceUnlocker? unlocker;
  final InternalDevToolStatusReader? statusReader;
  final InternalLocalDataClearer? localDataClearer;
  final InternalDevToolCloser? closer;
  final Locale? locale;
  final LocalizationsDelegate<AppLocalizations>? localizationsDelegateOverride;

  @override
  Widget build(BuildContext context) => _InternalMaterialApp(
    locale: locale,
    localizationsDelegateOverride: localizationsDelegateOverride,
    home: InternalDevToolUnlockGate(
      unlocker: unlocker ?? LocalAuthInternalDeviceUnlocker(),
      statusReader: statusReader ?? const PlatformInternalDevToolStatusReader(),
      localDataClearer:
          localDataClearer ?? const PlatformInternalLocalDataClearer(),
      closer: closer ?? const SystemNavigatorInternalDevToolCloser(),
    ),
  );
}

class InternalReleaseBlockedApp extends StatelessWidget {
  const InternalReleaseBlockedApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const _InternalMaterialApp(home: _InternalReleaseBlockedScreen());
}

class _InternalMaterialApp extends StatelessWidget {
  const _InternalMaterialApp({
    required this.home,
    this.locale,
    this.localizationsDelegateOverride,
  });

  final Widget home;
  final Locale? locale;
  final LocalizationsDelegate<AppLocalizations>? localizationsDelegateOverride;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.midnight(),
    darkTheme: AppTheme.midnight(),
    themeMode: ThemeMode.dark,
    locale: locale ?? _initialLocale(),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      localizationsDelegateOverride ?? AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  );

  static Locale _initialLocale() {
    final device = PlatformDispatcher.instance.locale;
    final supported = AppLocalizations.supportedLocales.any(
      (locale) => locale.languageCode == device.languageCode,
    );
    return supported ? Locale(device.languageCode) : const Locale('en');
  }
}

class InternalDevToolUnlockGate extends StatefulWidget {
  const InternalDevToolUnlockGate({
    required this.unlocker,
    required this.statusReader,
    required this.localDataClearer,
    required this.closer,
    super.key,
  });

  final InternalDeviceUnlocker unlocker;
  final InternalDevToolStatusReader statusReader;
  final InternalLocalDataClearer localDataClearer;
  final InternalDevToolCloser closer;

  @override
  State<InternalDevToolUnlockGate> createState() =>
      _InternalDevToolUnlockGateState();
}

class _InternalDevToolUnlockGateState extends State<InternalDevToolUnlockGate>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _unlocking = false;
  bool _denied = false;
  bool _screenBuilt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_mustRelock(state)) _relock();
  }

  bool _mustRelock(AppLifecycleState state) =>
      state != AppLifecycleState.resumed;

  Future<void> _unlock() async {
    setState(() {
      _unlocking = true;
      _denied = false;
    });
    final l10n = AppLocalizations.of(context);
    final granted = await widget.unlocker.unlock(
      reason: l10n.internalDevToolUnlockReason,
    );
    if (!mounted) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final resumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    setState(() {
      _unlocking = false;
      _unlocked = granted && resumed;
      _screenBuilt = _screenBuilt || _unlocked;
      _denied = !granted;
    });
  }

  void _relock() {
    if (!mounted || (!_unlocked && !_denied)) return;
    setState(() {
      _unlocked = false;
      _denied = false;
    });
  }

  Future<bool> _reauthenticate(String reason) =>
      widget.unlocker.unlock(reason: reason);

  Future<void> _relockAndClose() async {
    _relock();
    await widget.closer.close();
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _unlocked ? 1 : 0,
      children: [
        _InternalUnlockScreen(
          unlocking: _unlocking,
          denied: _denied,
          onUnlock: _unlock,
          onClose: _relockAndClose,
        ),
        if (_screenBuilt)
          InternalDevToolScreen(
            reauthenticate: _reauthenticate,
            statusReader: widget.statusReader,
            localDataClearer: widget.localDataClearer,
            onRelockAndClose: _relockAndClose,
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}

class _InternalUnlockScreen extends StatelessWidget {
  const _InternalUnlockScreen({
    required this.unlocking,
    required this.denied,
    required this.onUnlock,
    required this.onClose,
  });

  final bool unlocking;
  final bool denied;
  final VoidCallback onUnlock;
  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: InternalDevToolSemantics.launcher,
      container: true,
      child: _InternalUnlockScaffold(
        title: l10n.internalDevToolTitle,
        onClose: onClose,
        content: _InternalUnlockContent(
          unlocking: unlocking,
          denied: denied,
          onUnlock: onUnlock,
        ),
      ),
    );
  }
}

class _InternalUnlockScaffold extends StatelessWidget {
  const _InternalUnlockScaffold({
    required this.title,
    required this.content,
    required this.onClose,
  });

  final String title;
  final Widget content;
  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: InternalDevToolSemantics.authGate,
    container: true,
    child: Scaffold(
      appBar: _InternalAppBar(title: title, onClose: onClose),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(Spacing.xLarge),
          child: content,
        ),
      ),
    ),
  );
}

class _InternalUnlockContent extends StatelessWidget {
  const _InternalUnlockContent({
    required this.unlocking,
    required this.denied,
    required this.onUnlock,
  });

  final bool unlocking;
  final bool denied;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InternalUnlockMessage(denied: denied),
        const SizedBox(height: Spacing.xLarge),
        _InternalUnlockButton(unlocking: unlocking, onUnlock: onUnlock),
      ],
    );
  }
}

class _InternalUnlockMessage extends StatelessWidget {
  const _InternalUnlockMessage({required this.denied});

  final bool denied;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        const Icon(Icons.lock_outline, size: Sizes.sixXLarge),
        const SizedBox(height: Spacing.xLarge),
        Text(l10n.internalDevToolUnlockTitle, textAlign: TextAlign.center),
        const SizedBox(height: Spacing.xSmall),
        Text(l10n.internalDevToolUnlockBody, textAlign: TextAlign.center),
        if (denied) ...[
          const SizedBox(height: Spacing.medium),
          Text(l10n.internalDevToolUnlockDenied, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _InternalUnlockButton extends StatelessWidget {
  const _InternalUnlockButton({
    required this.unlocking,
    required this.onUnlock,
  });

  final bool unlocking;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsPrimaryButton(
      identifier: InternalDevToolSemantics.unlock,
      text: unlocking
          ? l10n.internalDevToolUnlocking
          : l10n.internalDevToolUnlockAction,
      isEnabled: !unlocking,
      onTap: onUnlock,
    );
  }
}

class InternalDevToolScreen extends StatefulWidget {
  const InternalDevToolScreen({
    required this.reauthenticate,
    required this.statusReader,
    required this.localDataClearer,
    required this.onRelockAndClose,
    super.key,
  });

  final Future<bool> Function(String reason) reauthenticate;
  final InternalDevToolStatusReader statusReader;
  final InternalLocalDataClearer localDataClearer;
  final Future<void> Function() onRelockAndClose;

  @override
  State<InternalDevToolScreen> createState() => _InternalDevToolScreenState();
}

class _InternalDevToolScreenState extends State<InternalDevToolScreen> {
  late Future<InternalDevToolStatus> _status = widget.statusReader.read();
  String? _clearResult;

  void _refreshStatus() {
    final next = widget.statusReader.read();
    setState(() {
      _status = next;
    });
  }

  Future<void> _clearData() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirmClear(l10n);
    if (!confirmed || !mounted) return;
    final unlocked = await widget.reauthenticate(
      l10n.internalDevToolClearUnlockReason,
    );
    if (!unlocked || !mounted) return;
    await _performClear(l10n);
  }

  Future<bool> _confirmClear(AppLocalizations l10n) =>
      OmdsConfirmationDialog.show(
        context: context,
        title: l10n.internalDevToolClearConfirmTitle,
        content: l10n.internalDevToolClearConfirmBody,
        confirmText: l10n.internalDevToolClearConfirmAction,
        cancelText: l10n.internalDevToolCancel,
        isDestructive: true,
        barrierDismissible: false,
        identifier: InternalDevToolSemantics.clearConfirmation,
      );

  Future<void> _performClear(AppLocalizations l10n) async {
    try {
      await widget.localDataClearer.clear();
      if (!mounted) return;
      setState(() => _clearResult = l10n.internalDevToolCleared);
    } on Object {
      if (!mounted) return;
      setState(() => _clearResult = l10n.internalDevToolClearFailed);
      showOmdsErrorSnackbar(context, message: l10n.internalDevToolClearFailed);
    } finally {
      if (mounted) await widget.onRelockAndClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: InternalDevToolSemantics.root,
      container: true,
      child: Scaffold(
        appBar: _InternalAppBar(
          title: l10n.internalDevToolTitle,
          onClose: widget.onRelockAndClose,
        ),
        body: SafeArea(
          child: FutureBuilder<InternalDevToolStatus>(
            future: _status,
            builder: (context, snapshot) => _InternalDevToolBody(
              snapshot: snapshot,
              clearResult: _clearResult,
              onRefresh: _refreshStatus,
              onClear: _clearData,
            ),
          ),
        ),
      ),
    );
  }
}

class _InternalDevToolBody extends StatelessWidget {
  const _InternalDevToolBody({
    required this.snapshot,
    required this.clearResult,
    required this.onRefresh,
    required this.onClear,
  });

  final AsyncSnapshot<InternalDevToolStatus> snapshot;
  final String? clearResult;
  final VoidCallback onRefresh;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsetsDirectional.all(Spacing.medium),
      children: [
        const _InternalQaBanner(),
        const SizedBox(height: Spacing.xLarge),
        _InternalStatusSnapshot(snapshot: snapshot, onRefresh: onRefresh),
        const SizedBox(height: Spacing.xLarge),
        _InternalClearSection(onClear: onClear),
        _InternalClearResult(message: clearResult),
      ],
    );
  }
}

class _InternalStatusSnapshot extends StatelessWidget {
  const _InternalStatusSnapshot({
    required this.snapshot,
    required this.onRefresh,
  });

  final AsyncSnapshot<InternalDevToolStatus> snapshot;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => snapshot.hasData
      ? _InternalStatusSection(
          status: snapshot.requireData,
          onRefresh: onRefresh,
        )
      : OmdsLoadingState(
          message: AppLocalizations.of(context).internalDevToolLoadingStatus,
        );
}

class _InternalClearResult extends StatelessWidget {
  const _InternalClearResult({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Semantics(
          identifier: InternalDevToolSemantics.clearResult,
          liveRegion: true,
          label: message,
          child: const SizedBox.shrink(),
        );
}

class _InternalQaBanner extends StatelessWidget {
  const _InternalQaBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: InternalDevToolSemantics.banner,
      container: true,
      header: true,
      child: OMDSProgressBanner(
        progress: 1,
        showPercentage: false,
        title: l10n.internalDevToolBannerTitle,
        subtitle: l10n.internalDevToolBannerSubtitle,
        backgroundColor: scheme.errorContainer,
        foregroundColor: scheme.onErrorContainer,
      ),
    );
  }
}

class _InternalStatusSection extends StatelessWidget {
  const _InternalStatusSection({required this.status, required this.onRefresh});

  final InternalDevToolStatus status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: InternalDevToolSemantics.status,
      container: true,
      child: OMDSSectionCard(
        title: l10n.internalDevToolStatusSection,
        content: _InternalStatusContent(
          status: status,
          refreshLabel: l10n.internalDevToolRefreshConnectivity,
          onRefresh: onRefresh,
        ),
      ),
    );
  }
}

class _InternalStatusContent extends StatelessWidget {
  const _InternalStatusContent({
    required this.status,
    required this.refreshLabel,
    required this.onRefresh,
  });

  final InternalDevToolStatus status;
  final String refreshLabel;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _InternalStatusRows(status: status),
      const SizedBox(height: Spacing.medium),
      OmdsPrimaryButton(
        identifier: InternalDevToolSemantics.connectivityProbe,
        text: refreshLabel,
        variant: OmdsButtonVariant.outlined,
        onTap: onRefresh,
      ),
    ],
  );
}

class _InternalStatusRows extends StatelessWidget {
  const _InternalStatusRows({required this.status});

  final InternalDevToolStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InternalBuildStatusRows(status: status),
        _InternalConnectivityRows(status: status),
      ],
    );
  }
}

class _InternalBuildStatusRows extends StatelessWidget {
  const _InternalBuildStatusRows({required this.status});

  final InternalDevToolStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InternalEnvironmentRows(status: status),
        const _InternalEndpointRows(),
        const _InternalPolicyRows(),
      ],
    );
  }
}

class _InternalEnvironmentRows extends StatelessWidget {
  const _InternalEnvironmentRows({required this.status});

  final InternalDevToolStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _StatusRow(
          identifier: InternalDevToolSemantics.runtime,
          label: l10n.internalDevToolRuntime,
          value: l10n.internalDevToolStaging,
        ),
        _StatusRow(
          identifier: InternalDevToolSemantics.build,
          label: l10n.internalDevToolBuild,
          value: status.buildLabel,
        ),
      ],
    );
  }
}

class _InternalEndpointRows extends StatelessWidget {
  const _InternalEndpointRows();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _StatusRow(
          identifier: InternalDevToolSemantics.gateway,
          label: l10n.internalDevToolGateway,
          value: InternalReleasePolicy.gatewayOrigin,
        ),
        _StatusRow(
          identifier: InternalDevToolSemantics.realtime,
          label: l10n.internalDevToolRealtime,
          value: InternalReleasePolicy.realtimeSocket,
        ),
      ],
    );
  }
}

class _InternalPolicyRows extends StatelessWidget {
  const _InternalPolicyRows();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _StatusRow(
          identifier: InternalDevToolSemantics.clarity,
          label: l10n.internalDevToolClarity,
          value: l10n.internalDevToolOff,
        ),
        _StatusRow(
          identifier: InternalDevToolSemantics.authentication,
          label: l10n.internalDevToolAuth,
          value: l10n.internalDevToolNormalSmsOnly,
        ),
      ],
    );
  }
}

class _InternalConnectivityRows extends StatelessWidget {
  const _InternalConnectivityRows({required this.status});

  final InternalDevToolStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = status.networkAvailable
        ? l10n.internalDevToolNetworkAvailable
        : l10n.internalDevToolNetworkUnavailable;
    return Column(
      children: [
        _StatusRow(
          identifier: InternalDevToolSemantics.connectivity,
          label: l10n.internalDevToolConnectivity,
          value: value,
        ),
        Text(l10n.internalDevToolNoGatewayProbe, textAlign: TextAlign.start),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.identifier,
    required this.label,
    required this.value,
  });

  final String identifier;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: identifier,
    container: true,
    child: Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.xSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: Spacing.medium),
          Expanded(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    ),
  );
}

class _InternalClearSection extends StatelessWidget {
  const _InternalClearSection({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OMDSSectionCard(
      title: l10n.internalDevToolClearSection,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.internalDevToolClearBody),
          const SizedBox(height: Spacing.medium),
          OmdsPrimaryButton(
            identifier: InternalDevToolSemantics.clearData,
            text: l10n.internalDevToolClearAction,
            variant: OmdsButtonVariant.outlined,
            onTap: onClear,
          ),
        ],
      ),
    );
  }
}

class _InternalReleaseBlockedScreen extends StatelessWidget {
  const _InternalReleaseBlockedScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: OmdsErrorState(
          title: l10n.internalDevToolBlockedTitle,
          message: l10n.internalDevToolBlockedBody,
          icon: Icons.lock_outline,
        ),
      ),
    );
  }
}

class _InternalAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _InternalAppBar({required this.title, required this.onClose});

  final String title;
  final Future<void> Function() onClose;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => OMDSAppBar(
    title: title,
    actions: [
      OmdsPrimaryButton(
        identifier: InternalDevToolSemantics.close,
        text: MaterialLocalizations.of(context).closeButtonLabel,
        variant: OmdsButtonVariant.text,
        width: Sizes.eightXLarge,
        height: Sizes.fourXLarge,
        onTap: onClose,
      ),
    ],
  );
}
