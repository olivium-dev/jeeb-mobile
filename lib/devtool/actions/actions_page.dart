import 'package:flutter/material.dart';

import '../gateway/dev_gateway_client.dart';

class ActionsPage extends StatefulWidget {
  const ActionsPage({super.key});

  @override
  State<ActionsPage> createState() => _ActionsPageState();
}

enum _ActionKind { initiateOffer, acceptOffer, sendMessage }

extension on _ActionKind {
  String get label => switch (this) {
        _ActionKind.initiateOffer => 'Initiate offer',
        _ActionKind.acceptOffer => 'Accept offer',
        _ActionKind.sendMessage => 'Send message',
      };
}

class _ActionsPageState extends State<ActionsPage> {
  final DevGatewayClient _client = DevGatewayClient();

  bool _loadingUsers = true;
  String? _loadError;
  List<DevUser> _users = const <DevUser>[];
  DevUser? _selectedUser;

  _ActionKind _action = _ActionKind.initiateOffer;
  bool _running = false;
  String? _resultMessage;
  bool _resultIsError = false;

  final TextEditingController _requestIdController = TextEditingController();
  final TextEditingController _feeController =
      TextEditingController(text: '5.0');
  final TextEditingController _etaController = TextEditingController(text: '10');
  final TextEditingController _noteController = TextEditingController();

  final TextEditingController _offerIdController = TextEditingController();

  final TextEditingController _chatRequestIdController =
      TextEditingController();
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _requestIdController.dispose();
    _feeController.dispose();
    _etaController.dispose();
    _noteController.dispose();
    _offerIdController.dispose();
    _chatRequestIdController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
      _loadError = null;
    });
    try {
      final users = await _client.listUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _selectedUser = users.isNotEmpty ? users.first : null;
        _loadingUsers = false;
      });
    } on DevGatewayException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loadingUsers = false;
      });
    }
  }

  Future<void> _run() async {
    final user = _selectedUser;
    if (user == null) {
      setState(() {
        _resultMessage = 'Pick a user first.';
        _resultIsError = true;
      });
      return;
    }

    setState(() {
      _running = true;
      _resultMessage = null;
      _resultIsError = false;
    });

    String? detail;
    try {
      switch (_action) {
        case _ActionKind.initiateOffer:
          final requestId = _requestIdController.text.trim();
          final fee = double.tryParse(_feeController.text.trim());
          final eta = int.tryParse(_etaController.text.trim());
          if (requestId.isEmpty || fee == null || eta == null) {
            throw const FormatException(
              'Request ID, fee and ETA (minutes) are required.',
            );
          }
          await _client.initiateOffer(
            asUserId: user.id,
            asRole: user.role,
            requestId: requestId,
            fee: fee,
            etaMinutes: eta,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
        case _ActionKind.acceptOffer:
          final offerId = _offerIdController.text.trim();
          if (offerId.isEmpty) {
            throw const FormatException('Offer ID is required.');
          }
          await _client.acceptOffer(
            asUserId: user.id,
            asRole: user.role,
            offerId: offerId,
          );
        case _ActionKind.sendMessage:
          final requestId = _chatRequestIdController.text.trim();
          final text = _textController.text.trim();
          if (requestId.isEmpty || text.isEmpty) {
            throw const FormatException('Request ID and text are required.');
          }
          final conversationId = await _client.sendMessage(
            asUserId: user.id,
            asRole: user.role,
            requestId: requestId,
            text: text,
          );
          detail = ' Conversation $conversationId.';
      }
      if (!mounted) return;
      setState(() {
        _running = false;
        _resultIsError = false;
        _resultMessage =
            '${_action.label} succeeded as ${user.username.isNotEmpty ? user.username : user.id}.${detail ?? ''}';
      });
    } on DevGatewayException catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _resultIsError = true;
        _resultMessage = e.message;
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _resultIsError = true;
        _resultMessage = e.message;
      });
    }
  }

  String _userLabel(DevUser user) {
    final name = user.displayName ?? user.username;
    final tag = name.isNotEmpty ? name : user.id;
    return user.role != null ? '$tag (${user.role})' : tag;
  }

  Widget _buildUserPicker() {
    if (_loadingUsers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _loadError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _loadUsers, child: const Text('Retry')),
        ],
      );
    }
    if (_users.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('No seeded users yet. Seed one on the Users page first.'),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _loadUsers, child: const Text('Refresh')),
        ],
      );
    }
    return DropdownButtonFormField<DevUser>(
      initialValue: _selectedUser,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Acting user',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final user in _users)
          DropdownMenuItem(value: user, child: Text(_userLabel(user))),
      ],
      onChanged: (user) => setState(() => _selectedUser = user),
    );
  }

  Widget _buildActionFields() {
    switch (_action) {
      case _ActionKind.initiateOffer:
        return Column(
          children: [
            TextField(
              controller: _requestIdController,
              decoration: const InputDecoration(
                labelText: 'Request ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _feeController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Fee',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _etaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ETA (minutes)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );
      case _ActionKind.acceptOffer:
        return TextField(
          controller: _offerIdController,
          decoration: const InputDecoration(
            labelText: 'Offer ID',
            border: OutlineInputBorder(),
          ),
        );
      case _ActionKind.sendMessage:
        return Column(
          children: [
            TextField(
              controller: _chatRequestIdController,
              decoration: const InputDecoration(
                labelText: 'Request ID',
                helperText: 'The conversation is resolved from this '
                    '(correlation key == request id).',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Message text',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Actions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Act as a seeded user', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          _buildUserPicker(),
          const SizedBox(height: 24),
          Text('Action', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<_ActionKind>(
            initialValue: _action,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              for (final kind in _ActionKind.values)
                DropdownMenuItem(value: kind, child: Text(kind.label)),
            ],
            onChanged: (kind) {
              if (kind == null) return;
              setState(() {
                _action = kind;
                _resultMessage = null;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildActionFields(),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _running || _selectedUser == null ? null : _run,
            child: _running
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Run'),
          ),
          if (_resultMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _resultIsError
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _resultMessage!,
                style: TextStyle(
                  color: _resultIsError
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
