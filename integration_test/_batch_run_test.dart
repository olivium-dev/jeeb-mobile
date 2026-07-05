import 'package:integration_test/integration_test.dart';
import 'screens/earnings_dashboard_test.dart' as s0;
import 'screens/escalate_test.dart' as s1;
import 'screens/support_ticket_test.dart' as s2;
import 'screens/dispute_status_test.dart' as s3;
import 'screens/notifications_list_test.dart' as s4;
import 'screens/rating_test.dart' as s5;
import 'screens/mutual_rating_test.dart' as s6;
import 'screens/kyc_rejected_test.dart' as s7;
import 'screens/wallet_hub_test.dart' as s8;
import 'screens/delivery_receipt_test.dart' as s9;
import 'screens/order_summary_test.dart' as s10;
import 'screens/waiting_no_coverage_test.dart' as s11;
import 'screens/settlement_test.dart' as s12;
import 'screens/reviews_list_test.dart' as s13;
import 'screens/kyc_wizard_test.dart' as s14;
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  s0.main(); s1.main(); s2.main(); s3.main(); s4.main(); s5.main(); s6.main(); s7.main();
  s8.main(); s9.main(); s10.main(); s11.main(); s12.main(); s13.main(); s14.main();
}
