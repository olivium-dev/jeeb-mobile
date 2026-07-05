import 'dev_screen_entry.dart';
import 'groups/auth_first_run_screens.dart';
import 'groups/home_shell_screens.dart';
import 'groups/jeeber_offers_screens.dart';
import 'groups/orders_delivery_screens.dart';
import 'groups/profiles_chat_screens.dart';
import 'groups/requests_flow_screens.dart';
import 'groups/settings_shared_screens.dart';

/// The full dev-tool screen catalog — the flat list every catalog UI reads.
///
/// Each group file under `groups/` exposes a
/// `final List<DevScreenEntry> camelGroupScreens`; this aggregator spreads them
/// all in, in a sensible user-journey order (auth → requests → orders →
/// offers → profiles/chat → settings → home shell).
final List<DevScreenEntry> devScreenCatalog = <DevScreenEntry>[
  ...authFirstRunScreens,
  ...requestsFlowScreens,
  ...ordersDeliveryScreens,
  ...jeeberOffersScreens,
  ...profilesChatScreens,
  ...settingsSharedScreens,
  ...homeShellScreens,
];
