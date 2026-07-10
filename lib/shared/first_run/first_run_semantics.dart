import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Generic first-run Semantics boundary.
class FirstRunSemanticTarget extends StatelessWidget {
  const FirstRunSemanticTarget({
    super.key,
    required this.identifier,
    required this.child,
    this.label,
    this.container = true,
    this.explicitChildNodes = false,
    this.button = false,
    this.enabled,
    this.textField = false,
    this.image = false,
  });

  final String identifier;
  final Widget child;
  final String? label;
  final bool container;
  final bool explicitChildNodes;
  final bool button;
  final bool? enabled;
  final bool textField;
  final bool image;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      label: label,
      container: container,
      explicitChildNodes: explicitChildNodes,
      button: button,
      enabled: enabled,
      textField: textField,
      image: image,
      child: child,
    );
  }
}

/// OMDS primary action with a stable first-run Semantics identifier.
class FirstRunPrimaryButton extends StatelessWidget {
  const FirstRunPrimaryButton({
    super.key,
    required this.identifier,
    required this.text,
    required this.onTap,
    this.buttonKey,
    this.variant = OmdsButtonVariant.primary,
    this.isEnabled = true,
    this.width,
  });

  final String identifier;
  final String text;
  final VoidCallback onTap;
  final Key? buttonKey;
  final OmdsButtonVariant variant;
  final bool isEnabled;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return FirstRunSemanticTarget(
      identifier: identifier,
      label: text,
      button: true,
      enabled: isEnabled,
      child: OmdsPrimaryButton(
        key: buttonKey,
        text: text,
        onTap: onTap,
        variant: variant,
        isEnabled: isEnabled,
        width: width,
      ),
    );
  }
}

/// OMDS loading action with a stable first-run Semantics identifier.
class FirstRunLoadingButton extends StatelessWidget {
  const FirstRunLoadingButton({
    super.key,
    required this.identifier,
    required this.text,
    required this.onTap,
    required this.isLoading,
    this.buttonKey,
    this.isEnabled = true,
  });

  final String identifier;
  final String text;
  final VoidCallback onTap;
  final bool isLoading;
  final Key? buttonKey;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return FirstRunSemanticTarget(
      identifier: identifier,
      label: text,
      button: true,
      enabled: isEnabled && !isLoading,
      child: OmdsLoadingButton(
        key: buttonKey,
        text: text,
        onTap: onTap,
        isLoading: isLoading,
        isEnabled: isEnabled,
      ),
    );
  }
}

/// OMDS OTP input with a stable first-run Semantics identifier.
class FirstRunOtpInput extends StatelessWidget {
  const FirstRunOtpInput({
    super.key,
    required this.identifier,
    required this.length,
    required this.hasError,
    this.inputKey,
    this.label,
    this.onChanged,
    this.onCompleted,
  });

  final String identifier;
  final int length;
  final bool hasError;
  final Key? inputKey;
  final String? label;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  @override
  Widget build(BuildContext context) {
    return FirstRunSemanticTarget(
      identifier: identifier,
      label: label,
      textField: true,
      child: OmdsOtpInput(
        key: inputKey,
        length: length,
        hasError: hasError,
        onChanged: onChanged,
        onCompleted: onCompleted,
      ),
    );
  }
}

/// OMDS loading region with a stable first-run Semantics identifier.
class FirstRunLoadingRegion extends StatelessWidget {
  const FirstRunLoadingRegion({
    super.key,
    required this.identifier,
    this.message,
    this.padding,
    this.size = Sizes.fourXLarge,
  });

  final String identifier;
  final String? message;
  final EdgeInsetsGeometry? padding;
  final double size;

  @override
  Widget build(BuildContext context) {
    return FirstRunSemanticTarget(
      identifier: identifier,
      child: OmdsLoadingState(message: message, padding: padding, size: size),
    );
  }
}
