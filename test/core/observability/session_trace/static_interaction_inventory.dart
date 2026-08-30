import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

const Set<String> _identifierParameterNames = <String>{
  'identifier',
  'semanticIdentifier',
  'semanticsIdentifier',
  'accessibilityIdentifier',
};

/// Resolves every compile-time String passed to a production Semantics-ID
/// parameter. This deliberately uses the analyzer rather than source regexes,
/// so static const fields, local consts, conditionals, and imported constants
/// cannot silently escape the observability classification contract.
Future<Set<String>> resolvedStaticInteractionIdentifiers() async {
  final libPath = Directory('lib').resolveSymbolicLinksSync();
  final collection = AnalysisContextCollection(
    includedPaths: <String>[libPath],
    sdkPath: _dartSdkPath(),
  );
  final identifiers = <String>{};
  final units = <CompilationUnit>[];
  try {
    final files = Directory(libPath)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);
    for (final file in files) {
      final path = file.resolveSymbolicLinksSync();
      final result = await collection
          .contextFor(path)
          .currentSession
          .getResolvedUnit(path);
      if (result is! ResolvedUnitResult) {
        throw StateError('Could not resolve production source: $path');
      }
      units.add(result.unit);
    }
    final forwardedParameters = <FormalParameterElement>{};
    var previousCount = -1;
    while (previousCount != forwardedParameters.length) {
      previousCount = forwardedParameters.length;
      for (final unit in units) {
        unit.accept(_ForwardedIdentifierVisitor(forwardedParameters));
      }
    }
    for (final unit in units) {
      unit.accept(_StaticIdentifierVisitor(identifiers, forwardedParameters));
    }
  } finally {
    await collection.dispose();
  }
  return identifiers;
}

String _dartSdkPath() {
  var directory = File(Platform.resolvedExecutable).parent;
  while (true) {
    for (final candidate in <Directory>[
      directory,
      Directory('${directory.path}/dart-sdk'),
    ]) {
      final libraries = File(
        '${candidate.path}/lib/_internal/sdk_library_metadata/lib/'
        'libraries.dart',
      );
      if (libraries.existsSync()) return candidate.path;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError('Could not locate the Dart SDK for analyzer resolution.');
}

bool _isIdentifierParameterName(String name) =>
    _identifierParameterNames.contains(name) ||
    name.endsWith('Identifier') ||
    name == 'semanticId' ||
    name == 'semanticsId';

final class _ForwardedIdentifierVisitor extends RecursiveAstVisitor<void> {
  _ForwardedIdentifierVisitor(this.forwardedParameters);

  final Set<FormalParameterElement> forwardedParameters;

  @override
  void visitNamedExpression(NamedExpression node) {
    if (_isIdentifierParameterName(node.name.label.name) ||
        forwardedParameters.contains(node.element)) {
      final expression = node.expression;
      if (expression is SimpleIdentifier &&
          expression.element is FormalParameterElement) {
        forwardedParameters.add(expression.element! as FormalParameterElement);
      }
    }
    super.visitNamedExpression(node);
  }
}

final class _StaticIdentifierVisitor extends RecursiveAstVisitor<void> {
  _StaticIdentifierVisitor(this.identifiers, this.forwardedParameters);

  final Set<String> identifiers;
  final Set<FormalParameterElement> forwardedParameters;

  @override
  void visitNamedExpression(NamedExpression node) {
    if (_isIdentifierParameterName(node.name.label.name) ||
        forwardedParameters.contains(node.element)) {
      _collectStaticStrings(node.expression);
    }
    super.visitNamedExpression(node);
  }

  @override
  void visitDefaultFormalParameter(DefaultFormalParameter node) {
    final name = node.name?.lexeme;
    final defaultValue = node.defaultValue;
    final element = node.declaredFragment?.element;
    if (defaultValue != null &&
        ((name != null && _isIdentifierParameterName(name)) ||
            forwardedParameters.contains(element))) {
      _collectStaticStrings(defaultValue);
    }
    super.visitDefaultFormalParameter(node);
  }

  void _collectStaticStrings(Expression expression) {
    final identifier = expression
        .computeConstantValue()
        ?.value
        ?.toStringValue();
    if (identifier != null) {
      if (identifier.isNotEmpty) identifiers.add(identifier);
      return;
    }
    switch (expression) {
      case ConditionalExpression(:final thenExpression, :final elseExpression):
        _collectStaticStrings(thenExpression);
        _collectStaticStrings(elseExpression);
      case BinaryExpression(:final leftOperand, :final rightOperand)
          when expression.operator.lexeme == '??':
        _collectStaticStrings(leftOperand);
        _collectStaticStrings(rightOperand);
      case ParenthesizedExpression(:final expression):
        _collectStaticStrings(expression);
      default:
        break;
    }
  }
}
