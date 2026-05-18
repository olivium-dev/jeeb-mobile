import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

class GoodsCostScreen extends StatelessWidget {
  final String deliveryId;
  const GoodsCostScreen({super.key, required this.deliveryId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: OMDSAppBar(title: 'Enter Goods Cost'),
      body: Padding(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How much did the goods cost?',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          'Enter the amount the Client needs to pay for the purchased goods.',
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
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.of(context).pop(double.tryParse(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OmdsTextField(
          controller: _controller,
          labelText: 'Goods Cost (LBP)',
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(Icons.attach_money),
          onChanged: (_) => setState(() {}),
        ),
        const Spacer(),
        OmdsLoadingButton(
          text: 'Confirm Cost',
          isLoading: _isSubmitting,
          isEnabled: _controller.text.isNotEmpty,
          onTap: _submit,
        ),
      ],
    );
  }
}
