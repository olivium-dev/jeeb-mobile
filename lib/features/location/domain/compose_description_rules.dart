// Mirrors gateway RequestCreateValidation.MinDescriptionLength.
// Change both contracts together; mobile keeps its shorter display cap.
const int kComposeDescriptionMinLength = 5;
const int kComposeDescriptionMaxLength = 280;

String collapseDescription(String raw) =>
    raw.trim().replaceAll(RegExp(r'\s+'), ' ');

bool isDescriptionLongEnough(String raw) =>
    collapseDescription(raw).length >= kComposeDescriptionMinLength;
