const kPasswordMinLength = 6;

String passwordMinLengthHint() => 'At least $kPasswordMinLength characters';

String passwordMinLengthError() =>
    'Use at least $kPasswordMinLength characters';

String? validatePasswordMinLength(String? value) {
  if (value == null || value.isEmpty) {
    return 'Enter a password';
  }
  if (value.length < kPasswordMinLength) {
    return passwordMinLengthError();
  }
  return null;
}
