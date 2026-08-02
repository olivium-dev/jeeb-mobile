import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goods_cost_cubit.dart';
import '../application/goods_cost_state.dart';
import '../data/dio_goods_cost_repository.dart';
import '../data/fake_goods_cost_repository.dart';
import '../domain/goods_cost.dart';
import '../domain/goods_cost_repository.dart';

class GoodsCostScreen extends StatelessWidget {
  const GoodsCostScreen({
    super.key,
    required this.deliveryId,
    this.repository,
  });

  final String deliveryId;

  final GoodsCostRepository? repository;

  GoodsCostRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<GoodsCostRepository>()) {
      return sl<GoodsCostRepository>();
    }
    if (sl.isRegistered<Dio>()) {
      return DioGoodsCostRepository(sl<Dio>());
    }
    return FakeGoodsCostRepository();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _resolveRepository();
    return BlocProvider<GoodsCostCubit>(
      create: (_) => GoodsCostCubit(
        repository: repo,
        deliveryId: deliveryId,
      )..loadCurrency(),
      child: const _GoodsCostView(),
    );
  }
}

class _GoodsCostView extends StatelessWidget {
  const _GoodsCostView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: OMDSAppBar(title: AppLocalizations.of(context).goodsCostTitle),
      body: const Padding(
        padding: EdgeInsets.all(Spacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(),
            SizedBox(height: Spacing.xLarge),
            Expanded(child: _CostFieldAndSubmit()),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.goodsCostHeadline,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.goodsCostBody,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _CostFieldAndSubmit extends StatefulWidget {
  const _CostFieldAndSubmit();

  @override
  State<_CostFieldAndSubmit> createState() => _CostFieldAndSubmitState();
}

class _CostFieldAndSubmitState extends State<_CostFieldAndSubmit> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_controller.text.trim());
    if (amount == null) return;
    context.read<GoodsCostCubit>().submit(amount);
  }

  String _label(AppLocalizations l10n, String? currency) =>
      (currency != null && currency.isNotEmpty)
          ? l10n.goodsCostFieldLabel(currency)
          : l10n.goodsCostFieldLabelNeutral;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<GoodsCostCubit, GoodsCostState>(
      listenWhen: (prev, next) =>
          prev.submitStatus != next.submitStatus &&
          next.submitStatus == GoodsCostSubmitStatus.succeeded,
      listener: (context, state) {
        final GoodsCost? recorded = state.recorded;
        if (recorded != null) {
          Navigator.of(context).pop(recorded);
        }
      },
      builder: (context, state) {
        final submitting = state.isSubmitting;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OmdsTextField(
              controller: _controller,
              labelText: _label(l10n, state.currency),
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.attach_money),
              enabled: !submitting,
              onChanged: (_) {
                if (state.submitStatus == GoodsCostSubmitStatus.failed) {
                  context.read<GoodsCostCubit>().acknowledgeError();
                } else {
                  setState(() {});
                }
              },
            ),
            if (state.submitStatus == GoodsCostSubmitStatus.failed) ...[
              const SizedBox(height: Spacing.small),
              Text(
                _errorCopy(l10n, state.submitError),
                key: const Key('goods-cost-error'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            const Spacer(),
            OmdsLoadingButton(
              text: l10n.goodsCostSubmit,
              isLoading: submitting,
              isEnabled: _controller.text.trim().isNotEmpty && !submitting,
              onTap: _submit,
            ),
          ],
        );
      },
    );
  }

  static String _errorCopy(AppLocalizations l10n, GoodsCostFailure? failure) {
    switch (failure) {
      case GoodsCostFailure.network:
        return l10n.goodsCostErrorNetwork;
      case GoodsCostFailure.notFound:
        return l10n.goodsCostErrorNotFound;
      case GoodsCostFailure.validation:
        return l10n.goodsCostErrorValidation;
      case GoodsCostFailure.unknown:
      case null:
        return l10n.goodsCostErrorGeneric;
    }
  }
}
