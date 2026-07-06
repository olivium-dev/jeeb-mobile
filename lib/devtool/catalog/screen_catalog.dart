import 'catalog_models.dart';

import 'entries/batch_01_entries.dart';
import 'entries/batch_02_entries.dart';
import 'entries/batch_03_entries.dart';
import 'entries/batch_04_entries.dart';
import 'entries/batch_05_entries.dart';
import 'entries/batch_06_entries.dart';
import 'entries/batch_07_entries.dart';
import 'entries/batch_08_entries.dart';
import 'entries/batch_09_entries.dart';
import 'entries/batch_10_entries.dart';
import 'entries/batch_11_entries.dart';

export 'catalog_models.dart';

/// All cataloged screens, assembled from the per-batch entry files (DT-04 / F2)
/// and sorted by feature for a stable menu order.
final List<CatalogEntry> kScreenCatalog = <CatalogEntry>[
  ...batch01Entries,
  ...batch02Entries,
  ...batch03Entries,
  ...batch04Entries,
  ...batch05Entries,
  ...batch06Entries,
  ...batch07Entries,
  ...batch08Entries,
  ...batch09Entries,
  ...batch10Entries,
  ...batch11Entries,
]..sort((a, b) => a.feature.compareTo(b.feature));
