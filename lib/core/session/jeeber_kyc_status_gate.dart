import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../features/kyc/domain/kyc_gateway.dart';
import '../../features/kyc/domain/kyc_submission.dart';
import '../dev_seam/dev_seam.dart';
import '../dev_seam/dev_seam_config.dart';



















enum JeeberKycStatus { none, pending, approved, rejected }















enum JeeberDeliveryTabDestination {
  registerPrompt,
  feed,
  kycRejected;

  
  
  
  
  
  
  static JeeberDeliveryTabDestination forStatus(JeeberKycStatus status) =>
      switch (status) {
        
        JeeberKycStatus.none => JeeberDeliveryTabDestination.registerPrompt,
        
        
        JeeberKycStatus.pending => JeeberDeliveryTabDestination.feed,
        
        JeeberKycStatus.approved => JeeberDeliveryTabDestination.feed,
        
        JeeberKycStatus.rejected => JeeberDeliveryTabDestination.kycRejected,
      };
}


abstract class JeeberKycStatusGate {
  
  JeeberKycStatus get status;

  
  
  
  bool get isApproved => status == JeeberKycStatus.approved;
}






















class SeamJeeberKycStatusGate implements JeeberKycStatusGate {
  const SeamJeeberKycStatusGate();

  @override
  JeeberKycStatus get status {
    
    
    
    
    if (!kDebugMode) return JeeberKycStatus.none;
    switch (DevSeam.current.kycStatusSeed) {
      case KycStatusSeed.approved:
        return JeeberKycStatus.approved;
      case KycStatusSeed.pending:
        return JeeberKycStatus.pending;
      case KycStatusSeed.rejected:
        return JeeberKycStatus.rejected;
      case KycStatusSeed.statusNone:
        return JeeberKycStatus.none;
      case KycStatusSeed.none:
        
        
        
        
        
        
        
        
        if (DevSeam.current.homeTab == 'unregistered') {
          return JeeberKycStatus.none;
        }
        return JeeberKycStatus.approved;
    }
  }

  @override
  bool get isApproved => status == JeeberKycStatus.approved;
}
























class LiveJeeberKycStatusGate extends ChangeNotifier
    implements JeeberKycStatusGate {
  
  
  
  
  
  
  
  LiveJeeberKycStatusGate(this._gateway, {bool? useLiveSource})
    : _useLiveSource = useLiveSource ?? !kDebugMode {
    
    
    if (_useLiveSource) unawaited(refresh());
  }

  final KycGateway _gateway;
  final bool _useLiveSource;

  
  JeeberKycStatus? _cached;

  @override
  JeeberKycStatus get status {
    
    
    if (!_useLiveSource) return const SeamJeeberKycStatusGate().status;
    
    
    
    
    return _cached ?? JeeberKycStatus.none;
  }

  @override
  bool get isApproved => status == JeeberKycStatus.approved;

  
  
  
  
  Future<void> refresh() async {
    try {
      final submission = await _gateway.fetchStatus();
      final next = _map(submission.status);
      if (next != _cached) {
        _cached = next;
        notifyListeners();
      }
    } catch (_) {
      
    }
  }

  static JeeberKycStatus _map(KycStatus status) => switch (status) {
    KycStatus.notSubmitted => JeeberKycStatus.none,
    KycStatus.pending => JeeberKycStatus.pending,
    KycStatus.approved => JeeberKycStatus.approved,
    KycStatus.rejected => JeeberKycStatus.rejected,
    
    
    
    
    
    
    
    
    KycStatus.resubmitRequested => JeeberKycStatus.pending,
  };
}







class JeeberKycGateBuilder extends StatelessWidget {
  const JeeberKycGateBuilder({
    super.key,
    required this.gate,
    required this.builder,
  });

  final JeeberKycStatusGate gate;
  final Widget Function(BuildContext context, JeeberKycStatusGate gate) builder;

  @override
  Widget build(BuildContext context) {
    final gate = this.gate;
    if (gate is Listenable) {
      return ListenableBuilder(
        listenable: gate as Listenable,
        builder: (context, _) => builder(context, this.gate),
      );
    }
    return builder(context, gate);
  }
}
