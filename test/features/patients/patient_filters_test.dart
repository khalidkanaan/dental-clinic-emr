import 'package:flutter_test/flutter_test.dart';

import 'package:dental_clinic/features/patients/data/patient.dart';
import 'package:dental_clinic/features/patients/domain/patient_filters.dart';

Patient _patient({
  String? lastVisitDate,
  int? lastVisitOwed = 0,
  bool visitSummaryCurrent = true,
  int credit = 0,
  String status = 'active',
}) =>
    Patient(
      id: 'p1',
      name: 'Sara',
      phoneNumber: '0790000000',
      status: status,
      version: 'v1',
      credit: credit,
      lastVisitDate: lastVisitDate,
      lastVisitOwed: lastVisitOwed,
      visitSummaryCurrent: visitSummaryCurrent,
    );

void main() {
  final today = DateTime(2026, 9, 29);

  group('resolveLastVisit', () {
    test('any time has no bounds', () {
      final r = PatientFilters.none.resolveLastVisit(today);
      expect(r.from, isNull);
      expect(r.to, isNull);
    });

    test('past presets set only a lower bound', () {
      expect(
        const PatientFilters(lastVisit: LastVisitPreset.pastMonth)
            .resolveLastVisit(today)
            .from,
        DateTime(2026, 8, 29),
      );
      expect(
        const PatientFilters(lastVisit: LastVisitPreset.past6Months)
            .resolveLastVisit(today)
            .from,
        DateTime(2026, 3, 29),
      );
    });

    test('"over" presets start the day before the matching "past" preset', () {
      final r = const PatientFilters(lastVisit: LastVisitPreset.over6MonthsAgo)
          .resolveLastVisit(today);
      expect(r.from, isNull);
      expect(r.to, DateTime(2026, 3, 28));
      expect(
        const PatientFilters(lastVisit: LastVisitPreset.over1YearAgo)
            .resolveLastVisit(today)
            .to,
        DateTime(2025, 9, 28),
      );
    });

    test('month subtraction clamps to the end of shorter months', () {
      final r = const PatientFilters(lastVisit: LastVisitPreset.past3Months)
          .resolveLastVisit(DateTime(2026, 5, 31));
      expect(r.from, DateTime(2026, 2, 28));
    });

    test('custom range without both dates is inactive', () {
      final f = PatientFilters(
        lastVisit: LastVisitPreset.custom,
        customFrom: DateTime(2026, 1, 1),
      );
      expect(f.hasLastVisitFilter, isFalse);
      expect(f.activeCount, 0);
    });
  });

  group('toQueryParameters', () {
    test('combines every active filter', () {
      final f = PatientFilters(
        lastVisit: LastVisitPreset.custom,
        customFrom: DateTime(2026, 1, 1),
        customTo: DateTime(2026, 6, 30),
        owesMoney: true,
        hasCredit: true,
        includeArchived: true,
      );
      expect(f.toQueryParameters(today), {
        'lastVisitFrom': '2026-01-01',
        'lastVisitTo': '2026-06-30',
        'owesMoney': 'true',
        'hasCredit': 'true',
        'includeArchived': 'true',
      });
      expect(f.activeCount, 4);
    });

    test('no filters sends nothing', () {
      expect(PatientFilters.none.toQueryParameters(today), isEmpty);
    });
  });

  group('matches', () {
    test('hides archived unless included', () {
      final archived = _patient(status: 'archived');
      expect(PatientFilters.none.matches(archived, today), isFalse);
      expect(
        const PatientFilters(includeArchived: true).matches(archived, today),
        isTrue,
      );
    });

    test('last visit bounds are inclusive and exclude patients with no visits',
        () {
      const f = PatientFilters(lastVisit: LastVisitPreset.pastMonth);
      expect(f.matches(_patient(lastVisitDate: '2026-08-29'), today), isTrue);
      expect(f.matches(_patient(lastVisitDate: '2026-08-28'), today), isFalse);
      expect(f.matches(_patient(), today), isFalse);
    });

    test('balance filters', () {
      expect(
        const PatientFilters(owesMoney: true)
            .matches(_patient(lastVisitOwed: 500), today),
        isTrue,
      );
      expect(
        const PatientFilters(owesMoney: true).matches(_patient(), today),
        isFalse,
      );
      expect(
        const PatientFilters(hasCredit: true)
            .matches(_patient(credit: 100), today),
        isTrue,
      );
    });

    test('owes money follows the last visit only: 0 owed means nothing owed',
        () {
      final paidUp = _patient(lastVisitDate: '2026-09-20', lastVisitOwed: 0);
      expect(
        const PatientFilters(owesMoney: true).matches(paidUp, today),
        isFalse,
      );
    });
  });

  group('unknown visit summary (server still reconciling)', () {
    final unknown = _patient(lastVisitOwed: null, visitSummaryCurrent: false);

    test('never matches owes-money or last-visit filters', () {
      expect(const PatientFilters(owesMoney: true).matches(unknown, today),
          isFalse);
      expect(
        const PatientFilters(lastVisit: LastVisitPreset.over1YearAgo)
            .matches(unknown, today),
        isFalse,
      );
    });

    test('still matches filters that do not depend on visits', () {
      expect(PatientFilters.none.matches(unknown, today), isTrue);
      final withCredit = _patient(
        lastVisitOwed: null,
        visitSummaryCurrent: false,
        credit: 100,
      );
      expect(const PatientFilters(hasCredit: true).matches(withCredit, today),
          isTrue);
    });

    test('fromJson keeps unknown as null, never 0', () {
      final p = Patient.fromJson({
        'id': 'p1',
        'lastVisitDate': null,
        'lastVisitOwed': null,
        'visitSummaryCurrent': false,
      });
      expect(p.lastVisitOwed, isNull);
      expect(p.visitSummaryCurrent, isFalse);

      final known = Patient.fromJson({
        'id': 'p2',
        'lastVisitDate': '2026-09-01',
        'lastVisitOwed': 0,
        'visitSummaryCurrent': true,
      });
      expect(known.lastVisitOwed, 0);
      expect(known.lastVisitDate, '2026-09-01');
    });
  });

  group('custom single day (from == to)', () {
    final day = PatientFilters.none.withLastVisit(
      LastVisitPreset.custom,
      customFrom: DateTime(2026, 9, 29),
      customTo: DateTime(2026, 9, 29),
    );

    test('is an active filter and sends the same date for both bounds', () {
      expect(day.hasLastVisitFilter, isTrue);
      expect(day.toQueryParameters(today), {
        'lastVisitFrom': '2026-09-29',
        'lastVisitTo': '2026-09-29',
      });
    });

    test('matches only a last visit on that exact day', () {
      expect(day.matches(_patient(lastVisitDate: '2026-09-29'), today), isTrue);
      expect(day.matches(_patient(lastVisitDate: '2026-09-28'), today), isFalse);
      expect(day.matches(_patient(lastVisitDate: '2026-09-30'), today), isFalse);
    });

    test('survives saving and reloading', () {
      expect(PatientFilters.fromJson(day.toJson()), day);
    });
  });

  test('custom dates are stored as dates only', () {
    final f = PatientFilters.none.withLastVisit(
      LastVisitPreset.custom,
      customFrom: DateTime(2026, 1, 1, 15, 30),
      customTo: DateTime(2026, 1, 31, 23, 59),
    );
    expect(f.customFrom, DateTime(2026, 1, 1));
    expect(f.customTo, DateTime(2026, 1, 31));
    expect(PatientFilters.fromJson(f.toJson()), f);
  });

  group('persistence', () {
    test('round-trips through JSON', () {
      final f = PatientFilters(
        lastVisit: LastVisitPreset.custom,
        customFrom: DateTime(2026, 1, 1),
        customTo: DateTime(2026, 6, 30),
        owesMoney: true,
      );
      expect(PatientFilters.fromJson(f.toJson()), f);
    });

    test('relative presets are stored by name, not as dates', () {
      final json =
          const PatientFilters(lastVisit: LastVisitPreset.past3Months).toJson();
      expect(json['lastVisit'], 'past3Months');
      expect(json.containsKey('customFrom'), isFalse);
    });

    test('bad stored values fall back to no filter', () {
      final f = PatientFilters.fromJson({
        'lastVisit': 'someFutureOption',
        'customFrom': 'not-a-date',
        'owesMoney': 'yes',
      });
      expect(f, PatientFilters.none);
    });
  });

  test('without() switches off exactly one filter', () {
    const f = PatientFilters(
      lastVisit: LastVisitPreset.pastMonth,
      owesMoney: true,
    );
    final next = f.without(PatientFilterKind.lastVisit);
    expect(next.hasLastVisitFilter, isFalse);
    expect(next.owesMoney, isTrue);
  });
}
