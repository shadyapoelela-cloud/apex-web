import 'package:flutter_test/flutter_test.dart';
import 'package:apex_finance/core/validators_ui.dart';

void main() {
  group('Saudi IBAN', () {
    test('rejects empty', () {
      expect(validateSaudiIban(''), isNotNull);
      expect(validateSaudiIban(null), isNotNull);
    });

    test('rejects wrong country code', () {
      expect(validateSaudiIban('EG1234567890123456789012'), isNotNull);
    });

    test('rejects wrong length', () {
      expect(validateSaudiIban('SA123'), contains('24'));
    });

    test('rejects non-numeric body', () {
      expect(validateSaudiIban('SA12ABCDEF0000000000000000'), isNotNull);
    });

    test('accepts valid IBAN (mod-97 passes)', () {
      // Example real-format Saudi IBAN with passing check digits.
      // Constructed via: SA03 8000 0000 6080 1016 7519
      expect(validateSaudiIban('SA0380000000608010167519'), isNull);
    });

    test('rejects IBAN failing mod-97', () {
      expect(validateSaudiIban('SA0000000000000000000000'), contains('غير صحيح'));
    });

    test('accepts IBAN with spaces', () {
      expect(validateSaudiIban('SA03 8000 0000 6080 1016 7519'), isNull);
    });
  });

  group('Saudi CR', () {
    test('rejects empty', () {
      expect(validateSaudiCR(''), isNotNull);
    });

    test('rejects wrong length', () {
      expect(validateSaudiCR('123'), contains('10'));
    });

    test('rejects non-10 prefix', () {
      expect(validateSaudiCR('2012345678'), contains('10'));
    });

    test('accepts 10-digit 10-prefixed', () {
      expect(validateSaudiCR('1010101010'), isNull);
    });
  });

  group('ZATCA VAT number', () {
    test('rejects wrong length', () {
      expect(validateSaudiVatNumber('3001'), contains('15'));
    });

    test('rejects wrong prefix/suffix', () {
      expect(validateSaudiVatNumber('100000000000003'), contains('3'));
      expect(validateSaudiVatNumber('300000000000000'), contains('3'));
    });

    test('accepts 15-digit 3…3 format', () {
      expect(validateSaudiVatNumber('300000000000003'), isNull);
    });
  });

  group('SAR amount', () {
    test('rejects negative', () {
      expect(validateSarAmount('-10'), contains('سالبة'));
    });

    test('rejects non-numeric', () {
      expect(validateSarAmount('abc'), isNotNull);
    });

    test('rejects more than 2 decimals', () {
      expect(validateSarAmount('10.123'), isNotNull);
    });

    test('accepts with thousands separators', () {
      expect(validateSarAmount('1,234.56'), isNull);
    });

    test('rejects above max', () {
      expect(validateSarAmount('9999999999'), contains('الحد'));
    });

    test('formatSarAmount adds thousand separators', () {
      expect(formatSarAmount(1234567.5), '1,234,567.50');
      expect(formatSarAmount(100), '100.00');
      expect(formatSarAmount(1000), '1,000.00');
    });
  });

  group('Saudi mobile', () {
    test('accepts +966 prefix', () {
      expect(validateSaudiMobile('+966501234567'), isNull);
    });
    test('accepts 0 prefix', () {
      expect(validateSaudiMobile('0501234567'), isNull);
    });
    test('accepts bare 9 digits', () {
      expect(validateSaudiMobile('501234567'), isNull);
    });
    test('rejects wrong first digit', () {
      expect(validateSaudiMobile('0301234567'), isNotNull);
    });
    test('rejects wrong length', () {
      expect(validateSaudiMobile('0501234'), isNotNull);
    });
  });

  group('Email', () {
    test('accepts typical', () {
      expect(validateEmail('user@example.com'), isNull);
    });
    test('rejects missing @', () {
      expect(validateEmail('userexample.com'), isNotNull);
    });
    test('rejects missing domain', () {
      expect(validateEmail('user@'), isNotNull);
    });
  });

  group('IBAN formatter', () {
    test('groups every 4 chars', () {
      expect(formatIban('SA0380000000608010167519'),
          'SA03 8000 0000 6080 1016 7519');
    });

    test('handles already-spaced', () {
      expect(formatIban('SA03 8000 0000 6080 1016 7519'),
          'SA03 8000 0000 6080 1016 7519');
    });
  });
}
