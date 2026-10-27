import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

void main() {
  final root = _git(['rev-parse', '--show-toplevel']).trim();
  final files = {
    ..._git([
      'diff',
      '--name-only',
      'origin/main',
      '--',
      'apps/legal_link/lib',
    ], root).split('\n'),
    ..._git([
      'ls-files',
      '--others',
      '--exclude-standard',
      '--',
      'apps/legal_link/lib',
    ], root).split('\n'),
  };
  final errors = <String>[];
  for (final name in files.where((name) => name.endsWith('.dart'))) {
    final file = File('$root/$name');
    if (!file.existsSync()) continue;
    final source = file.readAsStringSync();
    if (source.split('\n').length >= 800) {
      errors.add('$name: file exceeds 799 lines');
    }
    final parsed = parseString(content: source, throwIfDiagnostics: false);
    parsed.unit.accept(_Functions(name, parsed.lineInfo.getLocation, errors));
  }
  if (errors.isNotEmpty) {
    stderr.writeln(errors.join('\n'));
    exitCode = 1;
  } else {
    stdout.writeln(
      'Role B source size gate: files <800 lines; functions <50 lines',
    );
  }
}

String _git(List<String> arguments, [String? cwd]) {
  final result = Process.runSync('git', arguments, workingDirectory: cwd);
  if (result.exitCode != 0) throw StateError(result.stderr.toString());
  return result.stdout.toString();
}

class _Functions extends RecursiveAstVisitor<void> {
  _Functions(this.file, this.location, this.errors);
  final String file;
  final dynamic Function(int) location;
  final List<String> errors;

  void _check(String name, AstNode node) {
    final start = location(node.offset).lineNumber as int;
    final end = location(node.end).lineNumber as int;
    if (end - start + 1 >= 50) {
      errors.add('$file:$start $name: ${end - start + 1} lines (limit 49)');
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _check(node.name.lexeme, node);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _check(node.name.lexeme, node);
    super.visitFunctionDeclaration(node);
  }
}
