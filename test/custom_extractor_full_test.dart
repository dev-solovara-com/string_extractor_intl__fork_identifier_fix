import 'dart:convert';
import 'dart:io';

import 'package:string_extractor_intl/string_extractor_intl_custom_full.dart';
import 'package:test/test.dart';

void main() {
  group('Custom localization extractor', () {
    late Directory tempDir;
    late String originalWorkingDirectory;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'string_extractor_intl_custom_test_',
      );

      originalWorkingDirectory = Directory.current.path;
      Directory.current = tempDir.path;
    });

    tearDown(() {
      Directory.current = originalWorkingDirectory;

      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<Map<String, dynamic>> extractFromSource(
      String source, {
      String fileName = 'main.dart',
    }) async {
      final inputDir = Directory('${tempDir.path}/lib')
        ..createSync(recursive: true);
      final outputDir = '${tempDir.path}/lib/l10n';

      final sourceFile = File('${inputDir.path}/$fileName');
      await sourceFile.writeAsString(source);

      final extractor = LocalizationStringExtractor();

      await extractor.extractStrings(
        inputDirectory: inputDir.path,
        outputDirectory: outputDir,
        templateArbFile: 'app_en.arb',
        className: 'AppLocalizations',
        checkDependencies: false,
        replaceInFiles: false,
      );

      final arbFile = File('$outputDir/app_en.arb');

      expect(
        arbFile.existsSync(),
        isTrue,
        reason: 'Expected extractor to generate app_en.arb.',
      );

      return jsonDecode(await arbFile.readAsString()) as Map<String, dynamic>;
    }

    List<dynamic> extractedValues(Map<String, dynamic> arbData) {
      return arbData.entries
          .where((entry) => !entry.key.startsWith('@'))
          .map((entry) => entry.value)
          .toList();
    }

    test('ignores Semantics.identifier but keeps visible child text', () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';

Widget buildExample() {
  return Semantics(
    identifier: 'dashboard_attention_title',
    child: const Text('NEEDS ATTENTION'),
  );
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('NEEDS ATTENTION'));
      expect(values, isNot(contains('dashboard_attention_title')));
    });

    test('ignores custom semanticsId named arguments', () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';

Widget buildExample() {
  return InvoiceActionButton(
    semanticsId: 'invoice_section_create_button',
    label: 'CREATE INVOICE',
  );
}

class InvoiceActionButton {
  const InvoiceActionButton({
    required this.semanticsId,
    required this.label,
  });

  final String semanticsId;
  final String label;
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('CREATE INVOICE'));
      expect(values, isNot(contains('invoice_section_create_button')));
    });

    test('ignores all supported Flutter Key string forms', () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';

void buildExample(int i) {
  const Key('plain_key');
  Key('plain_key_interpolated_$i');

  const ValueKey('value_key');
  const ValueKey<String>('typed_value_key');
  ValueKey<String>('typed_value_key_interpolated_$i');

  const PageStorageKey('page_storage_key');
  const PageStorageKey<String>('typed_page_storage_key');
  PageStorageKey<String>('typed_page_storage_key_interpolated_$i');

  const ObjectKey('object_key');
  ObjectKey('object_key_interpolated_$i');

  const GlobalObjectKey('global_object_key');
  const GlobalObjectKey<String>('typed_global_object_key');
  GlobalObjectKey<String>('typed_global_object_key_interpolated_$i');

  GlobalKey(
    debugLabel: 'global_key_debug_label',
  );

  GlobalKey<State>(
    debugLabel: 'typed_global_key_debug_label',
  );

  GlobalKey<State>(
    debugLabel: 'typed_global_key_debug_label_$i',
  );

  GestureDetector(
    key: Key('dashboard_carousel_dot_$i'),
    child: const Text('VISIBLE TEXT'),
  );
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('VISIBLE TEXT'));

      final ignored = [
        'plain_key',
        'plain_key_interpolated_\$i',
        'value_key',
        'typed_value_key',
        'typed_value_key_interpolated_\$i',
        'page_storage_key',
        'typed_page_storage_key',
        'typed_page_storage_key_interpolated_\$i',
        'object_key',
        'object_key_interpolated_\$i',
        'global_object_key',
        'typed_global_object_key',
        'typed_global_object_key_interpolated_\$i',
        'global_key_debug_label',
        'typed_global_key_debug_label',
        'typed_global_key_debug_label_\$i',
        'dashboard_carousel_dot_\$i',
      ];

      for (final value in ignored) {
        expect(
          values,
          isNot(contains(value)),
          reason: 'Expected Flutter Key string "$value" to be ignored.',
        );
      }
    });

    test('ignores strings inside single-line comments', () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';

void buildExample() {
  // const Text('COMMENTED OUT TEXT');
  // static const String routeName = 'commented_route_name';
  // final debugValue = "commented_debug_value";

  const Text('VISIBLE TEXT');
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('VISIBLE TEXT'));
      expect(values, isNot(contains('COMMENTED OUT TEXT')));
      expect(values, isNot(contains('commented_route_name')));
      expect(values, isNot(contains('commented_debug_value')));
    });

    test('ignores strings inside documentation comments', () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';

/// Example usage:
/// Text('DOC COMMENT TEXT')
/// static const String route = 'doc_comment_route';

void buildExample() {
  const Text('VISIBLE TEXT');
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('VISIBLE TEXT'));
      expect(values, isNot(contains('DOC COMMENT TEXT')));
      expect(values, isNot(contains('doc_comment_route')));
    });

    test('ignores strings inside block comments', () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';

/*
const Text('BLOCK COMMENT TEXT');
static const String route = 'block_comment_route';
*/

void buildExample() {
  const Text('VISIBLE TEXT');
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('VISIBLE TEXT'));
      expect(values, isNot(contains('BLOCK COMMENT TEXT')));
      expect(values, isNot(contains('block_comment_route')));
    });

    test('ignores strings inside nested Dart block comments', () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';

/*
  const Text('OUTER BLOCK COMMENT TEXT');

  /*
    const Text('NESTED BLOCK COMMENT TEXT');
    static const String route = 'nested_block_route';
  */

  const Text('OUTER BLOCK COMMENT TEXT 2');
*/

void buildExample() {
  const Text('VISIBLE TEXT');
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('VISIBLE TEXT'));
      expect(values, isNot(contains('OUTER BLOCK COMMENT TEXT')));
      expect(values, isNot(contains('NESTED BLOCK COMMENT TEXT')));
      expect(values, isNot(contains('nested_block_route')));
      expect(values, isNot(contains('OUTER BLOCK COMMENT TEXT 2')));
    });

    test('does not treat comment markers inside strings as comments', () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';

void buildExample() {
  const Text('Use // as a separator');
  const Text('Use /* this */ literally');
  const Text('VISIBLE AFTER COMMENT MARKERS');
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('Use // as a separator'));
      expect(values, contains('Use /* this */ literally'));
      expect(values, contains('VISIBLE AFTER COMMENT MARKERS'));
    });

    test('supports l10n-ignore-next-line for custom programmatic strings',
        () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';

// l10n-ignore-next-line
final String runtimeInternalKey = 'runtimeInternalKey';

// l10n-ignore-next-line
String anotherInternalValue = "anotherInternalValue";

void buildExample() {
  const Text('VISIBLE TEXT');
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('VISIBLE TEXT'));
      expect(values, isNot(contains('runtimeInternalKey')));
      expect(values, isNot(contains('anotherInternalValue')));
    });

    test(
        'l10n-ignore-next-line only applies to the immediately following line',
        () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';

// l10n-ignore-next-line
final String ignoredValue = 'ignored_programmatic_value';

final String userFacingMessage = 'Reusable user-facing message';

void buildExample() {
  const Text('VISIBLE TEXT');
}
''');

      final values = extractedValues(arbData);

      expect(values, isNot(contains('ignored_programmatic_value')));
      expect(values, contains('Reusable user-facing message'));
      expect(values, contains('VISIBLE TEXT'));
    });

    test('ignores static const String declarations by default', () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';

static const String internalFieldKey = 'advancePaymentAmount';
static const String internalPropertyName = 'calendarEventUIObj';
static const String internalStorageKey = 'sourceLineItemId';

void buildExample() {
  const Text('VISIBLE TEXT');
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('VISIBLE TEXT'));
      expect(values, isNot(contains('advancePaymentAmount')));
      expect(values, isNot(contains('calendarEventUIObj')));
      expect(values, isNot(contains('sourceLineItemId')));
    });

    test(
        'l10n-include-next-line includes a user-facing static const String',
        () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';

// l10n-include-next-line
static const String reusableErrorMessage = 'Something went wrong';

// l10n-include-next-line
static const String reusableSuccessMessage = 'Invoice created successfully';

static const String internalFieldKey = 'invoiceUIObj';

void buildExample() {
  const Text('VISIBLE TEXT');
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('Something went wrong'));
      expect(values, contains('Invoice created successfully'));
      expect(values, contains('VISIBLE TEXT'));
      expect(values, isNot(contains('invoiceUIObj')));
    });

    test(
        'l10n-include-next-line only applies to the immediately following static const String',
        () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';

// l10n-include-next-line
static const String includedMessage = 'Included reusable message';

static const String ignoredMessage = 'Ignored static constant';

void buildExample() {
  const Text('VISIBLE TEXT');
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('Included reusable message'));
      expect(values, contains('VISIBLE TEXT'));
      expect(values, isNot(contains('Ignored static constant')));
    });

    test(
        'l10n-ignore-next-line still overrides a static const String declaration',
        () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';

// l10n-ignore-next-line
static const String explicitlyIgnored = 'Explicitly ignored';

void buildExample() {
  const Text('VISIBLE TEXT');
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('VISIBLE TEXT'));
      expect(values, isNot(contains('Explicitly ignored')));
    });

    test('ignores static String values in *_routes.dart files', () async {
      final arbData = await extractFromSource(
        r'''
import 'package:flutter/material.dart';

class AppRoutes {
  static String dashboardPath = '/dashboard';
  static String invoicePath = '/invoices/create';
  static const String customerPath = '/customers';
  static final String settingsPath = '/settings/profile';
}

void buildExample() {
  const Text('VISIBLE ROUTE SCREEN TEXT');
}
''',
        fileName: 'app_routes.dart',
      );

      final values = extractedValues(arbData);

      expect(values, contains('VISIBLE ROUTE SCREEN TEXT'));
      expect(values, isNot(contains('/dashboard')));
      expect(values, isNot(contains('/invoices/create')));
      expect(values, isNot(contains('/customers')));
      expect(values, isNot(contains('/settings/profile')));
    });

    test('route-file rule matches case-insensitively', () async {
      final arbData = await extractFromSource(
        r'''
class AppRoutes {
  static String route = '/internal-route';
}

final String userFacingMessage = 'Visible non-static message';
''',
        fileName: 'APP_ROUTES.DART',
      );

      final values = extractedValues(arbData);

      expect(values, isNot(contains('/internal-route')));
      expect(values, contains('Visible non-static message'));
    });

    test(
        'non-route files do not globally ignore ordinary static String declarations',
        () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';

static String reusableRuntimeMessage = 'Runtime reusable message';

void buildExample() {
  const Text('VISIBLE TEXT');
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('Runtime reusable message'));
      expect(values, contains('VISIBLE TEXT'));
    });

    test(
        'route-file rule does not ignore non-static user-facing String values',
        () async {
      final arbData = await extractFromSource(
        r'''
class AppRoutes {
  static String route = '/internal-route';
}

final String userFacingMessage = 'Visible route screen message';
''',
        fileName: 'billing_routes.dart',
      );

      final values = extractedValues(arbData);

      expect(values, isNot(contains('/internal-route')));
      expect(values, contains('Visible route screen message'));
    });

    test('still ignores import export and part URIs', () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';
export 'src/exported_file.dart';
part 'generated_file.dart';

void buildExample() {
  const Text('VISIBLE TEXT');
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('VISIBLE TEXT'));
      expect(values, isNot(contains('package:flutter/material.dart')));
      expect(values, isNot(contains('src/exported_file.dart')));
      expect(values, isNot(contains('generated_file.dart')));
    });

    test('still ignores MaterialApp and CupertinoApp title values', () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

void buildExample() {
  MaterialApp(
    title: 'INTERNAL MATERIAL APP TITLE',
    home: const Text('MATERIAL VISIBLE TEXT'),
  );

  CupertinoApp(
    title: 'INTERNAL CUPERTINO APP TITLE',
    home: const Text('CUPERTINO VISIBLE TEXT'),
  );
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('MATERIAL VISIBLE TEXT'));
      expect(values, contains('CUPERTINO VISIBLE TEXT'));
      expect(values, isNot(contains('INTERNAL MATERIAL APP TITLE')));
      expect(values, isNot(contains('INTERNAL CUPERTINO APP TITLE')));
    });

    test('keeps interpolated user-facing strings for localization', () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';

void buildExample(dynamic data, int count) {
  Text('${data.invoicedCount} invoices');
  Text('$count selected');
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('{data.invoicedCount} invoices'));
      expect(values, contains('{count} selected'));
    });

    test('handles mixed custom rules in one ordinary Dart file', () async {
      final arbData = await extractFromSource(r'''
import 'package:flutter/material.dart';

static const String internalFieldKey = 'advancePaymentAmount';

// l10n-include-next-line
static const String reusableMessage = 'Payment is required';

// l10n-ignore-next-line
final String runtimeInternalKey = 'runtime_internal_key';

// const Text('OLD COMMENTED TEXT');

/*
  const Text('OLD BLOCK COMMENT TEXT');
*/

Widget buildExample(int i) {
  return Semantics(
    identifier: 'dashboard_card_attention',
    child: Column(
      children: [
        InvoiceActionButton(
          semanticsId: 'invoice_section_create_button',
          label: 'CREATE INVOICE',
        ),
        GestureDetector(
          key: Key('dashboard_carousel_dot_$i'),
          child: const Text('NEEDS ATTENTION'),
        ),
        Text('$i invoices'),
      ],
    ),
  );
}

class InvoiceActionButton extends StatelessWidget {
  const InvoiceActionButton({
    super.key,
    required this.semanticsId,
    required this.label,
  });

  final String semanticsId;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label);
  }
}
''');

      final values = extractedValues(arbData);

      expect(values, contains('Payment is required'));
      expect(values, contains('CREATE INVOICE'));
      expect(values, contains('NEEDS ATTENTION'));
      expect(values, contains('{i} invoices'));

      final ignored = [
        'advancePaymentAmount',
        'runtime_internal_key',
        'OLD COMMENTED TEXT',
        'OLD BLOCK COMMENT TEXT',
        'dashboard_card_attention',
        'invoice_section_create_button',
        'dashboard_carousel_dot_\$i',
      ];

      for (final value in ignored) {
        expect(
          values,
          isNot(contains(value)),
          reason: 'Expected "$value" to be ignored.',
        );
      }
    });

    test('handles route-file and explicit rules together', () async {
      final arbData = await extractFromSource(
        r'''
import 'package:flutter/material.dart';

class InvoiceRoutes {
  static String listPath = '/invoices';
  static const String createPath = '/invoices/create';
  static final String editPath = '/invoices/edit';

  // l10n-ignore-next-line
  final String internalInstanceValue = 'internal_instance_value';

  final String visibleMessage = 'Invoice routes loaded';
}

void buildExample() {
  const Text('INVOICE SCREEN');
}
''',
        fileName: 'invoice_routes.dart',
      );

      final values = extractedValues(arbData);

      expect(values, contains('Invoice routes loaded'));
      expect(values, contains('INVOICE SCREEN'));

      expect(values, isNot(contains('/invoices')));
      expect(values, isNot(contains('/invoices/create')));
      expect(values, isNot(contains('/invoices/edit')));
      expect(values, isNot(contains('internal_instance_value')));
    });
  });
}
