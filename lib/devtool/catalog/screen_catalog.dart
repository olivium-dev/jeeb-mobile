import 'catalog_models.dart';
import 'entries/batch_00_entries.dart';
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
import 'entries/batch_12_entries.dart';
import 'entries/batch_13_entries.dart';

export 'catalog_models.dart';

/// The aggregated screen catalog (DT-04 / F2). Each `batch_NN_entries.dart` file
/// contributes a `List<CatalogEntry>` (authored in parallel, one batch per
/// agent). This registry concatenates them and sorts by feature. Add a new
/// `...batchNNEntries` line here when a batch file lands.
final List<CatalogEntry> kScreenCatalog = <CatalogEntry>[
  ...batch00Entries,
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
  ...batch12Entries,
  ...batch13Entries,
]..sort((a, b) => a.feature.compareTo(b.feature));
