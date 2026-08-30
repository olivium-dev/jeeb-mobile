import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../core/text/digit_normalization.dart';
import '../../l10n/app_localizations.dart';
import '../gateway/dev_gateway_client.dart';

class FundJeeberWalletPage extends StatefulWidget {
  const FundJeeberWalletPage({super.key, required this.jeeber, this.client});

  final DevUser jeeber;
  final DevGatewayClient? client;

  @override
  State<FundJeeberWalletPage> createState() => _FundJeeberWalletPageState();
}

class _FundJeeberWalletPageState extends State<FundJeeberWalletPage> {
  late final DevGatewayClient _client = widget.client ?? DevGatewayClient();
  final TextEditingController _amountController = TextEditingController(
    text: '50',
  );
  final String _operationId = _secureOperationId();
  late final String _partnerPassword = 'Dv1!${_secureOperationId()}';

  DevUser? _partnerUser;
  DevUser? _adminUser;
  bool _running = false;
  double? _lockedAmount;
  _FundingStep _step = _FundingStep.ready;
  String? _error;
  bool _requiresReconciliation = false;
  bool _cleanupRequired = false;
  bool _credentialProvisioned = false;
  _FundingReceipt? _receipt;
  _FundingReceipt? _pendingReceipt;
  DevWalletBalance? _jeeberBefore;
  DevWalletBalance? _partnerBeforeCredit;
  DevWalletBalance? _partnerFunded;
  DevTopupPreview? _preview;
  DevWalletMove? _credit;
  DevWalletMove? _topup;
  _FundingActors? _actors;
  Future<bool>? _cleanupInFlight;

  @override
  void dispose() {
    if (_credentialProvisioned) unawaited(_cleanupCredential());
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fund() async {
    final l10n = AppLocalizations.of(context);
    final amount = _parseAmount(_amountController.text);
    if (amount == null ||
        amount <= 0 ||
        amount > 100000 ||
        !_isCentAmount(amount)) {
      setState(() => _error = l10n.walletFundingInvalidAmount);
      return;
    }
    if (_lockedAmount != null && amount != _lockedAmount) {
      setState(() {
        _error = l10n.walletFundingLockedAmount(
          _money(context, _lockedAmount!),
        );
      });
      return;
    }

    setState(() {
      _running = true;
      _lockedAmount = amount;
      _error = null;
      _requiresReconciliation = false;
      _cleanupRequired = false;
    });

    var requiresReconciliation = false;
    try {
      final actors = await _prepareActors();
      _setStep(_FundingStep.reading);
      _jeeberBefore ??= await _client.readJeeberWallet(
        userId: widget.jeeber.id,
        accessToken: actors.jeeberToken,
      );
      _partnerBeforeCredit ??= await _client.readPartnerWallet(
        accessToken: actors.partner.accessToken,
      );
      _requireCurrencyIdentity(_jeeberBefore!, 'Jeeber balance');
      _requireCurrencyIdentity(_partnerBeforeCredit!, 'partner wallet');

      _setStep(_FundingStep.preview);
      _preview ??= await _client.predictPartnerTopup(
        jeeberId: widget.jeeber.id,
        amount: amount,
        partnerToken: actors.partner.accessToken,
      );

      _setStep(_FundingStep.credit);
      final creditResult = await _client.creditPartner(
        partnerId: actors.partner.partnerId,
        amount: amount,
        adminToken: actors.adminToken,
        idempotencyKey: 'devtool-cash-$_operationId',
      );
      if (_credit case final existingCredit?) {
        _requireSameMove(existingCredit, creditResult, 'cash credit');
      } else {
        _credit = creditResult;
      }
      _requireExecuted(_credit!, amount, 'cash credit');
      _partnerFunded ??= await _client.readPartnerWallet(
        accessToken: actors.partner.accessToken,
      );
      _requireMoney(
        _partnerFunded!.amount - _partnerBeforeCredit!.amount,
        amount,
        'partner cash-credit increase',
      );

      _setStep(_FundingStep.creditReplay);
      final creditReplay = await _client.creditPartner(
        partnerId: actors.partner.partnerId,
        amount: amount,
        adminToken: actors.adminToken,
        idempotencyKey: 'devtool-cash-$_operationId',
      );
      final partnerAfterCreditReplay = await _client.readPartnerWallet(
        accessToken: actors.partner.accessToken,
      );
      _requireSameMove(_credit!, creditReplay, 'cash credit');
      if (_topup == null) {
        _requireSameBalance(
          _partnerFunded!,
          partnerAfterCreditReplay,
          'cash credit',
        );
      }

      final otp = _preview!.otpRequired
          ? await _requestOtp(amount, actors.partner.accessToken)
          : null;

      _setStep(_FundingStep.topup);
      final topupResult = await _client.executePartnerTopup(
        jeeberId: widget.jeeber.id,
        amount: amount,
        partnerToken: actors.partner.accessToken,
        idempotencyKey: 'devtool-topup-$_operationId',
        otp: otp,
      );
      if (_topup case final existingTopup?) {
        _requireSameMove(existingTopup, topupResult, 'Jeeber top-up');
      } else {
        _topup = topupResult;
      }
      final after = await _client.readJeeberWallet(
        userId: widget.jeeber.id,
        accessToken: actors.jeeberToken,
      );
      final partnerAfterTopup = await _client.readPartnerWallet(
        accessToken: actors.partner.accessToken,
      );
      _requireSameCurrency(_jeeberBefore!, after, 'Jeeber balance');
      _requireSameCurrency(
        _partnerFunded!,
        partnerAfterTopup,
        'partner wallet',
      );
      _requireExecuted(_topup!, amount, 'Jeeber top-up');
      _requireMoney(
        _topup!.amount,
        _preview!.grossAmount,
        'executed gross amount',
      );
      _requireMoney(_topup!.fees, _preview!.fees, 'executed fees');
      _requireMoney(
        _topup!.amount - _topup!.fees,
        _preview!.netToJeeber,
        'executed net amount',
      );
      _requireMoney(
        after.amount - _jeeberBefore!.amount,
        _preview!.netToJeeber,
        'Jeeber balance increase',
      );
      _requireMoney(
        _partnerFunded!.amount - partnerAfterTopup.amount,
        amount,
        'partner wallet debit',
      );

      _setStep(_FundingStep.topupReplay);
      final replayOtp = _preview!.otpRequired
          ? await _requestOtp(amount, actors.partner.accessToken)
          : null;
      final topupReplay = await _client.executePartnerTopup(
        jeeberId: widget.jeeber.id,
        amount: amount,
        partnerToken: actors.partner.accessToken,
        idempotencyKey: 'devtool-topup-$_operationId',
        otp: replayOtp,
      );
      final afterReplay = await _client.readJeeberWallet(
        userId: widget.jeeber.id,
        accessToken: actors.jeeberToken,
      );
      final partnerAfterReplayTopup = await _client.readPartnerWallet(
        accessToken: actors.partner.accessToken,
      );
      _requireSameMove(_topup!, topupReplay, 'Jeeber top-up');
      _requireSameBalance(after, afterReplay, 'Jeeber top-up');
      _requireSameBalance(
        partnerAfterTopup,
        partnerAfterReplayTopup,
        'Jeeber top-up',
      );

      _pendingReceipt = _FundingReceipt(
        before: _jeeberBefore!,
        after: after,
        preview: _preview!,
        credit: _credit!,
        topup: _topup!,
      );
      _setStep(_FundingStep.cleaning);
    } on DevGatewayException catch (error) {
      final beforeMoneyMutation =
          _step == _FundingStep.preparing ||
          _step == _FundingStep.reading ||
          _step == _FundingStep.preview;
      requiresReconciliation =
          _credit != null ||
          (!beforeMoneyMutation && error.isUncertainWalletMove);
      if (!mounted) return;
      setState(() {
        if (!requiresReconciliation) {
          _jeeberBefore = null;
          _partnerBeforeCredit = null;
          _preview = null;
        }
        _requiresReconciliation = requiresReconciliation;
        _step = requiresReconciliation
            ? _FundingStep.reconciliation
            : _FundingStep.stopped;
        _error = _localizedError(l10n, error);
      });
    } finally {
      if (_credentialProvisioned) {
        final cleaned = await _cleanupCredential();
        if (cleaned) _publishReceiptAfterCleanup();
      } else if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  String get _partnerIdentifier =>
      'devtool-partner-${_partnerUser!.id.replaceAll('-', '')}';

  Future<_FundingActors> _prepareActors() async {
    if (_actors case final actors?) return actors;
    _setStep(_FundingStep.preparing);
    _partnerUser ??= await _client.seedUser(
      role: 'partner',
      displayName: 'devtool_partner_$_operationId',
    );
    _adminUser ??= await _client.seedUser(
      role: 'admin',
      displayName: 'devtool_admin_$_operationId',
    );
    await _client.ensureJeeberWallet(widget.jeeber.id);
    // Arm cleanup before the mutating request: a lost response can mean the
    // server activated the credential even though this client saw a failure.
    // The holder-bound DELETE is safe when activation never happened.
    _credentialProvisioned = true;
    await _client.provisionPartnerCredential(
      identifier: _partnerIdentifier,
      holderId: _partnerUser!.id,
      displayName: _partnerUser!.username,
      password: _partnerPassword,
    );
    final partner = await _client.loginPartner(
      identifier: _partnerIdentifier,
      password: _partnerPassword,
    );
    final adminToken = await _client.mintTokenForUser(
      _adminUser!.id,
      roles: const <String>['admin'],
    );
    final jeeberToken = await _client.mintTokenForUser(
      widget.jeeber.id,
      roles: const <String>['driver'],
    );
    return _actors = _FundingActors(
      partner: partner,
      adminToken: adminToken,
      jeeberToken: jeeberToken,
    );
  }

  Future<DevPartnerOtp> _requestOtp(double amount, String partnerToken) {
    _setStep(_FundingStep.otp);
    return _client.requestPartnerTopupOtp(
      jeeberId: widget.jeeber.id,
      amount: amount,
      partnerToken: partnerToken,
    );
  }

  Future<bool> _cleanupCredential() {
    if (!_credentialProvisioned) return Future<bool>.value(true);
    if (_cleanupInFlight case final active?) return active;
    late final Future<bool> current;
    current = _performCleanup().whenComplete(() {
      if (identical(_cleanupInFlight, current)) _cleanupInFlight = null;
    });
    return _cleanupInFlight = current;
  }

  Future<bool> _performCleanup() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _client.removePartnerCredential(
          _partnerIdentifier,
          holderId: _partnerUser!.id,
        );
        _credentialProvisioned = false;
        _actors = null;
        _partnerUser = null;
        _adminUser = null;
        if (!mounted) return true;
        setState(() {
          _cleanupRequired = false;
          _running = false;
        });
        return true;
      } on DevGatewayException catch (error) {
        if (error.statusCode == 404) {
          _credentialProvisioned = false;
          _actors = null;
          _partnerUser = null;
          _adminUser = null;
          if (!mounted) return true;
          setState(() {
            _cleanupRequired = false;
            _running = false;
          });
          return true;
        }
        // The server-enforced one-shot credential and five-minute session cap
        // keep this fail-closed while the idempotent DELETE is retried.
      }
    }
    if (!mounted) return false;
    setState(() {
      _cleanupRequired = true;
      _running = false;
    });
    return false;
  }

  Future<void> _retryCleanup() async {
    setState(() => _running = true);
    if (await _cleanupCredential()) _publishReceiptAfterCleanup();
  }

  void _publishReceiptAfterCleanup() {
    if (!mounted || _pendingReceipt == null) return;
    setState(() {
      _receipt = _pendingReceipt;
      _pendingReceipt = null;
      _step = _FundingStep.complete;
    });
  }

  Future<void> _handleBlockedPop<T>(bool didPop, T? result) async {
    if (didPop || _running || !_credentialProvisioned) return;
    setState(() => _running = true);
    final cleaned = await _cleanupCredential();
    if (!mounted || !cleaned) return;
    Navigator.of(context).pop(result);
  }

  void _setStep(_FundingStep value) {
    if (mounted) setState(() => _step = value);
  }

  static void _requireSameMove(
    DevWalletMove first,
    DevWalletMove replay,
    String label,
  ) {
    if (first.transactionId != replay.transactionId ||
        first.status.toLowerCase() != replay.status.toLowerCase()) {
      throw DevGatewayException.walletVerification(
        '$label replay returned different transaction metadata.',
      );
    }
    _requireMoney(replay.amount, first.amount, '$label replay amount');
    _requireMoney(replay.fees, first.fees, '$label replay fees');
  }

  static void _requireSameBalance(
    DevWalletBalance first,
    DevWalletBalance replay,
    String label,
  ) {
    _requireSameCurrency(first, replay, label);
    _requireMoney(replay.amount, first.amount, '$label replay balance');
  }

  static void _requireSameCurrency(
    DevWalletBalance first,
    DevWalletBalance second,
    String label,
  ) {
    final firstCode = first.currency?.trim().toUpperCase();
    final secondCode = second.currency?.trim().toUpperCase();
    if (firstCode?.isNotEmpty == true || secondCode?.isNotEmpty == true) {
      if (firstCode == null ||
          firstCode.isEmpty ||
          secondCode == null ||
          secondCode.isEmpty ||
          firstCode != secondCode) {
        throw DevGatewayException.walletVerification(
          '$label currency changed from ${first.currency ?? 'unknown'} '
          'to ${second.currency ?? 'unknown'}.',
        );
      }
      return;
    }
    if (first.currencyId == null ||
        second.currencyId == null ||
        first.currencyId != second.currencyId) {
      throw DevGatewayException.walletVerification(
        '$label currency identity is missing or changed.',
      );
    }
  }

  static void _requireCurrencyIdentity(DevWalletBalance balance, String label) {
    final currencyId = balance.currencyId;
    if (balance.currency?.trim().isNotEmpty == true ||
        (currencyId != null && currencyId > 0)) {
      return;
    }
    throw DevGatewayException.walletVerification(
      '$label currency identity is missing.',
    );
  }

  static void _requireExecuted(
    DevWalletMove move,
    double expectedAmount,
    String label,
  ) {
    if (move.status.toLowerCase() != 'executed') {
      throw DevGatewayException.walletVerification(
        '$label returned status ${move.status}.',
      );
    }
    _requireMoney(move.amount, expectedAmount, '$label amount');
  }

  static void _requireMoney(double actual, double expected, String label) {
    final actualMinor = _minorUnits(actual);
    final expectedMinor = _minorUnits(expected);
    if (actualMinor == null ||
        expectedMinor == null ||
        actualMinor != expectedMinor) {
      throw DevGatewayException.walletVerification(
        '$label was ${_plainMoney(actual)}, expected ${_plainMoney(expected)}.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = _localizedStep(l10n, _step);
    return PopScope(
      canPop: !_running && !_credentialProvisioned && !_cleanupRequired,
      onPopInvokedWithResult: _handleBlockedPop,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.walletFundingTitle,
          showBackButton: true,
          centerTitle: false,
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: Spacing.large),
          children: [
            _JeeberFundingSummary(jeeber: widget.jeeber),
            _WalletFundingAmountCard(
              controller: _amountController,
              inputEnabled: !_running && _lockedAmount == null,
              running: _running,
              completed: _receipt != null,
              submitEnabled:
                  !_running && _receipt == null && !_requiresReconciliation,
              onSubmit: _fund,
            ),
            _WalletFundingStatusCard(status: status),
            if (_error != null)
              _WalletFundingErrorCard(
                message: _error!,
                reconciliation: _requiresReconciliation,
                operationId: _operationId,
              ),
            if (_cleanupRequired)
              _WalletFundingCleanupCard(
                running: _running,
                onRetry: _retryCleanup,
              ),
            if (_receipt != null && !_cleanupRequired)
              _ReceiptCard(receipt: _receipt!),
          ],
        ),
      ),
    );
  }
}

class _JeeberFundingSummary extends StatelessWidget {
  const _JeeberFundingSummary({required this.jeeber});

  final DevUser jeeber;

  @override
  Widget build(BuildContext context) => OMDSSectionCard(
    title: AppLocalizations.of(context).walletFundingJeeberSection,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(jeeber.username),
        const SizedBox(height: Spacing.xSmall),
        SelectableText(_bidiIsolate(jeeber.id)),
      ],
    ),
  );
}

class _WalletFundingAmountCard extends StatelessWidget {
  const _WalletFundingAmountCard({
    required this.controller,
    required this.inputEnabled,
    required this.running,
    required this.completed,
    required this.submitEnabled,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool inputEnabled;
  final bool running;
  final bool completed;
  final bool submitEnabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => OMDSSectionCard(
    title: AppLocalizations.of(context).walletFundingAmountSection,
    content: _WalletFundingAmountForm(
      controller: controller,
      inputEnabled: inputEnabled,
      running: running,
      completed: completed,
      submitEnabled: submitEnabled,
      onSubmit: onSubmit,
    ),
  );
}

class _WalletFundingAmountForm extends StatelessWidget {
  const _WalletFundingAmountForm({
    required this.controller,
    required this.inputEnabled,
    required this.running,
    required this.completed,
    required this.submitEnabled,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool inputEnabled;
  final bool running;
  final bool completed;
  final bool submitEnabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WalletFundingAmountInput(
          controller: controller,
          enabled: inputEnabled,
        ),
        const SizedBox(height: Spacing.small),
        Text(
          l10n.walletFundingDescription,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: Spacing.medium),
        OmdsLoadingButton(
          identifier: 'devtool.walletFunding.submit',
          text: completed
              ? l10n.walletFundingVerified
              : l10n.walletFundingAddMoney,
          isLoading: running,
          isEnabled: submitEnabled,
          onTap: onSubmit,
        ),
      ],
    );
  }
}

class _WalletFundingAmountInput extends StatelessWidget {
  const _WalletFundingAmountInput({
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) => OmdsTextField(
    controller: controller,
    identifier: 'devtool.walletFunding.amount',
    labelText: AppLocalizations.of(context).walletFundingAmountLabel,
    hintText: '50',
    enabled: enabled,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [
      const ArabicIndicDigitsFormatter(),
      const _LocalizedDecimalFormatter(),
      FilteringTextInputFormatter.allow(RegExp(r'^\d{0,6}([.]\d{0,2})?')),
    ],
  );
}

class _WalletFundingStatusCard extends StatelessWidget {
  const _WalletFundingStatusCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => OMDSSectionCard(
    title: AppLocalizations.of(context).walletFundingStatusSection,
    content: Semantics(
      liveRegion: true,
      container: true,
      child: Text(status, key: const ValueKey('wallet-funding-status')),
    ),
  );
}

class _WalletFundingErrorCard extends StatelessWidget {
  const _WalletFundingErrorCard({
    required this.message,
    required this.reconciliation,
    required this.operationId,
  });

  final String message;
  final bool reconciliation;
  final String operationId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = reconciliation
        ? l10n.walletFundingReconciliationDetail(
            message,
            _bidiIsolate(operationId),
          )
        : l10n.walletFundingErrorDetail(message);
    return OMDSSectionCard(
      title: reconciliation
          ? l10n.walletFundingReconciliation
          : l10n.walletFundingStopped,
      content: Semantics(
        liveRegion: true,
        container: true,
        child: Text(
          detail,
          key: const ValueKey('wallet-funding-error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

class _WalletFundingCleanupCard extends StatelessWidget {
  const _WalletFundingCleanupCard({
    required this.running,
    required this.onRetry,
  });

  final bool running;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OMDSSectionCard(
      title: l10n.walletFundingCleanupRequiredTitle,
      content: Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.walletFundingCleanupRequiredBody),
            const SizedBox(height: Spacing.medium),
            OmdsLoadingButton(
              identifier: 'devtool.walletFunding.cleanup',
              text: l10n.walletFundingCleanupRetry,
              isLoading: running,
              isEnabled: !running,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.receipt});

  final _FundingReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: const ValueKey('wallet-funding-receipt'),
      liveRegion: true,
      container: true,
      child: OMDSSectionCard(
        title: l10n.walletFundingReceiptTitle,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FundingReceiptVerification(),
            const SizedBox(height: Spacing.small),
            _FundingReceiptMoney(receipt: receipt),
            const SizedBox(height: Spacing.small),
            _FundingReceiptTransactions(receipt: receipt),
          ],
        ),
      ),
    );
  }
}

class _FundingReceiptVerification extends StatelessWidget {
  const _FundingReceiptVerification();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.walletFundingReceiptBalance),
        Text(l10n.walletFundingReceiptCreditReplay),
        Text(l10n.walletFundingReceiptTopupReplay),
      ],
    );
  }
}

class _FundingReceiptMoney extends StatelessWidget {
  const _FundingReceiptMoney({required this.receipt});

  final _FundingReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.walletFundingReceiptBefore(
            _moneyWithCurrency(context, receipt.before.amount, receipt.before),
          ),
        ),
        Text(
          l10n.walletFundingReceiptAfter(
            _moneyWithCurrency(context, receipt.after.amount, receipt.after),
          ),
        ),
        Text(
          l10n.walletFundingReceiptGross(
            _money(context, receipt.preview.grossAmount),
          ),
        ),
        Text(
          l10n.walletFundingReceiptFees(_money(context, receipt.preview.fees)),
        ),
        Text(
          l10n.walletFundingReceiptNet(
            _money(context, receipt.preview.netToJeeber),
          ),
        ),
      ],
    );
  }
}

class _FundingReceiptTransactions extends StatelessWidget {
  const _FundingReceiptTransactions({required this.receipt});

  final _FundingReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          l10n.walletFundingReceiptTopupTransaction(
            _bidiIsolate(receipt.topup.transactionId),
          ),
        ),
        SelectableText(
          l10n.walletFundingReceiptCreditTransaction(
            _bidiIsolate(receipt.credit.transactionId),
          ),
        ),
      ],
    );
  }
}

class _FundingReceipt {
  const _FundingReceipt({
    required this.before,
    required this.after,
    required this.preview,
    required this.credit,
    required this.topup,
  });

  final DevWalletBalance before;
  final DevWalletBalance after;
  final DevTopupPreview preview;
  final DevWalletMove credit;
  final DevWalletMove topup;
}

String _moneyWithCurrency(
  BuildContext context,
  double amount,
  DevWalletBalance balance,
) {
  final code = balance.currency?.trim();
  final identity = code?.isNotEmpty == true
      ? code!
      : 'currency-${balance.currencyId ?? 'unknown'}';
  return '${_money(context, amount)} ${_bidiIsolate(identity)}';
}

class _FundingActors {
  const _FundingActors({
    required this.partner,
    required this.adminToken,
    required this.jeeberToken,
  });

  final DevPartnerSession partner;
  final String adminToken;
  final String jeeberToken;
}

enum _FundingStep {
  ready,
  preparing,
  reading,
  credit,
  creditReplay,
  preview,
  otp,
  topup,
  topupReplay,
  cleaning,
  complete,
  reconciliation,
  stopped,
}

String _localizedStep(AppLocalizations l10n, _FundingStep step) =>
    switch (step) {
      _FundingStep.ready => l10n.walletFundingReady,
      _FundingStep.preparing => l10n.walletFundingStepPreparing,
      _FundingStep.reading => l10n.walletFundingStepReading,
      _FundingStep.credit => l10n.walletFundingStepCredit,
      _FundingStep.creditReplay => l10n.walletFundingStepCreditReplay,
      _FundingStep.preview => l10n.walletFundingStepPreview,
      _FundingStep.otp => l10n.walletFundingStepOtp,
      _FundingStep.topup => l10n.walletFundingStepTopup,
      _FundingStep.topupReplay => l10n.walletFundingStepTopupReplay,
      _FundingStep.cleaning => l10n.walletFundingStepCleaning,
      _FundingStep.complete => l10n.walletFundingComplete,
      _FundingStep.reconciliation => l10n.walletFundingReconciliation,
      _FundingStep.stopped => l10n.walletFundingStopped,
    };

class _LocalizedDecimalFormatter extends TextInputFormatter {
  const _LocalizedDecimalFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = newValue.text.replaceAll(RegExp(r'[,٫]'), '.');
    return newValue.copyWith(text: normalized);
  }
}

double? _parseAmount(String input) => double.tryParse(
  normalizeArabicIndicDigits(input.trim()).replaceAll(RegExp(r'[,٫]'), '.'),
);

String _money(BuildContext context, double value) =>
    NumberFormat.decimalPatternDigits(
      locale: Localizations.localeOf(context).toLanguageTag(),
      decimalDigits: 2,
    ).format(value);

String _plainMoney(double value) => value.toStringAsFixed(2);

bool _isCentAmount(double value) => _minorUnits(value) != null;

int? _minorUnits(double value) {
  if (!value.isFinite) return null;
  final scaled = value * 100;
  final rounded = scaled.round();
  return (scaled - rounded).abs() <= 0.0000001 ? rounded : null;
}

String _bidiIsolate(String value) => '\u2068$value\u2069';

String _localizedError(AppLocalizations l10n, DevGatewayException error) {
  final type = error.problemType ?? '';
  if (type.endsWith('/devtool-wallet-verification-failed')) {
    return l10n.walletFundingErrorVerification;
  }
  if (error.isUncertainWalletMove) return l10n.walletFundingErrorUncertain;
  if (type.contains('/otp-')) return l10n.walletFundingErrorOtp;
  return switch (error.statusCode) {
    401 => l10n.walletFundingErrorUnauthorized,
    403 => l10n.walletFundingErrorForbidden,
    404 => l10n.walletFundingErrorDisabled,
    410 => l10n.walletFundingErrorRetired,
    null => l10n.walletFundingErrorUnreachable,
    final status => l10n.walletFundingErrorStatus(status.toString()),
  };
}

String _secureOperationId() {
  final random = Random.secure();
  final entropy = List<int>.generate(12, (_) => random.nextInt(256));
  return entropy.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
