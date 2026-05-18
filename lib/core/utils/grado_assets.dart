class GradoAssets {
  static const String defaultGrade = 'SARGENTO';

  static const List<String> catalog = <String>[
    'SARGENTO',
    'SARGENTO SEGUNDO',
    'SARGENTO PRIMERO',
    'SARGENTO MAYOR',
    'SUBOFICIAL SEGUNDO',
    'SUBOFICIAL PRIMERO',
    'SUBOFICIAL MAYOR',
    'SUBOFICIAL SUPERIOR',
    'SUBTENIENTE',
    'TENIENTE',
    'CAPITAN',
    'MAYOR',
    'TENIENTE CORONEL',
    'CORONEL',
  ];

  static const Map<String, String> _numericToGrade = <String, String>{
    '1': 'SARGENTO',
    '2': 'SARGENTO SEGUNDO',
    '3': 'SARGENTO PRIMERO',
    '4': 'SARGENTO MAYOR',
    '5': 'SUBOFICIAL SEGUNDO',
    '6': 'SUBOFICIAL PRIMERO',
    '7': 'SUBOFICIAL MAYOR',
    '8': 'SUBOFICIAL SUPERIOR',
    '9': 'SUBTENIENTE',
    '10': 'TENIENTE',
    '11': 'CAPITAN',
    '12': 'MAYOR',
    '13': 'TENIENTE CORONEL',
    '14': 'CORONEL',
  };

  static const Map<String, String> _gradeToIcon = <String, String>{
    'SARGENTO': 'sgto.png',
    'SARGENTO SEGUNDO': 'sgtoseg.png',
    'SARGENTO PRIMERO': 'sgtopri.png',
    'SARGENTO MAYOR': 'sgtomy.png',
    'SUBOFICIAL SEGUNDO': 'sofseg.png',
    'SUBOFICIAL PRIMERO': 'sofpri.png',
    'SUBOFICIAL MAYOR': 'sofmy.png',
    'SUBOFICIAL SUPERIOR': 'sofsup.png',
    'SUBTENIENTE': 'subtte.png',
    'TENIENTE': 'tte.png',
    'CAPITAN': 'cap.png',
    'MAYOR': 'my.png',
    'TENIENTE CORONEL': 'ttecnl.png',
    'CORONEL': 'cnl.png',
  };

  static const Map<String, String> _gradeToAbbreviation = <String, String>{
    'SARGENTO': 'sgto.',
    'SARGENTO SEGUNDO': 'sgto.2do',
    'SARGENTO PRIMERO': 'sgto.1ro',
    'SARGENTO MAYOR': 'sgto.my.',
    'SUBOFICIAL SEGUNDO': 'sof.2do',
    'SUBOFICIAL PRIMERO': 'sof.1ro',
    'SUBOFICIAL MAYOR': 'sof.my.',
    'SUBOFICIAL SUPERIOR': 'sof.sup.',
    'SUBTENIENTE': 'subtte.',
    'TENIENTE': 'tte.',
    'CAPITAN': 'cap.',
    'MAYOR': 'My.',
    'TENIENTE CORONEL': 'TCnl.',
    'CORONEL': 'Cnl.',
  };

  static const Map<String, String> _aliasToGrade = <String, String>{
    'SGTO': 'SARGENTO',
    'SGTO2DO': 'SARGENTO SEGUNDO',
    'SGTOSEG': 'SARGENTO SEGUNDO',
    'SGTO1RO': 'SARGENTO PRIMERO',
    'SGTOPRI': 'SARGENTO PRIMERO',
    'SGTOMY': 'SARGENTO MAYOR',
    'SOF2DO': 'SUBOFICIAL SEGUNDO',
    'SOFSEG': 'SUBOFICIAL SEGUNDO',
    'SOF1RO': 'SUBOFICIAL PRIMERO',
    'SOFPRI': 'SUBOFICIAL PRIMERO',
    'SOFMY': 'SUBOFICIAL MAYOR',
    'SOFSUP': 'SUBOFICIAL SUPERIOR',
    'SUBTTE': 'SUBTENIENTE',
    'STTE': 'SUBTENIENTE',
    'TTE': 'TENIENTE',
    'CAP': 'CAPITAN',
    'MY': 'MAYOR',
    'TTCNL': 'TENIENTE CORONEL',
    'TCNL': 'TENIENTE CORONEL',
    'TTECNL': 'TENIENTE CORONEL',
    'CNL': 'CORONEL',
  };

  static String displayName(String? rawGrade) {
    final normalized = _normalize(rawGrade);
    if (normalized.isEmpty) return defaultGrade;

    final asNumber = _numericToGrade[normalized];
    if (asNumber != null) return asNumber;

    if (catalog.contains(normalized)) return normalized;

    final compact = normalized.replaceAll(' ', '');
    final asAlias = _aliasToGrade[compact];
    if (asAlias != null) return asAlias;

    if (normalized == 'SGTO') return 'SARGENTO';
    if (normalized == 'SGTO SEGUNDO' ||
        normalized == 'SGTO 2DO' ||
        normalized == 'SARGENTO 2DO' ||
        normalized == 'SGTO2DO' ||
        normalized == 'SGTOSEG') {
      return 'SARGENTO SEGUNDO';
    }
    if (normalized == 'SGTO PRIMERO' ||
        normalized == 'SGTO 1RO' ||
        normalized == 'SARGENTO 1RO' ||
        normalized == 'SGTO1RO' ||
        normalized == 'SGTOPRI') {
      return 'SARGENTO PRIMERO';
    }
    if (normalized == 'SGTO MAYOR' ||
        normalized == 'SGTO MY' ||
        normalized == 'SGTOMY') {
      return 'SARGENTO MAYOR';
    }
    if (normalized == 'SOF SEGUNDO' ||
        normalized == 'SOF 2DO' ||
        normalized == 'SOF2DO' ||
        normalized == 'SOFSEG') {
      return 'SUBOFICIAL SEGUNDO';
    }
    if (normalized == 'SOF PRIMERO' ||
        normalized == 'SOF 1RO' ||
        normalized == 'SOF1RO' ||
        normalized == 'SOFPRI') {
      return 'SUBOFICIAL PRIMERO';
    }
    if (normalized == 'SOF MAYOR' ||
        normalized == 'SOF MY' ||
        normalized == 'SOFMY') {
      return 'SUBOFICIAL MAYOR';
    }
    if (normalized == 'SOF SUPERIOR' ||
        normalized == 'SOF SUP' ||
        normalized == 'SOFSUP') {
      return 'SUBOFICIAL SUPERIOR';
    }
    if (normalized == 'SUB TTE' ||
        normalized == 'SUBTTE' ||
        normalized == 'SBTTTE') {
      return 'SUBTENIENTE';
    }
    if (normalized == 'TTE') return 'TENIENTE';
    if (normalized == 'CAPITAN' || normalized == 'CAP') return 'CAPITAN';
    if (normalized == 'MY') return 'MAYOR';
    if (normalized == 'TTE CNL' ||
        normalized == 'TTCNL' ||
        normalized == 'TCNL' ||
        normalized == 'TTECNL') {
      return 'TENIENTE CORONEL';
    }
    if (normalized == 'CNL') return 'CORONEL';

    return normalized;
  }

  static String abbreviation(String? rawGrade) {
    final grade = displayName(rawGrade);
    return _gradeToAbbreviation[grade] ?? grade;
  }

  static int hierarchyLevel(String? rawGrade) {
    final grade = displayName(rawGrade);
    final idx = catalog.indexOf(grade);
    return idx >= 0 ? idx + 1 : 1;
  }

  static String iconAsset(String? rawGrade) {
    final grade = displayName(rawGrade);
    final fileName = _gradeToIcon[grade] ?? 'sgto.png';
    return 'assets/icons/$fileName';
  }

  static String _normalize(String? rawGrade) {
    final value = (rawGrade ?? '').trim().toUpperCase();
    return value
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), '');
  }
}
