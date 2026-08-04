import '../../tier_selection/domain/tier.dart';

/// Maps a [TierId] to its EXACT `request_type_<tier>_radio` Semantics
/// identifier per 63_W1_TEST_PLAN §2.2 (JM-024). The blueprint tier ids are the
String requestTypeRadioId(TierId id) => switch (id) {
      TierId.flash => 'request_type_flash_radio',
      TierId.express => 'request_type_express_radio',
      TierId.standard => 'request_type_standard_radio',
      TierId.onTheWay => 'request_type_on_the_way_radio',
      TierId.eco => 'request_type_eco_radio',
    };
