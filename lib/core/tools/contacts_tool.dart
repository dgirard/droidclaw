import 'package:flutter_contacts/flutter_contacts.dart';

import 'tool.dart';

/// Tool that searches and reads device contacts (read-only).
class ContactsTool extends Tool {
  static const int _defaultLimit = 10;
  static const int _maxLimit = 50;

  final bool canRequestPermission;

  ContactsTool({this.canRequestPermission = true});

  @override
  String get name => 'contacts';

  @override
  String get description =>
      'Search and read device contacts. Read-only access. '
      'Use to look up phone numbers, emails, or addresses by name. '
      'Only read contacts when the user explicitly asks.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'operation': {
            'type': 'string',
            'enum': ['search', 'get_all'],
            'description':
                'search: find contacts by name/phone/email; '
                    'get_all: list all contacts',
          },
          'query': {
            'type': 'string',
            'description':
                'Search query — name, phone number, or email '
                    '(required for search)',
          },
          'limit': {
            'type': 'integer',
            'description':
                'Max results to return (default: $_defaultLimit, '
                    'max: $_maxLimit)',
          },
        },
        'required': ['operation'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final operation = arguments['operation'] as String?;
    if (operation == null) {
      return ToolResult.error('Missing required parameter: operation');
    }

    try {
      final hasPermission = await FlutterContacts.requestPermission();
      if (!hasPermission) {
        if (!canRequestPermission) {
          return ToolResult.error(
              'Contacts permission not granted. '
              'Please open the app and use the contacts tool once '
              'to grant permission.');
        }
        return ToolResult.error('Contacts permission denied by user.');
      }

      final limit = (arguments['limit'] as int?) ?? _defaultLimit;
      final effectiveLimit = limit.clamp(1, _maxLimit);

      switch (operation) {
        case 'search':
          return await _search(arguments, effectiveLimit);
        case 'get_all':
          return await _getAll(effectiveLimit);
        default:
          return ToolResult.error(
              'Unknown operation: $operation. Use "search" or "get_all".');
      }
    } catch (e) {
      return ToolResult.error('Contacts operation failed: $e');
    }
  }

  Future<ToolResult> _search(
      Map<String, dynamic> arguments, int limit) async {
    final query = arguments['query'] as String?;
    if (query == null || query.isEmpty) {
      return ToolResult.error(
          'Missing required parameter: query (for search)');
    }

    final contacts =
        await FlutterContacts.getContacts(withProperties: true);
    final lowerQuery = query.toLowerCase();
    final digitsQuery = query.replaceAll(RegExp(r'\D'), '');

    final matches = contacts.where((c) {
      if (c.displayName.toLowerCase().contains(lowerQuery)) return true;
      if (digitsQuery.isNotEmpty &&
          c.phones.any((p) => p.number
              .replaceAll(RegExp(r'\D'), '')
              .contains(digitsQuery))) {
        return true;
      }
      if (c.emails
          .any((e) => e.address.toLowerCase().contains(lowerQuery))) {
        return true;
      }
      return false;
    }).take(limit).toList();

    if (matches.isEmpty) {
      return ToolResult.simple('No contacts found matching "$query".');
    }

    final lines = matches.map(_formatContact).join('\n\n');
    return ToolResult.dual(
      forLLM: 'Found ${matches.length} contact(s) for "$query":\n\n$lines',
      forUser: '${matches.length} contact(s) found for "$query"',
    );
  }

  Future<ToolResult> _getAll(int limit) async {
    final contacts =
        await FlutterContacts.getContacts(withProperties: true);
    final limited = contacts.take(limit).toList();

    if (limited.isEmpty) {
      return ToolResult.simple('No contacts on device.');
    }

    final lines = limited.map(_formatContact).join('\n\n');
    return ToolResult.dual(
      forLLM: 'Contacts (${limited.length} of ${contacts.length} total):'
          '\n\n$lines',
      forUser:
          '${limited.length} contact(s) listed (${contacts.length} total)',
    );
  }

  String _formatContact(Contact c) {
    final parts = <String>[c.displayName];
    for (final phone in c.phones) {
      parts.add('  Phone (${phone.label}): ${phone.number}');
    }
    for (final email in c.emails) {
      parts.add('  Email (${email.label}): ${email.address}');
    }
    return parts.join('\n');
  }
}
