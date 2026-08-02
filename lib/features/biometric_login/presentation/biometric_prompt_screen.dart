import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';
import '../../../l10n/app_localizations.dart';
import '../application/biometric_cubit.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/biometric_prompt_screen_fixtures.dart';

class BiometricPromptScreen extends StatelessWidget {
  const BiometricPromptScreen({super.key, this.cubit});

  final BiometricCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<BiometricCubit>.value(
        value: provided,
        child: const _BiometricPromptScaffold(),
      );
    }
    return BlocProvider(
      create: (_) => BiometricCubit()..checkAvailability(),
      child: const _BiometricPromptScaffold(),
    );
  }
}

class _BiometricPromptScaffold extends StatelessWidget {
  const _BiometricPromptScaffold();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BiometricCubit, BiometricState>(
      builder: (context, state) {
        return Semantics(
          identifier: 'biometric_prompt_root',
          container: true,
          child: Scaffold(
          body: SafeArea(
            child: Center(
              child: _PromptColumn(state: state),
            ),
          ),
        ),
        );
      },
    );
  }
}

class _PromptColumn extends StatelessWidget {
  const _PromptColumn({required this.state});
  final BiometricState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _PromptHeader(),
        const SizedBox(height: Spacing.fourXLarge),
        _PromptAction(state: state),
      ],
    );
  }
}

class _PromptHeader extends StatelessWidget {
  const _PromptHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          Icons.fingerprint,
          size: Sizes.eightXLarge,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: Spacing.xLarge),
        Text(
          AppLocalizations.of(context).useBiometrics,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: Spacing.small),
        Text(
          'Sign in quickly with your fingerprint or face',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PromptAction extends StatelessWidget {
  const _PromptAction({required this.state});
  final BiometricState state;

  @override
  Widget build(BuildContext context) {
    if (state == BiometricState.available) {
      return Semantics(
        identifier: 'biometric_prompt_authenticate_cta',
        button: true,
        container: true,
        child: OmdsPrimaryButton(
        text: 'Authenticate',
        icon: const Icon(Icons.fingerprint),
        onTap: () => context.read<BiometricCubit>().authenticate(),
      ),
      );
    }
    if (state == BiometricState.checking) {
      return const OmdsLoadingState();
    }
    if (state == BiometricState.unavailable) {
      return Text(AppLocalizations.of(context).biometricNotAvailable);
    }
    return const SizedBox.shrink();
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, not shipped. Previews are tree-shaken out of release builds.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _biometricPromptScreenPhoneBox = Size(390, 844);

/// The smallest display the app still has to look right on (iPhone SE 1st gen
/// class), used for the accessibility-ceiling card.
const Size _biometricPromptScreenCompactBox = Size(320, 568);

final class BiometricPromptScreenCaptions {
  BiometricPromptScreenCaptions._();

  /// Mounted, probe not yet run.
  static const String initial = 'preview · initial · probe has not run';

  /// The availability probe is in flight.
  static const String checking = 'preview · checking · probe in flight';

  /// Hardware present and enrolled.
  static const String available = 'preview · available · the only state with '
      'a button';

  /// No hardware, or nothing enrolled.
  static const String unavailable = 'preview · unavailable · nothing enrolled';

  /// The OS prompt rejected the user.
  static const String failed = 'preview · failed · no error, no retry';

  /// The OS prompt accepted the user.
  static const String authenticated = 'preview · authenticated · nothing '
      'happens';

  /// The accessibility ceiling on the smallest supported display.
  static const String compactLargeText = 'preview · unavailable · 320x568 · '
      '200% text';
}

class _BiometricPromptScreenHost extends StatefulWidget {
  const _BiometricPromptScreenHost({
    required this.createCubit,
    required this.caption,
    super.key,
    this.window,
    this.textScale,
  });

  final BiometricCubit Function() createCubit;

  /// The line painted above the screen — see note 2 in the prose.
  final String caption;

  /// Logical size of the simulated display, or `null` to use the real one.
  final Size? window;

  final double? textScale;

  @override
  State<_BiometricPromptScreenHost> createState() =>
      _BiometricPromptScreenHostState();
}

class _BiometricPromptScreenHostState
    extends State<_BiometricPromptScreenHost> {
  late final BiometricCubit _cubit = widget.createCubit();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Widget _caption(ThemeData theme) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.small,
          vertical: Spacing.xSmall,
        ),
        child: Text(
          widget.caption,
          // Dev chrome: LTR and unscaled, so the AR card still reads it as one
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget screen = BiometricPromptScreen(cubit: _cubit);
    final Size? window = widget.window;

    if (window == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _caption(theme),
          Expanded(child: screen),
        ],
      );
    }

    // Unbound on both axes. The render tests pump onto 800 x 600; an `Align` +
    return Material(
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _caption(theme),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: window,
                    padding: EdgeInsets.zero,
                    viewPadding: EdgeInsets.zero,
                    viewInsets: EdgeInsets.zero,
                    // Null leaves the ambient scaler alone — see the field doc.
                    textScaler: widget.textScale == null
                        ? null
                        : TextScaler.linear(widget.textScale!),
                  ),
                  child: SizedBox.fromSize(size: window, child: screen),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _biometricPromptScreenHosted(
  BiometricCubit Function() createCubit,
  String caption, {
  Size? window,
  double? textScale,
}) =>
    _BiometricPromptScreenHost(
      // Keyed by caption so two previews pumped back to back in the same test
      key: ValueKey<String>(caption),
      createCubit: createCubit,
      caption: caption,
      window: window,
      textScale: textScale,
    );

@JeebPreview(
  group: 'biometric_login',
  name: 'Initial · before the probe',
  size: _biometricPromptScreenPhoneBox,
)
Widget biometricPromptScreenInitial() => _biometricPromptScreenHosted(
      biometricPromptScreenInitialCubit,
      BiometricPromptScreenCaptions.initial,
    );

@JeebPreview(
  group: 'biometric_login',
  name: 'Checking · probe in flight',
  size: _biometricPromptScreenPhoneBox,
)
Widget biometricPromptScreenChecking() => _biometricPromptScreenHosted(
      biometricPromptScreenCheckingCubit,
      BiometricPromptScreenCaptions.checking,
    );

@JeebPreview(
  group: 'biometric_login',
  name: 'Available · authenticate CTA',
  size: _biometricPromptScreenPhoneBox,
  matrix: true,
)
Widget biometricPromptScreenAvailable() => _biometricPromptScreenHosted(
      biometricPromptScreenAvailableCubit,
      BiometricPromptScreenCaptions.available,
    );

@JeebPreview(
  group: 'biometric_login',
  name: 'Unavailable · nothing enrolled',
  size: _biometricPromptScreenPhoneBox,
)
Widget biometricPromptScreenUnavailable() => _biometricPromptScreenHosted(
      biometricPromptScreenUnavailableCubit,
      BiometricPromptScreenCaptions.unavailable,
    );

@JeebPreview(
  group: 'biometric_login',
  name: 'Failed · no error, no retry',
  size: _biometricPromptScreenPhoneBox,
)
Widget biometricPromptScreenFailed() => _biometricPromptScreenHosted(
      biometricPromptScreenFailedCubit,
      BiometricPromptScreenCaptions.failed,
    );

@JeebPreview(
  group: 'biometric_login',
  name: 'Authenticated · success is invisible',
  size: _biometricPromptScreenPhoneBox,
)
Widget biometricPromptScreenAuthenticated() => _biometricPromptScreenHosted(
      biometricPromptScreenAuthenticatedCubit,
      BiometricPromptScreenCaptions.authenticated,
    );

@JeebPreview(
  group: 'biometric_login',
  name: 'Unavailable · compact at 200% text',
  size: _biometricPromptScreenCompactBox,
)
Widget biometricPromptScreenCompactLargeText() => _biometricPromptScreenHosted(
      biometricPromptScreenUnavailableCubit,
      BiometricPromptScreenCaptions.compactLargeText,
      window: _biometricPromptScreenCompactBox,
      textScale: 2,
    );
