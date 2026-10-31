// ignore_for_file: unused_import, deprecated_member_use
//
// EPS Assistant DZ — التطبيق كاملاً في ملف واحد (lib/main.dart).
// لا توجد أي استيرادات محلية: كل النماذج والخدمات والـ Providers والشاشات هنا.
//
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

// ==========================================================================
// === CONSTANTS ===
// ==========================================================================

// --- core/constants/db_constants.dart ---
/// أسماء قاعدة البيانات والجداول.
class DbConstants {
  DbConstants._();

  static const String dbName = 'eps_assistant.db';
  static const int dbVersion = 4;

  // الجداول
  static const String tTeachers = 'teachers';
  static const String tClasses = 'classes';
  static const String tStudents = 'students';
  static const String tSessions = 'attendance_sessions';
  static const String tRecords = 'attendance_records';
  static const String tIncidents = 'incidents';

  /// معرّف الأستاذ الافتراضي الذي يُنشأ مع قاعدة البيانات (تطبيق بأستاذ واحد).
  static const int defaultTeacherId = 1;
}

// ==========================================================================
// === THEME ===
// ==========================================================================

// --- core/theme/app_colors.dart ---
/// ألوان التطبيق الثابتة.
class AppColors {
  AppColors._();

  // الأزرق الداكن (الشريط العلوي)
  static const Color navy = Color(0xFF003366);
  static const Color navyDark = Color(0xFF001F3F); // شريط علوي في الوضع الداكن
  static const Color navyLight = Color(0xFF9CC3F0); // لون أساسي في الوضع الداكن

  // ألوان الحالات — الوضع الفاتح
  static const Color presentLight = Color(0xFF2E7D32); // أخضر: حاضر
  static const Color absentLight = Color(0xFFC62828); // أحمر: غائب
  static const Color lateLight = Color(0xFFEF6C00); // برتقالي: متأخر
  static const Color warningLight = Color(0xFFF9A825); // أصفر: تنبيه / بدون بذلة

  // ألوان الحالات — الوضع الداكن (أفتح لتبقى مقروءة)
  static const Color presentDark = Color(0xFF66BB6A);
  static const Color absentDark = Color(0xFFEF5350);
  static const Color lateDark = Color(0xFFFFA726);
  static const Color warningDark = Color(0xFFFFD54F);

  // حالات إضافية للنداء
  static const Color sickLight = Color(0xFF6A1B9A); // بنفسجي: مريض
  static const Color sickDark = Color(0xFFCE93D8);
  static const Color escapedLight = Color(0xFF5D4037); // بني: هروب
  static const Color escapedDark = Color(0xFFBCAAA4);
  static const Color exemptLight = Color(0xFF1565C0); // أزرق: معفى
  static const Color exemptDark = Color(0xFF90CAF9);
  static const Color excusedLight = Color(0xFF00838F); // تركوازي: غياب مبرَّر
  static const Color excusedDark = Color(0xFF4DD0E1);
}

// --- core/theme/app_theme.dart ---
/// ألوان حالات الحضور والتنبيه كـ ThemeExtension (تتغير تلقائياً مع الوضع الفاتح/الداكن).
///
/// الاستعمال: `context.attendanceColors.present`
@immutable
class AttendanceColors extends ThemeExtension<AttendanceColors> {
  const AttendanceColors({
    required this.present,
    required this.absent,
    required this.late,
    required this.warning,
  });

  final Color present; // حاضر
  final Color absent; // غائب
  final Color late; // متأخر
  final Color warning; // تنبيه

  static const light = AttendanceColors(
    present: AppColors.presentLight,
    absent: AppColors.absentLight,
    late: AppColors.lateLight,
    warning: AppColors.warningLight,
  );

  static const dark = AttendanceColors(
    present: AppColors.presentDark,
    absent: AppColors.absentDark,
    late: AppColors.lateDark,
    warning: AppColors.warningDark,
  );

  @override
  AttendanceColors copyWith({
    Color? present,
    Color? absent,
    Color? late,
    Color? warning,
  }) =>
      AttendanceColors(
        present: present ?? this.present,
        absent: absent ?? this.absent,
        late: late ?? this.late,
        warning: warning ?? this.warning,
      );

  @override
  AttendanceColors lerp(ThemeExtension<AttendanceColors>? other, double t) {
    if (other is! AttendanceColors) return this;
    return AttendanceColors(
      present: Color.lerp(present, other.present, t)!,
      absent: Color.lerp(absent, other.absent, t)!,
      late: Color.lerp(late, other.late, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AttendanceColors get attendanceColors =>
      Theme.of(this).extension<AttendanceColors>() ?? AttendanceColors.light;
}

/// السمتان الفاتحة والداكنة.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? AppColors.navyLight : AppColors.navy,
      onPrimary: isDark ? const Color(0xFF00203F) : Colors.white,
      error: isDark ? AppColors.absentDark : AppColors.absentLight,
    );

    final appBarColor = isDark ? AppColors.navyDark : AppColors.navy;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: <ThemeExtension<dynamic>>[
        isDark ? AttendanceColors.dark : AttendanceColors.light,
      ],

      // الشريط العلوي: أزرق داكن #003366 في الوضعين (أغمق قليلاً في الداكن)
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // الشريط السفلي
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        elevation: 8,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ==========================================================================
// === LOCALIZATION (AppStrings) ===
// ==========================================================================

// --- core/l10n/app_strings.dart ---
/// نصوص مؤقتة بثلاث لغات (ar / fr / en) إلى أن نفعّل gen-l10n بملفات .arb.
/// الاستعمال: `AppStrings.of(context).timetable`
class AppStrings {
  AppStrings._(this._code);

  /// نصوص بلغة محدّدة دون الحاجة إلى BuildContext (مثلاً في خدمة PDF).
  factory AppStrings.forCode(String code) => AppStrings._(code);
  final String _code;

  static AppStrings of(BuildContext context) =>
      AppStrings._(Localizations.localeOf(context).languageCode);

  static const _values = <String, Map<String, String>>{
    // التبويبات
    'timetable': {'ar': 'التوقيت', 'fr': 'Emploi du temps', 'en': 'Timetable'},
    'classes': {'ar': 'الأقسام', 'fr': 'Classes', 'en': 'Classes'},
    'lessonPlans': {'ar': 'الجذاذات', 'fr': 'Fiches pédagogiques', 'en': 'Lesson plans'},
    'settings': {'ar': 'الإعدادات', 'fr': 'Paramètres', 'en': 'Settings'},

    // الأقسام
    'addClass': {'ar': 'إضافة قسم', 'fr': 'Ajouter une classe', 'en': 'Add class'},
    'editClass': {'ar': 'تعديل القسم', 'fr': 'Modifier la classe', 'en': 'Edit class'},
    'className': {'ar': 'اسم القسم', 'fr': 'Nom de la classe', 'en': 'Class name'},
    'classNameHint': {'ar': 'مثال: 4م1', 'fr': 'Ex. : 4AM1', 'en': 'e.g. 4M1'},
    'level': {'ar': 'المستوى', 'fr': 'Niveau', 'en': 'Level'},
    'levelHint': {'ar': 'مثال: السنة الرابعة متوسط', 'fr': 'Ex. : 4e année moyenne', 'en': 'e.g. 4th year middle'},
    'cycle': {'ar': 'الطور', 'fr': 'Cycle', 'en': 'Cycle'},
    'primary': {'ar': 'ابتدائي', 'fr': 'Primaire', 'en': 'Primary'},
    'middle': {'ar': 'متوسط', 'fr': 'Moyen', 'en': 'Middle'},
    'secondary': {'ar': 'ثانوي', 'fr': 'Secondaire', 'en': 'Secondary'},
    'manageStudents': {'ar': 'إدارة التلاميذ', 'fr': 'Gérer les élèves', 'en': 'Manage students'},
    'attendance': {'ar': 'النداء', 'fr': 'Appel', 'en': 'Roll call'},
    'comingSoon': {'ar': 'ستتوفر هذه الميزة قريباً', 'fr': 'Bientôt disponible', 'en': 'Coming soon'},
    'noClasses': {'ar': 'لا توجد أقسام بعد', 'fr': 'Aucune classe pour le moment', 'en': 'No classes yet'},
    'noClassesHint': {
      'ar': 'اضغط على زر الإضافة لإنشاء أول قسم',
      'fr': 'Appuyez sur le bouton d\u2019ajout pour créer la première classe',
      'en': 'Tap the add button to create your first class',
    },
    'deleteClassTitle': {'ar': 'حذف القسم', 'fr': 'Supprimer la classe', 'en': 'Delete class'},
    'deleteClassMessage': {
      'ar': 'سيتم حذف القسم «{name}» مع جميع تلاميذه وسجلات الحضور والحوادث المرتبطة به. لا يمكن التراجع.',
      'fr': 'La classe « {name} » sera supprimée avec tous ses élèves, présences et incidents. Action irréversible.',
      'en': 'Class “{name}” will be deleted with all its students, attendance records and incidents. This cannot be undone.',
    },
    'studentCount': {'ar': '{n} تلميذ', 'fr': '{n} élève(s)', 'en': '{n} student(s)'},

    // التلاميذ
    'students': {'ar': 'التلاميذ', 'fr': 'Élèves', 'en': 'Students'},
    'addStudent': {'ar': 'إضافة تلميذ', 'fr': 'Ajouter un élève', 'en': 'Add student'},
    'editStudent': {'ar': 'تعديل التلميذ', 'fr': 'Modifier l\u2019élève', 'en': 'Edit student'},
    'firstName': {'ar': 'الاسم', 'fr': 'Prénom', 'en': 'First name'},
    'lastName': {'ar': 'اللقب', 'fr': 'Nom', 'en': 'Last name'},
    'gender': {'ar': 'الجنس', 'fr': 'Sexe', 'en': 'Gender'},
    'male': {'ar': 'ذكر', 'fr': 'Garçon', 'en': 'Male'},
    'female': {'ar': 'أنثى', 'fr': 'Fille', 'en': 'Female'},
    'noStudents': {'ar': 'لا يوجد تلاميذ في هذا القسم', 'fr': 'Aucun élève dans cette classe', 'en': 'No students in this class'},
    'noStudentsHint': {
      'ar': 'اضغط على زر الإضافة لإضافة أول تلميذ',
      'fr': 'Appuyez sur le bouton d\u2019ajout pour ajouter le premier élève',
      'en': 'Tap the add button to add the first student',
    },
    'deleteStudentTitle': {'ar': 'حذف التلميذ', 'fr': 'Supprimer l\u2019élève', 'en': 'Delete student'},
    'deleteStudentMessage': {
      'ar': 'هل تريد حذف التلميذ «{name}» مع سجلات حضوره وحوادثه؟',
      'fr': 'Supprimer l\u2019élève « {name} » avec ses présences et incidents ?',
      'en': 'Delete student “{name}” with their attendance records and incidents?',
    },

    // النداء
    'present': {'ar': 'حاضر', 'fr': 'Présent', 'en': 'Present'},
    'absent': {'ar': 'غائب', 'fr': 'Absent', 'en': 'Absent'},
    'other': {'ar': 'أخرى', 'fr': 'Autre', 'en': 'Other'},
    'late': {'ar': 'متأخر', 'fr': 'En retard', 'en': 'Late'},
    'noUniform': {'ar': 'بدون بذلة', 'fr': 'Sans tenue', 'en': 'No kit'},
    'sick': {'ar': 'مريض', 'fr': 'Malade', 'en': 'Sick'},
    'escaped': {'ar': 'هروب', 'fr': 'Fugue', 'en': 'Skipped'},
    'exempt': {'ar': 'معفى', 'fr': 'Dispensé', 'en': 'Exempt'},
    'excused': {'ar': 'غياب مبرَّر', 'fr': 'Absence justifiée', 'en': 'Excused'},
    'countPresent': {'ar': 'الحاضرون', 'fr': 'Présents', 'en': 'Present'},
    'countAbsent': {'ar': 'الغائبون', 'fr': 'Absents', 'en': 'Absent'},
    'countTotal': {'ar': 'المجموع', 'fr': 'Total', 'en': 'Total'},
    'setAllPresent': {'ar': 'تعيين الكل حاضر', 'fr': 'Tout le monde présent', 'en': 'Mark all present'},
    'setAllTitle': {'ar': 'تعيين الكل حاضر؟', 'fr': 'Tout marquer présent ?', 'en': 'Mark everyone present?'},
    'setAllMessage': {
      'ar': 'ستُستبدل الحالات المسجَّلة حالياً (غياب، تأخر...) بحالة «حاضر».',
      'fr': 'Les statuts déjà saisis (absence, retard…) seront remplacés par « Présent ».',
      'en': 'Statuses already recorded (absent, late…) will be replaced with “Present”.',
    },
    'confirm': {'ar': 'تأكيد', 'fr': 'Confirmer', 'en': 'Confirm'},
    'date': {'ar': 'التاريخ', 'fr': 'Date', 'en': 'Date'},

    // التقارير (PDF)
    'exportPdf': {'ar': 'تصدير PDF', 'fr': 'Exporter en PDF', 'en': 'Export PDF'},
    'previewPrint': {'ar': 'معاينة وطباعة', 'fr': 'Aperçu et impression', 'en': 'Preview & print'},
    'saveToPhone': {'ar': 'حفظ في الهاتف', 'fr': 'Enregistrer sur le téléphone', 'en': 'Save to phone'},
    'shareFile': {'ar': 'مشاركة الملف', 'fr': 'Partager le fichier', 'en': 'Share file'},
    'preparingPdf': {'ar': 'جارٍ إنشاء الملف…', 'fr': 'Création du fichier…', 'en': 'Creating the file…'},
    'savedTo': {'ar': 'تم الحفظ في:', 'fr': 'Enregistré dans :', 'en': 'Saved to:'},
    'attendanceSheet': {'ar': 'كشف الحضور', 'fr': 'Feuille de présence', 'en': 'Attendance sheet'},
    'institution': {'ar': 'المؤسسة', 'fr': 'Établissement', 'en': 'Institution'},
    'teacherLabel': {'ar': 'الأستاذ(ة)', 'fr': 'Professeur', 'en': 'Teacher'},
    'classLabel': {'ar': 'القسم', 'fr': 'Classe', 'en': 'Class'},
    'indexLabel': {'ar': 'الرقم', 'fr': 'N°', 'en': 'No.'},
    'studentLabel': {'ar': 'التلميذ', 'fr': 'Élève', 'en': 'Student'},
    'statusLabelTitle': {'ar': 'الحالة', 'fr': 'Statut', 'en': 'Status'},
    'notesLabel': {'ar': 'ملاحظات', 'fr': 'Observations', 'en': 'Notes'},
    'teacherSignature': {'ar': 'إمضاء الأستاذ', 'fr': 'Signature du professeur', 'en': 'Teacher signature'},
    'directorVisa': {'ar': 'تأشيرة المدير', 'fr': 'Visa du directeur', 'en': 'Principal visa'},
    'parentSignature': {'ar': 'إمضاء الولي (للاطلاع)', 'fr': 'Signature du parent (pour information)', 'en': 'Parent signature (acknowledgement)'},
    'incidentReport': {'ar': 'تقرير حادث', 'fr': 'Rapport d\u2019incident', 'en': 'Incident report'},
    'studentInfo': {'ar': 'بيانات التلميذ', 'fr': 'Informations sur l\u2019élève', 'en': 'Student information'},
    'incidentDetails': {'ar': 'تفاصيل الحادث', 'fr': 'Détails de l\u2019incident', 'en': 'Incident details'},
    'fullName': {'ar': 'الاسم واللقب', 'fr': 'Nom et prénom', 'en': 'Full name'},
    'birthDate': {'ar': 'تاريخ الميلاد', 'fr': 'Date de naissance', 'en': 'Date of birth'},
    'incidentDate': {'ar': 'تاريخ الحادث', 'fr': 'Date de l\u2019incident', 'en': 'Incident date'},
    'incidentLocation': {'ar': 'مكان الحادث', 'fr': 'Lieu', 'en': 'Location'},
    'injuryNature': {'ar': 'طبيعة الإصابة', 'fr': 'Nature de la blessure', 'en': 'Nature of injury'},
    'severityLabel': {'ar': 'درجة الخطورة', 'fr': 'Gravité', 'en': 'Severity'},
    'minor': {'ar': 'خفيفة', 'fr': 'Légère', 'en': 'Minor'},
    'moderate': {'ar': 'متوسطة', 'fr': 'Modérée', 'en': 'Moderate'},
    'severe': {'ar': 'خطيرة', 'fr': 'Grave', 'en': 'Severe'},
    'incidentDescription': {'ar': 'وصف الحادث', 'fr': 'Description des faits', 'en': 'Description'},
    'firstAid': {'ar': 'الإسعافات المقدَّمة', 'fr': 'Premiers secours donnés', 'en': 'First aid given'},
    'parentNotification': {'ar': 'إشعار الولي', 'fr': 'Information du parent', 'en': 'Parent notification'},
    'parentNotified': {'ar': 'تم إشعار الولي', 'fr': 'Parent informé', 'en': 'Parent notified'},
    'parentNotNotified': {'ar': 'لم يُشعَر الولي بعد', 'fr': 'Parent pas encore informé', 'en': 'Parent not yet notified'},

    // الحوادث
    'incidents': {'ar': 'الحوادث', 'fr': 'Incidents', 'en': 'Incidents'},
    'addIncident': {'ar': 'إضافة حادث', 'fr': 'Ajouter un incident', 'en': 'Add incident'},
    'newIncident': {'ar': 'حادث جديد', 'fr': 'Nouvel incident', 'en': 'New incident'},
    'noIncidents': {'ar': 'لا توجد حوادث مسجَّلة', 'fr': 'Aucun incident enregistré', 'en': 'No incidents recorded'},
    'noIncidentsHint': {
      'ar': 'اضغط على زر الإضافة لتسجيل أول حادث وإنشاء تقريره',
      'fr': 'Appuyez sur le bouton d\u2019ajout pour enregistrer un incident et générer son rapport',
      'en': 'Tap the add button to record an incident and generate its report',
    },
    'needClassFirst': {
      'ar': 'أضف قسماً وتلاميذ أولاً من تبويب الأقسام',
      'fr': 'Ajoutez d\u2019abord une classe et des élèves dans l\u2019onglet Classes',
      'en': 'Add a class and students first from the Classes tab',
    },
    'chooseClass': {'ar': 'اختر القسم', 'fr': 'Choisir la classe', 'en': 'Choose class'},
    'chooseStudent': {'ar': 'اختر التلميذ', 'fr': 'Choisir l\u2019élève', 'en': 'Choose student'},
    'injuredStudent': {'ar': 'التلميذ المصاب', 'fr': 'Élève blessé', 'en': 'Injured student'},
    'dateTime': {'ar': 'التاريخ والوقت', 'fr': 'Date et heure', 'en': 'Date and time'},
    'loc_outdoor': {'ar': 'ملعب خارجي', 'fr': 'Terrain extérieur', 'en': 'Outdoor field'},
    'loc_gym': {'ar': 'قاعة رياضية', 'fr': 'Salle de sport', 'en': 'Gym'},
    'loc_yard': {'ar': 'ساحة المؤسسة', 'fr': 'Cour de l\u2019établissement', 'en': 'Schoolyard'},
    'inj_bruise': {'ar': 'كدمة', 'fr': 'Contusion', 'en': 'Bruise'},
    'inj_sprain': {'ar': 'التواء', 'fr': 'Entorse', 'en': 'Sprain'},
    'inj_fracture': {'ar': 'كسر', 'fr': 'Fracture', 'en': 'Fracture'},
    'inj_cut': {'ar': 'جرح', 'fr': 'Plaie', 'en': 'Cut'},
    'inj_dislocation': {'ar': 'خلع', 'fr': 'Luxation', 'en': 'Dislocation'},
    'inj_strain': {'ar': 'شدّ عضلي', 'fr': 'Élongation', 'en': 'Muscle strain'},
    'inj_head': {'ar': 'ضربة على الرأس', 'fr': 'Coup à la tête', 'en': 'Head injury'},
    'inj_faint': {'ar': 'إغماء / دوخة', 'fr': 'Malaise', 'en': 'Fainting / dizziness'},
    'specify': {'ar': 'يرجى التحديد', 'fr': 'Précisez', 'en': 'Please specify'},
    'firstAidHint': {'ar': 'مثال: كمادات باردة، تضميد، استدعاء الإسعاف…', 'fr': 'Ex. : glace, pansement, appel des secours…', 'en': 'e.g. cold pack, bandage, called ambulance…'},
    'parentNoteHint': {'ar': 'كيف تم إشعاره؟ (مثال: اتصال هاتفي)', 'fr': 'Comment ? (ex. : appel téléphonique)', 'en': 'How? (e.g. phone call)'},
    'optionalHint': {'ar': 'اختياري', 'fr': 'Facultatif', 'en': 'Optional'},
    'saveReport': {'ar': 'حفظ التقرير', 'fr': 'Enregistrer le rapport', 'en': 'Save report'},
    'deleteIncidentTitle': {'ar': 'حذف الحادث', 'fr': 'Supprimer l\u2019incident', 'en': 'Delete incident'},
    'deleteIncidentMessage': {
      'ar': 'سيُحذف سجل حادث التلميذ «{name}». لا يمكن التراجع.',
      'fr': 'L\u2019incident de l\u2019élève « {name} » sera supprimé. Action irréversible.',
      'en': 'The incident record for “{name}” will be deleted. This cannot be undone.',
    },

    // الإعدادات والأمان والنسخ الاحتياطي والترخيص
    'teacherData': {'ar': 'بيانات الأستاذ', 'fr': 'Informations du professeur', 'en': 'Teacher information'},
    'schoolName': {'ar': 'اسم المؤسسة', 'fr': 'Nom de l\u2019établissement', 'en': 'School name'},
    'rank': {'ar': 'الرتبة', 'fr': 'Grade', 'en': 'Rank'},
    'saved': {'ar': 'تم الحفظ', 'fr': 'Enregistré', 'en': 'Saved'},
    'appearance': {'ar': 'المظهر', 'fr': 'Apparence', 'en': 'Appearance'},
    'themeLight': {'ar': 'فاتح', 'fr': 'Clair', 'en': 'Light'},
    'themeDark': {'ar': 'داكن', 'fr': 'Sombre', 'en': 'Dark'},
    'themeSystem': {'ar': 'تلقائي', 'fr': 'Auto', 'en': 'Auto'},
    'language': {'ar': 'اللغة', 'fr': 'Langue', 'en': 'Language'},
    'security': {'ar': 'الأمان', 'fr': 'Sécurité', 'en': 'Security'},
    'pinLock': {'ar': 'قفل التطبيق برمز PIN', 'fr': 'Verrouillage par code PIN', 'en': 'PIN lock'},
    'pinLockSubtitle': {
      'ar': 'يُطلب رمز من 4 أرقام عند فتح التطبيق',
      'fr': 'Un code à 4 chiffres est demandé à l\u2019ouverture',
      'en': 'A 4-digit code is required when opening the app',
    },
    'pinEnter': {'ar': 'أدخل رمز PIN', 'fr': 'Entrez le code PIN', 'en': 'Enter PIN'},
    'pinCreate': {'ar': 'أنشئ رمز PIN جديداً', 'fr': 'Créez un code PIN', 'en': 'Create a new PIN'},
    'pinConfirm': {'ar': 'أعد إدخال الرمز للتأكيد', 'fr': 'Confirmez le code', 'en': 'Re-enter the PIN to confirm'},
    'pinWrong': {'ar': 'رمز غير صحيح', 'fr': 'Code incorrect', 'en': 'Incorrect PIN'},
    'pinMismatch': {'ar': 'الرمزان غير متطابقين، حاول مجدداً', 'fr': 'Les codes ne correspondent pas, réessayez', 'en': 'PINs do not match, try again'},
    'pinTooMany': {'ar': 'محاولات كثيرة. حاول بعد {n} ثانية', 'fr': 'Trop de tentatives. Réessayez dans {n} s', 'en': 'Too many attempts. Try again in {n}s'},
    'pinVerifyToDisable': {
      'ar': 'أدخل الرمز الحالي لإيقاف القفل',
      'fr': 'Entrez le code actuel pour désactiver',
      'en': 'Enter the current PIN to turn off the lock',
    },
    'pinEnabledMsg': {'ar': 'تم تفعيل قفل PIN', 'fr': 'Code PIN activé', 'en': 'PIN lock enabled'},
    'pinDisabledMsg': {'ar': 'تم إيقاف قفل PIN', 'fr': 'Code PIN désactivé', 'en': 'PIN lock disabled'},
    'backupRestore': {'ar': 'النسخ الاحتياطي والاستعادة', 'fr': 'Sauvegarde et restauration', 'en': 'Backup & restore'},
    'backup': {'ar': 'نسخة احتياطية', 'fr': 'Sauvegarde', 'en': 'Backup'},
    'backupSubtitle': {
      'ar': 'حفظ أو مشاركة نسخة من كل بياناتك',
      'fr': 'Enregistrer ou partager une copie de vos données',
      'en': 'Save or share a copy of all your data',
    },
    'restore': {'ar': 'استعادة', 'fr': 'Restaurer', 'en': 'Restore'},
    'restoreSubtitle': {
      'ar': 'استبدال البيانات الحالية بنسخة سابقة',
      'fr': 'Remplacer les données actuelles par une sauvegarde',
      'en': 'Replace current data with a backup',
    },
    'shareBackup': {'ar': 'مشاركة النسخة', 'fr': 'Partager la sauvegarde', 'en': 'Share backup'},
    'restoreConfirmTitle': {'ar': 'استعادة نسخة احتياطية؟', 'fr': 'Restaurer une sauvegarde ?', 'en': 'Restore a backup?'},
    'restoreConfirmMessage': {
      'ar': 'ستُستبدل جميع البيانات الحالية (الأقسام، التلاميذ، الحضور، الحوادث) بمحتوى الملف المختار. لا يمكن التراجع.',
      'fr': 'Toutes les données actuelles (classes, élèves, présences, incidents) seront remplacées par celles du fichier choisi. Action irréversible.',
      'en': 'All current data (classes, students, attendance, incidents) will be replaced with the chosen file. This cannot be undone.',
    },
    'restoreDone': {'ar': 'تمت الاستعادة بنجاح', 'fr': 'Restauration réussie', 'en': 'Restore completed'},
    'restoreInvalid': {
      'ar': 'الملف المختار ليس نسخة احتياطية صالحة',
      'fr': 'Le fichier choisi n\u2019est pas une sauvegarde valide',
      'en': 'The chosen file is not a valid backup',
    },
    'restoreNewer': {
      'ar': 'هذه النسخة أحدث من إصدار التطبيق الحالي',
      'fr': 'Cette sauvegarde est plus récente que la version de l\u2019application',
      'en': 'This backup is newer than the current app version',
    },
    'license': {'ar': 'الترخيص', 'fr': 'Licence', 'en': 'License'},
    'trialPeriod': {'ar': 'الفترة التجريبية: {n} يوماً', 'fr': 'Période d\u2019essai : {n} jours', 'en': 'Trial period: {n} days'},
    'trialRemaining': {'ar': 'المتبقي: {n} يوماً', 'fr': 'Restant : {n} jours', 'en': 'Remaining: {n} days'},
    'trialStarted': {'ar': 'تاريخ أول تشغيل: {date}', 'fr': 'Premier lancement : {date}', 'en': 'First launch: {date}'},
    'trialExpired': {'ar': 'انتهت الفترة التجريبية', 'fr': 'Période d\u2019essai terminée', 'en': 'Trial period ended'},

    // عامة
    'save': {'ar': 'حفظ', 'fr': 'Enregistrer', 'en': 'Save'},
    'cancel': {'ar': 'إلغاء', 'fr': 'Annuler', 'en': 'Cancel'},
    'delete': {'ar': 'حذف', 'fr': 'Supprimer', 'en': 'Delete'},
    'edit': {'ar': 'تعديل', 'fr': 'Modifier', 'en': 'Edit'},
    'retry': {'ar': 'إعادة المحاولة', 'fr': 'Réessayer', 'en': 'Retry'},
    'required': {'ar': 'هذا الحقل مطلوب', 'fr': 'Champ obligatoire', 'en': 'This field is required'},
    'errorGeneric': {'ar': 'حدث خطأ، حاول مرة أخرى', 'fr': 'Une erreur est survenue, réessayez', 'en': 'Something went wrong, please try again'},
  };

  String _t(String key, [Map<String, String> args = const {}]) {
    var v = _values[key]?[_code] ?? _values[key]?['en'] ?? key;
    args.forEach((k, val) => v = v.replaceAll('{$k}', val));
    return v;
  }

  String get appName => 'EPS Assistant DZ';

  String get timetable => _t('timetable');
  String get classes => _t('classes');
  String get lessonPlans => _t('lessonPlans');
  String get settings => _t('settings');

  String get addClass => _t('addClass');
  String get editClass => _t('editClass');
  String get className => _t('className');
  String get classNameHint => _t('classNameHint');
  String get level => _t('level');
  String get levelHint => _t('levelHint');
  String get cycle => _t('cycle');
  String get manageStudents => _t('manageStudents');
  String get attendance => _t('attendance');
  String get comingSoon => _t('comingSoon');
  String get noClasses => _t('noClasses');
  String get noClassesHint => _t('noClassesHint');
  String get deleteClassTitle => _t('deleteClassTitle');
  String deleteClassMessage(String name) => _t('deleteClassMessage', {'name': name});
  String studentCount(int n) => _t('studentCount', {'n': '$n'});

  String get students => _t('students');
  String get addStudent => _t('addStudent');
  String get editStudent => _t('editStudent');
  String get firstName => _t('firstName');
  String get lastName => _t('lastName');
  String get gender => _t('gender');
  String get noStudents => _t('noStudents');
  String get noStudentsHint => _t('noStudentsHint');
  String get deleteStudentTitle => _t('deleteStudentTitle');
  String deleteStudentMessage(String name) => _t('deleteStudentMessage', {'name': name});

  // النداء
  String get other => _t('other');
  String get countPresent => _t('countPresent');
  String get countAbsent => _t('countAbsent');
  String get countTotal => _t('countTotal');
  String get setAllPresent => _t('setAllPresent');
  String get setAllTitle => _t('setAllTitle');
  String get setAllMessage => _t('setAllMessage');
  String get confirm => _t('confirm');
  String get date => _t('date');

  /// [code] = اسم القيمة في enum AttendanceStatus
  /// (present, absent, late, noUniform, sick, escaped, exempt, excused).
  String statusLabel(String code) => _t(code);

  // التقارير (PDF)
  String get exportPdf => _t('exportPdf');
  String get previewPrint => _t('previewPrint');
  String get saveToPhone => _t('saveToPhone');
  String get shareFile => _t('shareFile');
  String get preparingPdf => _t('preparingPdf');
  String get savedTo => _t('savedTo');
  String get attendanceSheet => _t('attendanceSheet');
  String get institution => _t('institution');
  String get teacherLabel => _t('teacherLabel');
  String get classLabel => _t('classLabel');
  String get indexLabel => _t('indexLabel');
  String get studentLabel => _t('studentLabel');
  String get statusTitle => _t('statusLabelTitle');
  String get notesLabel => _t('notesLabel');
  String get teacherSignature => _t('teacherSignature');
  String get directorVisa => _t('directorVisa');
  String get parentSignature => _t('parentSignature');
  String get incidentReport => _t('incidentReport');
  String get studentInfo => _t('studentInfo');
  String get incidentDetails => _t('incidentDetails');
  String get fullName => _t('fullName');
  String get birthDate => _t('birthDate');
  String get incidentDate => _t('incidentDate');
  String get incidentLocation => _t('incidentLocation');
  String get injuryNature => _t('injuryNature');
  String get severityTitle => _t('severityLabel');
  String get incidentDescription => _t('incidentDescription');
  String get firstAid => _t('firstAid');
  String get parentNotification => _t('parentNotification');
  String get parentNotified => _t('parentNotified');
  String get parentNotNotified => _t('parentNotNotified');

  /// [code] = اسم القيمة في enum IncidentSeverity: minor / moderate / severe
  String severityLabel(String code) => _t(code);

  // الحوادث
  String get incidents => _t('incidents');
  String get addIncident => _t('addIncident');
  String get newIncident => _t('newIncident');
  String get noIncidents => _t('noIncidents');
  String get noIncidentsHint => _t('noIncidentsHint');
  String get needClassFirst => _t('needClassFirst');
  String get chooseClass => _t('chooseClass');
  String get chooseStudent => _t('chooseStudent');
  String get injuredStudent => _t('injuredStudent');
  String get dateTime => _t('dateTime');
  String get specify => _t('specify');
  String get firstAidHint => _t('firstAidHint');
  String get parentNoteHint => _t('parentNoteHint');
  String get optionalHint => _t('optionalHint');
  String get saveReport => _t('saveReport');
  String get deleteIncidentTitle => _t('deleteIncidentTitle');
  String deleteIncidentMessage(String name) => _t('deleteIncidentMessage', {'name': name});

  /// طبيعة الإصابة: رمز جاهز (bruise, sprain, fracture, cut, dislocation, strain, head, faint)
  /// أو نص حرّ يُعاد كما هو.
  String injuryLabel(String value) =>
      _values['inj_$value'] != null ? _t('inj_$value') : value;

  /// المكان: رمز جاهز (outdoor, gym, yard) أو نص حرّ يُعاد كما هو.
  String placeLabel(String value) =>
      _values['loc_$value'] != null ? _t('loc_$value') : value;

  // الإعدادات والأمان
  String get teacherData => _t('teacherData');
  String get schoolName => _t('schoolName');
  String get rank => _t('rank');
  String get saved => _t('saved');
  String get appearance => _t('appearance');
  String get themeLight => _t('themeLight');
  String get themeDark => _t('themeDark');
  String get themeSystem => _t('themeSystem');
  String get language => _t('language');
  String get security => _t('security');
  String get pinLock => _t('pinLock');
  String get pinLockSubtitle => _t('pinLockSubtitle');
  String get pinEnter => _t('pinEnter');
  String get pinCreate => _t('pinCreate');
  String get pinConfirm => _t('pinConfirm');
  String get pinWrong => _t('pinWrong');
  String get pinMismatch => _t('pinMismatch');
  String pinTooMany(int seconds) => _t('pinTooMany', {'n': '$seconds'});
  String get pinVerifyToDisable => _t('pinVerifyToDisable');
  String get pinEnabledMsg => _t('pinEnabledMsg');
  String get pinDisabledMsg => _t('pinDisabledMsg');
  String get backupRestore => _t('backupRestore');
  String get backup => _t('backup');
  String get backupSubtitle => _t('backupSubtitle');
  String get restore => _t('restore');
  String get restoreSubtitle => _t('restoreSubtitle');
  String get shareBackup => _t('shareBackup');
  String get restoreConfirmTitle => _t('restoreConfirmTitle');
  String get restoreConfirmMessage => _t('restoreConfirmMessage');
  String get restoreDone => _t('restoreDone');
  String get restoreInvalid => _t('restoreInvalid');
  String get restoreNewer => _t('restoreNewer');
  String get license => _t('license');
  String trialPeriod(int days) => _t('trialPeriod', {'n': '$days'});
  String trialRemaining(int days) => _t('trialRemaining', {'n': '$days'});
  String trialStarted(String date) => _t('trialStarted', {'date': date});
  String get trialExpired => _t('trialExpired');

  String get save => _t('save');
  String get cancel => _t('cancel');
  String get delete => _t('delete');
  String get edit => _t('edit');
  String get retry => _t('retry');
  String get required => _t('required');
  String get errorGeneric => _t('errorGeneric');

  /// [code] = اسم القيمة في enum Cycle: primary / middle / secondary
  String cycleLabel(String code) => _t(code);

  /// [code] = اسم القيمة في enum Gender: male / female
  String genderLabel(String code) => _t(code);
}

// ==========================================================================
// === MODELS ===
// ==========================================================================

// --- features/settings/data/models/teacher_model.dart ---
/// الطور التعليمي.
enum Cycle {
  primary,
  middle,
  secondary;

  static Cycle fromValue(String? v) =>
      Cycle.values.firstWhere((e) => e.name == v, orElse: () => Cycle.middle);
}

class TeacherModel extends Equatable {
  final int? id;
  final String firstName; // الاسم
  final String lastName; // اللقب
  final String schoolName; // اسم المؤسسة
  final String rank; // الرتبة
  final String? wilaya;
  final Cycle cycle;
  final String? phone;
  final String? email;
  final DateTime createdAt;

  const TeacherModel({
    this.id,
    this.firstName = '',
    this.lastName = '',
    this.schoolName = '',
    this.rank = '',
    this.wilaya,
    this.cycle = Cycle.middle,
    this.phone,
    this.email,
    required this.createdAt,
  });

  /// «اللقب الاسم».
  String get fullName =>
      [lastName.trim(), firstName.trim()].where((e) => e.isNotEmpty).join(' ');

  /// الاسم الكامل مع الرتبة (للتقارير).
  String get displayName {
    final r = rank.trim();
    if (r.isEmpty) return fullName;
    return fullName.isEmpty ? r : '$fullName ($r)';
  }

  factory TeacherModel.fromMap(Map<String, Object?> map) => TeacherModel(
        id: map['id'] as int?,
        // صفوف النسخ القديمة: الاسم كان في full_name فقط.
        firstName: (map['first_name'] as String?) ??
            (map['full_name'] as String?) ??
            '',
        lastName: (map['last_name'] as String?) ?? '',
        schoolName: (map['school_name'] as String?) ?? '',
        rank: (map['rank'] as String?) ?? '',
        wilaya: map['wilaya'] as String?,
        cycle: Cycle.fromValue(map['cycle'] as String?),
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'full_name': fullName,
        'first_name': firstName,
        'last_name': lastName,
        'school_name': schoolName,
        'rank': rank,
        'wilaya': wilaya,
        'cycle': cycle.name,
        'phone': phone,
        'email': email,
        'created_at': createdAt.toIso8601String(),
      };

  TeacherModel copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? schoolName,
    String? rank,
    String? wilaya,
    Cycle? cycle,
    String? phone,
    String? email,
  }) =>
      TeacherModel(
        id: id ?? this.id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        schoolName: schoolName ?? this.schoolName,
        rank: rank ?? this.rank,
        wilaya: wilaya ?? this.wilaya,
        cycle: cycle ?? this.cycle,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
        id, firstName, lastName, schoolName, rank, wilaya, cycle, phone, email,
        createdAt
      ];
}

// --- features/classes/data/models/class_model.dart ---
class ClassModel extends Equatable {
  final int? id;
  final int teacherId;
  final String name; // مثال: 4م1 / 2AS-3
  final String? level; // مثال: السنة الرابعة متوسط
  final Cycle cycle;
  final String? schoolYear; // مثال: 2026/2027
  final DateTime createdAt;

  /// للعرض فقط (يُحسب بـ JOIN ولا يُخزَّن في الجدول).
  final int? studentCount;

  const ClassModel({
    this.id,
    this.teacherId = DbConstants.defaultTeacherId,
    required this.name,
    this.level,
    this.cycle = Cycle.middle,
    this.schoolYear,
    required this.createdAt,
    this.studentCount,
  });

  factory ClassModel.fromMap(Map<String, Object?> map) => ClassModel(
        id: map['id'] as int?,
        teacherId: map['teacher_id'] as int,
        name: map['name'] as String,
        level: map['level'] as String?,
        cycle: Cycle.fromValue(map['cycle'] as String?),
        schoolYear: map['school_year'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        studentCount: map['student_count'] as int?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'teacher_id': teacherId,
        'name': name,
        'level': level,
        'cycle': cycle.name,
        'school_year': schoolYear,
        'created_at': createdAt.toIso8601String(),
      };

  ClassModel copyWith({
    int? id,
    int? teacherId,
    String? name,
    String? level,
    Cycle? cycle,
    String? schoolYear,
  }) =>
      ClassModel(
        id: id ?? this.id,
        teacherId: teacherId ?? this.teacherId,
        name: name ?? this.name,
        level: level ?? this.level,
        cycle: cycle ?? this.cycle,
        schoolYear: schoolYear ?? this.schoolYear,
        createdAt: createdAt,
        studentCount: studentCount,
      );

  @override
  List<Object?> get props =>
      [id, teacherId, name, level, cycle, schoolYear, createdAt, studentCount];
}

// --- features/classes/data/models/student_model.dart ---
enum Gender {
  male,
  female;

  static Gender fromValue(String? v) =>
      Gender.values.firstWhere((e) => e.name == v, orElse: () => Gender.male);
}

class StudentModel extends Equatable {
  final int? id;
  final int classId;
  final String firstName;
  final String lastName;
  final Gender gender;
  final DateTime? birthDate;
  final bool isExempt; // معفى من الحصة (شهادة طبية مثلاً)
  final String? notes;
  final DateTime createdAt;

  const StudentModel({
    this.id,
    required this.classId,
    required this.firstName,
    required this.lastName,
    this.gender = Gender.male,
    this.birthDate,
    this.isExempt = false,
    this.notes,
    required this.createdAt,
  });

  String get fullName => '$lastName $firstName';

  factory StudentModel.fromMap(Map<String, Object?> map) => StudentModel(
        id: map['id'] as int?,
        classId: map['class_id'] as int,
        firstName: map['first_name'] as String,
        lastName: map['last_name'] as String,
        gender: Gender.fromValue(map['gender'] as String?),
        birthDate: map['birth_date'] == null
            ? null
            : DateTime.parse(map['birth_date'] as String),
        isExempt: (map['is_exempt'] as int? ?? 0) == 1,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'class_id': classId,
        'first_name': firstName,
        'last_name': lastName,
        'gender': gender.name,
        'birth_date': birthDate?.toIso8601String(),
        'is_exempt': isExempt ? 1 : 0,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  StudentModel copyWith({
    int? id,
    int? classId,
    String? firstName,
    String? lastName,
    Gender? gender,
    DateTime? birthDate,
    bool? isExempt,
    String? notes,
  }) =>
      StudentModel(
        id: id ?? this.id,
        classId: classId ?? this.classId,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        gender: gender ?? this.gender,
        birthDate: birthDate ?? this.birthDate,
        isExempt: isExempt ?? this.isExempt,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
        id, classId, firstName, lastName, gender, birthDate, isExempt, notes, createdAt
      ];
}

// --- features/classes/data/models/attendance_session_model.dart ---
/// حصة دراسية لقسم معيّن في تاريخ معيّن.
class AttendanceSessionModel extends Equatable {
  final int? id;
  final int classId;
  final DateTime sessionDate;
  final String? startTime; // "08:00"
  final String? endTime; // "09:00"
  final String? topic;
  final String? notes;
  final DateTime createdAt;

  const AttendanceSessionModel({
    this.id,
    required this.classId,
    required this.sessionDate,
    this.startTime,
    this.endTime,
    this.topic,
    this.notes,
    required this.createdAt,
  });

  factory AttendanceSessionModel.fromMap(Map<String, Object?> map) =>
      AttendanceSessionModel(
        id: map['id'] as int?,
        classId: map['class_id'] as int,
        sessionDate: DateTime.parse(map['session_date'] as String),
        startTime: map['start_time'] as String?,
        endTime: map['end_time'] as String?,
        topic: map['topic'] as String?,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'class_id': classId,
        'session_date': sessionDate.toIso8601String(),
        'start_time': startTime,
        'end_time': endTime,
        'topic': topic,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  AttendanceSessionModel copyWith({
    int? id,
    int? classId,
    DateTime? sessionDate,
    String? startTime,
    String? endTime,
    String? topic,
    String? notes,
  }) =>
      AttendanceSessionModel(
        id: id ?? this.id,
        classId: classId ?? this.classId,
        sessionDate: sessionDate ?? this.sessionDate,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        topic: topic ?? this.topic,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props =>
      [id, classId, sessionDate, startTime, endTime, topic, notes, createdAt];
}

// --- features/classes/data/models/attendance_record_model.dart ---
/// حالات الحضور. القيمة المخزّنة في SQLite هي [name] (مطابقة لقيد CHECK).
enum AttendanceStatus {
  present, // حاضر
  absent, // غائب
  late, // متأخر
  noUniform, // بدون بذلة
  sick, // مريض
  escaped, // هروب
  exempt, // معفى
  excused; // غياب مبرَّر

  static AttendanceStatus fromValue(String? v) => AttendanceStatus.values
      .firstWhere((e) => e.name == v, orElse: () => AttendanceStatus.present);

  /// الحالات التي تظهر في قائمة «أخرى».
  static List<AttendanceStatus> get others => values
      .where((s) => s != AttendanceStatus.present && s != AttendanceStatus.absent)
      .toList();
}

/// سجل حضور/غياب تلميذ في حصة. الثنائية (session_id, student_id) فريدة.
class AttendanceRecordModel extends Equatable {
  final int? id;
  final int sessionId;
  final int studentId;
  final AttendanceStatus status;
  final String? note;

  const AttendanceRecordModel({
    this.id,
    required this.sessionId,
    required this.studentId,
    this.status = AttendanceStatus.present,
    this.note,
  });

  factory AttendanceRecordModel.fromMap(Map<String, Object?> map) =>
      AttendanceRecordModel(
        id: map['id'] as int?,
        sessionId: map['session_id'] as int,
        studentId: map['student_id'] as int,
        status: AttendanceStatus.fromValue(map['status'] as String?),
        note: map['note'] as String?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'session_id': sessionId,
        'student_id': studentId,
        'status': status.name,
        'note': note,
      };

  AttendanceRecordModel copyWith({
    int? id,
    int? sessionId,
    int? studentId,
    AttendanceStatus? status,
    String? note,
  }) =>
      AttendanceRecordModel(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        studentId: studentId ?? this.studentId,
        status: status ?? this.status,
        note: note ?? this.note,
      );

  @override
  List<Object?> get props => [id, sessionId, studentId, status, note];
}

// --- features/incidents/data/models/incident_model.dart ---
enum IncidentSeverity {
  minor,
  moderate,
  severe;

  static IncidentSeverity fromValue(String? v) => IncidentSeverity.values
      .firstWhere((e) => e.name == v, orElse: () => IncidentSeverity.minor);
}

/// حادثة (إصابة، سلوك...) مرتبطة بتلميذ، وتُصدَّر كتقرير PDF.
///
/// - [type]: طبيعة الإصابة/الحادث (مثال: التواء في الكاحل)
/// - [actionTaken]: الإسعافات المقدَّمة
/// - [parentNotified] / [parentNotificationNote]: إشعار الولي وكيفيته
class IncidentModel extends Equatable {
  final int? id;
  final int studentId;
  final int classId;
  final int? sessionId; // يصبح NULL إذا حُذفت الحصة
  final DateTime incidentDate;
  final String type;
  final IncidentSeverity severity;
  final String? location;
  final String description;
  final String? actionTaken;
  final bool parentNotified;
  final String? parentNotificationNote;
  final String? pdfPath;
  final DateTime createdAt;

  const IncidentModel({
    this.id,
    required this.studentId,
    required this.classId,
    this.sessionId,
    required this.incidentDate,
    required this.type,
    this.severity = IncidentSeverity.minor,
    this.location,
    required this.description,
    this.actionTaken,
    this.parentNotified = false,
    this.parentNotificationNote,
    this.pdfPath,
    required this.createdAt,
  });

  factory IncidentModel.fromMap(Map<String, Object?> map) => IncidentModel(
        id: map['id'] as int?,
        studentId: map['student_id'] as int,
        classId: map['class_id'] as int,
        sessionId: map['session_id'] as int?,
        incidentDate: DateTime.parse(map['incident_date'] as String),
        type: map['type'] as String,
        severity: IncidentSeverity.fromValue(map['severity'] as String?),
        location: map['location'] as String?,
        description: map['description'] as String,
        actionTaken: map['action_taken'] as String?,
        parentNotified: (map['parent_notified'] as int? ?? 0) == 1,
        parentNotificationNote: map['parent_notification_note'] as String?,
        pdfPath: map['pdf_path'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'student_id': studentId,
        'class_id': classId,
        'session_id': sessionId,
        'incident_date': incidentDate.toIso8601String(),
        'type': type,
        'severity': severity.name,
        'location': location,
        'description': description,
        'action_taken': actionTaken,
        'parent_notified': parentNotified ? 1 : 0,
        'parent_notification_note': parentNotificationNote,
        'pdf_path': pdfPath,
        'created_at': createdAt.toIso8601String(),
      };

  IncidentModel copyWith({
    int? id,
    int? studentId,
    int? classId,
    int? sessionId,
    DateTime? incidentDate,
    String? type,
    IncidentSeverity? severity,
    String? location,
    String? description,
    String? actionTaken,
    bool? parentNotified,
    String? parentNotificationNote,
    String? pdfPath,
  }) =>
      IncidentModel(
        id: id ?? this.id,
        studentId: studentId ?? this.studentId,
        classId: classId ?? this.classId,
        sessionId: sessionId ?? this.sessionId,
        incidentDate: incidentDate ?? this.incidentDate,
        type: type ?? this.type,
        severity: severity ?? this.severity,
        location: location ?? this.location,
        description: description ?? this.description,
        actionTaken: actionTaken ?? this.actionTaken,
        parentNotified: parentNotified ?? this.parentNotified,
        parentNotificationNote:
            parentNotificationNote ?? this.parentNotificationNote,
        pdfPath: pdfPath ?? this.pdfPath,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
        id, studentId, classId, sessionId, incidentDate, type, severity,
        location, description, actionTaken, parentNotified,
        parentNotificationNote, pdfPath, createdAt
      ];
}

// --- features/incidents/data/models/incident_list_item.dart ---
/// حادثة مع اسم التلميذ والقسم (نتيجة JOIN) لعرضها في القائمة.
class IncidentListItem {
  const IncidentListItem({
    required this.incident,
    required this.studentName,
    required this.className,
  });

  final IncidentModel incident;
  final String studentName;
  final String className;
}

// --- features/reports/data/services/report_data.dart ---
/// بيانات «كشف الحضور». [languageCode]: ar / fr / en (العربية تُطبع RTL).
class AttendanceSheetData {
  const AttendanceSheetData({
    required this.languageCode,
    required this.schoolName,
    required this.teacherName,
    required this.classModel,
    required this.date,
    required this.students,
    required this.statuses,
  });

  final String languageCode;
  final String schoolName;
  final String teacherName;
  final ClassModel classModel;
  final DateTime date;
  final List<StudentModel> students;

  /// studentId ← الحالة. غير الموجود = لم يُنادَ عليه.
  final Map<int, AttendanceStatus> statuses;
}

/// بيانات «تقرير حادث».
class IncidentReportData {
  const IncidentReportData({
    required this.languageCode,
    required this.schoolName,
    required this.teacherName,
    required this.className,
    required this.student,
    required this.incident,
  });

  final String languageCode;
  final String schoolName;
  final String teacherName;
  final String className;
  final StudentModel student;
  final IncidentModel incident;
}

// ==========================================================================
// === DATABASE ===
// ==========================================================================

// --- core/database/database_helper.dart ---
/// مساعد قاعدة البيانات (Singleton) — يفتح sqflite وينشئ الجداول ويفعّل المفاتيح الأجنبية.
///
/// علاقات الحذف المتسلسل (ON DELETE CASCADE):
///   teachers ─► classes ─► students ─► attendance_records / incidents
///                      └─► attendance_sessions ─► attendance_records
///   حذف حصة (session) لا يحذف الحادثة المرتبطة بها: تصبح session_id = NULL.
class DatabaseHelper {
  /// [path] اختياري: مرّر `inMemoryDatabasePath` في الاختبارات.
  DatabaseHelper({String? path}) : _customPath = path;

  /// النسخة المستعملة في التطبيق.
  static final DatabaseHelper instance = DatabaseHelper();

  final String? _customPath;
  Future<Database>? _opening;

  Future<Database> get database => _opening ??= _open();

  /// مسار الملف الفعلي (مفيد للنسخ الاحتياطي لاحقاً).
  Future<String> get databasePath async =>
      _customPath ?? p.join(await getDatabasesPath(), DbConstants.dbName);

  Future<Database> _open() async {
    final path = await databasePath;
    return openDatabase(
      path,
      version: DbConstants.dbVersion,
      onConfigure: (db) async {
        // ضروري: SQLite يعطّل المفاتيح الأجنبية افتراضياً.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// جدول سجلات الحضور (نسخة 2: حالات جديدة — بدون بذلة، مريض، هروب، معفى).
  static const String _createRecordsSql = '''
      CREATE TABLE ${DbConstants.tRecords} (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        status     TEXT    NOT NULL DEFAULT 'present'
                   CHECK (status IN ('present','absent','late','noUniform',
                                     'sick','escaped','exempt','excused')),
        note       TEXT,
        UNIQUE (session_id, student_id),
        FOREIGN KEY (session_id) REFERENCES ${DbConstants.tSessions}(id)
          ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (student_id) REFERENCES ${DbConstants.tStudents}(id)
          ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''';

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE ${DbConstants.tTeachers} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name   TEXT    NOT NULL DEFAULT '',
        first_name  TEXT,
        last_name   TEXT,
        rank        TEXT,
        school_name TEXT    NOT NULL DEFAULT '',
        wilaya      TEXT,
        cycle       TEXT    NOT NULL DEFAULT 'middle'
                    CHECK (cycle IN ('primary','middle','secondary')),
        phone       TEXT,
        email       TEXT,
        created_at  TEXT    NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE ${DbConstants.tClasses} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        teacher_id  INTEGER NOT NULL,
        name        TEXT    NOT NULL,
        level       TEXT,
        cycle       TEXT    NOT NULL DEFAULT 'middle'
                    CHECK (cycle IN ('primary','middle','secondary')),
        school_year TEXT,
        created_at  TEXT    NOT NULL,
        FOREIGN KEY (teacher_id) REFERENCES ${DbConstants.tTeachers}(id)
          ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE ${DbConstants.tStudents} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id    INTEGER NOT NULL,
        first_name  TEXT    NOT NULL,
        last_name   TEXT    NOT NULL,
        gender      TEXT    NOT NULL DEFAULT 'male'
                    CHECK (gender IN ('male','female')),
        birth_date  TEXT,
        is_exempt   INTEGER NOT NULL DEFAULT 0 CHECK (is_exempt IN (0,1)),
        notes       TEXT,
        created_at  TEXT    NOT NULL,
        FOREIGN KEY (class_id) REFERENCES ${DbConstants.tClasses}(id)
          ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE ${DbConstants.tSessions} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id     INTEGER NOT NULL,
        session_date TEXT    NOT NULL,
        start_time   TEXT,
        end_time     TEXT,
        topic        TEXT,
        notes        TEXT,
        created_at   TEXT    NOT NULL,
        FOREIGN KEY (class_id) REFERENCES ${DbConstants.tClasses}(id)
          ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');

    batch.execute(_createRecordsSql);

    batch.execute('''
      CREATE TABLE ${DbConstants.tIncidents} (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id    INTEGER NOT NULL,
        class_id      INTEGER NOT NULL,
        session_id    INTEGER,
        incident_date TEXT    NOT NULL,
        type          TEXT    NOT NULL,
        severity      TEXT    NOT NULL DEFAULT 'minor'
                      CHECK (severity IN ('minor','moderate','severe')),
        location      TEXT,
        description   TEXT    NOT NULL,
        action_taken  TEXT,
        parent_notified INTEGER NOT NULL DEFAULT 0,
        parent_notification_note TEXT,
        pdf_path      TEXT,
        created_at    TEXT    NOT NULL,
        FOREIGN KEY (student_id) REFERENCES ${DbConstants.tStudents}(id)
          ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (class_id) REFERENCES ${DbConstants.tClasses}(id)
          ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (session_id) REFERENCES ${DbConstants.tSessions}(id)
          ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');

    // فهارس للأعمدة الأجنبية (تسرّع الحذف المتسلسل والاستعلامات)
    batch.execute('CREATE INDEX idx_classes_teacher ON ${DbConstants.tClasses}(teacher_id)');
    batch.execute('CREATE INDEX idx_students_class ON ${DbConstants.tStudents}(class_id)');
    batch.execute('CREATE INDEX idx_sessions_class_date ON ${DbConstants.tSessions}(class_id, session_date)');
    batch.execute('CREATE INDEX idx_records_session ON ${DbConstants.tRecords}(session_id)');
    batch.execute('CREATE INDEX idx_records_student ON ${DbConstants.tRecords}(student_id)');
    batch.execute('CREATE INDEX idx_incidents_student ON ${DbConstants.tIncidents}(student_id)');
    batch.execute('CREATE INDEX idx_incidents_class ON ${DbConstants.tIncidents}(class_id)');

    // الأستاذ الافتراضي (يُعدَّل لاحقاً من شاشة الإعدادات)
    batch.insert(DbConstants.tTeachers, {
      'id': DbConstants.defaultTeacherId,
      'full_name': '',
      'school_name': '',
      'cycle': 'middle',
      'created_at': DateTime.now().toIso8601String(),
    });

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // SQLite لا يعدّل قيد CHECK مباشرة: نعيد بناء الجدول مع نسخ البيانات.
      await db.execute(
          'ALTER TABLE ${DbConstants.tRecords} RENAME TO attendance_records_old');
      await db.execute(_createRecordsSql);
      await db.execute('''
        INSERT INTO ${DbConstants.tRecords} (id, session_id, student_id, status, note)
        SELECT id, session_id, student_id, status, note FROM attendance_records_old
      ''');
      await db.execute('DROP TABLE attendance_records_old');
      await db.execute(
          'CREATE INDEX idx_records_session ON ${DbConstants.tRecords}(session_id)');
      await db.execute(
          'CREATE INDEX idx_records_student ON ${DbConstants.tRecords}(student_id)');
    }
    if (oldVersion < 3) {
      // إشعار الولي في تقرير الحادث.
      await db.execute(
          'ALTER TABLE ${DbConstants.tIncidents} ADD COLUMN parent_notified INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE ${DbConstants.tIncidents} ADD COLUMN parent_notification_note TEXT');
    }
    if (oldVersion < 4) {
      // بيانات الأستاذ: الاسم، اللقب، الرتبة (full_name يبقى للتوافق).
      await db.execute('ALTER TABLE ${DbConstants.tTeachers} ADD COLUMN first_name TEXT');
      await db.execute('ALTER TABLE ${DbConstants.tTeachers} ADD COLUMN last_name TEXT');
      await db.execute('ALTER TABLE ${DbConstants.tTeachers} ADD COLUMN rank TEXT');
      await db.execute(
          'UPDATE ${DbConstants.tTeachers} SET first_name = full_name WHERE first_name IS NULL');
    }
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening == null) return;
    final db = await opening;
    await db.close();
    _opening = null;
  }
}

// ==========================================================================
// === REPOSITORIES ===
// ==========================================================================

// --- features/classes/data/repositories/classes_repository.dart ---
/// مستودع CRUD للأقسام. (التلاميذ في StudentsRepository)
/// حذف قسم يحذف تلاميذه وحصصه وسجلات حضوره وحوادثه تلقائياً (ON DELETE CASCADE).
class ClassesRepository {
  ClassesRepository(this._helper);
  final DatabaseHelper _helper;

  Future<Database> get _db => _helper.database;

  Future<int> insertClass(ClassModel c) async {
    final db = await _db;
    return db.insert(DbConstants.tClasses, c.toMap()..remove('id'));
  }

  Future<int> updateClass(ClassModel c) async {
    assert(c.id != null, 'updateClass requires an id');
    final db = await _db;
    return db.update(DbConstants.tClasses, c.toMap(),
        where: 'id = ?', whereArgs: [c.id]);
  }

  Future<int> deleteClass(int id) async {
    final db = await _db;
    return db.delete(DbConstants.tClasses, where: 'id = ?', whereArgs: [id]);
  }

  Future<ClassModel?> getClassById(int id) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT c.*, (SELECT COUNT(*) FROM ${DbConstants.tStudents} s WHERE s.class_id = c.id) AS student_count
      FROM ${DbConstants.tClasses} c WHERE c.id = ? LIMIT 1
    ''', [id]);
    return rows.isEmpty ? null : ClassModel.fromMap(rows.first);
  }

  /// كل الأقسام مع عدد التلاميذ في كل قسم.
  Future<List<ClassModel>> getClasses(
      {int teacherId = DbConstants.defaultTeacherId}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT c.*, COUNT(s.id) AS student_count
      FROM ${DbConstants.tClasses} c
      LEFT JOIN ${DbConstants.tStudents} s ON s.class_id = c.id
      WHERE c.teacher_id = ?
      GROUP BY c.id
      ORDER BY c.name COLLATE NOCASE
    ''', [teacherId]);
    return rows.map(ClassModel.fromMap).toList();
  }
}

// --- features/classes/data/repositories/students_repository.dart ---
/// مستودع CRUD للتلاميذ.
/// حذف تلميذ يحذف سجلات حضوره وحوادثه تلقائياً (ON DELETE CASCADE).
class StudentsRepository {
  StudentsRepository(this._helper);
  final DatabaseHelper _helper;

  Future<Database> get _db => _helper.database;

  Future<int> insertStudent(StudentModel s) async {
    final db = await _db;
    return db.insert(DbConstants.tStudents, s.toMap()..remove('id'));
  }

  /// إضافة عدة تلاميذ دفعة واحدة (مثلاً عند الاستيراد).
  Future<void> insertStudents(List<StudentModel> students) async {
    final db = await _db;
    final batch = db.batch();
    for (final s in students) {
      batch.insert(DbConstants.tStudents, s.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  Future<int> updateStudent(StudentModel s) async {
    assert(s.id != null, 'updateStudent requires an id');
    final db = await _db;
    return db.update(DbConstants.tStudents, s.toMap(),
        where: 'id = ?', whereArgs: [s.id]);
  }

  Future<int> deleteStudent(int id) async {
    final db = await _db;
    return db.delete(DbConstants.tStudents, where: 'id = ?', whereArgs: [id]);
  }

  Future<StudentModel?> getStudentById(int id) async {
    final db = await _db;
    final rows = await db.query(DbConstants.tStudents,
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : StudentModel.fromMap(rows.first);
  }

  /// تلاميذ قسم معيّن، مرتبون أبجدياً، مع بحث اختياري بالاسم أو اللقب.
  Future<List<StudentModel>> getStudentsByClass(int classId,
      {String? query}) async {
    final db = await _db;
    final q = query?.trim() ?? '';
    final hasQuery = q.isNotEmpty;
    final rows = await db.query(
      DbConstants.tStudents,
      where: hasQuery
          ? 'class_id = ? AND (first_name LIKE ? OR last_name LIKE ?)'
          : 'class_id = ?',
      whereArgs: hasQuery ? [classId, '%$q%', '%$q%'] : [classId],
      orderBy: 'last_name COLLATE NOCASE, first_name COLLATE NOCASE',
    );
    return rows.map(StudentModel.fromMap).toList();
  }
}

// --- features/classes/data/repositories/attendance_repository.dart ---
/// مستودع النداء: الحصص وسجلات الحضور.
class AttendanceRepository {
  AttendanceRepository(this._helper);
  final DatabaseHelper _helper;

  Future<Database> get _db => _helper.database;

  /// يُرجع حصة القسم في هذا التاريخ، وينشئها إن لم توجد
  /// (حصة واحدة لكل قسم في اليوم حالياً).
  Future<AttendanceSessionModel> getOrCreateSession(
      int classId, DateTime date) async {
    final db = await _db;
    final day = DateTime(date.year, date.month, date.day);
    final rows = await db.query(
      DbConstants.tSessions,
      where: 'class_id = ? AND session_date = ?',
      whereArgs: [classId, day.toIso8601String()],
      orderBy: 'id ASC',
      limit: 1,
    );
    if (rows.isNotEmpty) return AttendanceSessionModel.fromMap(rows.first);

    final session = AttendanceSessionModel(
      classId: classId,
      sessionDate: day,
      createdAt: DateTime.now(),
    );
    final id = await db.insert(
        DbConstants.tSessions, session.toMap()..remove('id'));
    return session.copyWith(id: id);
  }

  /// حالات التلاميذ المسجَّلة في الحصة: studentId ← status.
  Future<Map<int, AttendanceStatus>> getStatuses(int sessionId) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tRecords,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return {
      for (final r in rows)
        r['student_id'] as int: AttendanceStatus.fromValue(r['status'] as String?),
    };
  }

  /// يحفظ حالة تلميذ فوراً (إدراج إن لم يوجد سجل، وإلا تحديث) في معاملة واحدة.
  /// لا نستعمل UPSERT لأن بعض إصدارات SQLite في أجهزة أندرويد القديمة لا تدعمه.
  Future<void> setStatus(
      int sessionId, int studentId, AttendanceStatus status) async {
    final db = await _db;
    final batch = db.batch();
    _queueUpsert(batch, sessionId, studentId, status);
    await batch.commit(noResult: true);
  }

  /// يعيّن نفس الحالة لعدة تلاميذ دفعة واحدة (معاملة واحدة).
  Future<void> setStatusForAll(
      int sessionId, Iterable<int> studentIds, AttendanceStatus status) async {
    final db = await _db;
    final batch = db.batch();
    for (final id in studentIds) {
      _queueUpsert(batch, sessionId, id, status);
    }
    await batch.commit(noResult: true);
  }

  void _queueUpsert(
      Batch batch, int sessionId, int studentId, AttendanceStatus status) {
    batch.insert(
      DbConstants.tRecords,
      {
        'session_id': sessionId,
        'student_id': studentId,
        'status': status.name,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    batch.update(
      DbConstants.tRecords,
      {'status': status.name},
      where: 'session_id = ? AND student_id = ?',
      whereArgs: [sessionId, studentId],
    );
  }
}

// --- features/incidents/data/repositories/incidents_repository.dart ---
/// مستودع الحوادث.
class IncidentsRepository {
  IncidentsRepository(this._helper);
  final DatabaseHelper _helper;

  Future<Database> get _db => _helper.database;

  /// يُرجع معرّف السجل الجديد.
  Future<int> insertIncident(IncidentModel i) async {
    final db = await _db;
    return db.insert(DbConstants.tIncidents, i.toMap()..remove('id'));
  }

  Future<int> updateIncident(IncidentModel i) async {
    assert(i.id != null, 'updateIncident requires an id');
    final db = await _db;
    return db.update(DbConstants.tIncidents, i.toMap(),
        where: 'id = ?', whereArgs: [i.id]);
  }

  Future<int> deleteIncident(int id) async {
    final db = await _db;
    return db.delete(DbConstants.tIncidents, where: 'id = ?', whereArgs: [id]);
  }

  /// كل حوادث أقسام الأستاذ، الأحدث أولاً، مع اسم التلميذ والقسم.
  Future<List<IncidentListItem>> getAll(
      {int teacherId = DbConstants.defaultTeacherId}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT i.*, s.first_name AS student_first_name, s.last_name AS student_last_name,
             c.name AS class_name
      FROM ${DbConstants.tIncidents} i
      JOIN ${DbConstants.tStudents} s ON s.id = i.student_id
      JOIN ${DbConstants.tClasses} c ON c.id = i.class_id
      WHERE c.teacher_id = ?
      ORDER BY i.incident_date DESC, i.id DESC
    ''', [teacherId]);

    return rows
        .map((r) => IncidentListItem(
              incident: IncidentModel.fromMap(r),
              studentName:
                  '${r['student_last_name']} ${r['student_first_name']}',
              className: r['class_name'] as String,
            ))
        .toList();
  }
}

// --- features/settings/data/repositories/teachers_repository.dart ---
/// مستودع بيانات الأستاذ (صف واحد افتراضي يُنشأ مع القاعدة).
class TeachersRepository {
  TeachersRepository(this._helper);
  final DatabaseHelper _helper;

  Future<Database> get _db => _helper.database;

  Future<TeacherModel> getDefaultTeacher() async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tTeachers,
      where: 'id = ?',
      whereArgs: [DbConstants.defaultTeacherId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return TeacherModel(
          id: DbConstants.defaultTeacherId, createdAt: DateTime.now());
    }
    return TeacherModel.fromMap(rows.first);
  }

  Future<int> updateTeacher(TeacherModel t) async {
    final db = await _db;
    return db.update(DbConstants.tTeachers, t.toMap(),
        where: 'id = ?', whereArgs: [t.id ?? DbConstants.defaultTeacherId]);
  }
}

// ==========================================================================
// === SERVICES (PDF, PIN, LICENSE, BACKUP) ===
// ==========================================================================

// --- features/reports/data/services/pdf_service.dart ---
/// خدمة توليد ملفات PDF (كشف الحضور + تقرير الحادث).
///
/// العربية: يُحمَّل خط عربي من `assets/fonts/`. حزمة pdf تتولى وصل الحروف
/// العربية وترتيب الاتجاهين داخل النص عبر `Text(textDirection: ...)`.
///
/// ترتيب الأعمدة والعناصر من اليمين لليسار يتم يدوياً في [_Layout]
/// (بعكس ترتيب الخلايا عند العربية)، فلا يعتمد على دعم الجداول والصفوف
/// لـ RTL في إصدار الحزمة، ويعمل مع كل الإصدارات.
class PdfService {
  PdfService._();
  static final PdfService instance = PdfService._();

  // خط DejaVu Sans المرفق في المشروع (يدعم العربية). يمكنك استبداله بخط Cairo
  // بنفس اسمي الملفين في assets/fonts/ دون تغيير أي كود.
  static const String regularFontAsset = 'assets/fonts/pdf-regular.ttf';
  static const String boldFontAsset = 'assets/fonts/pdf-bold.ttf';

  pw.ThemeData? _theme;

  /// تحميل الخط العربي مرة واحدة وإعادة استعماله (يُخزَّن مؤقتاً).
  Future<pw.ThemeData> loadTheme() async {
    final cached = _theme;
    if (cached != null) return cached;

    try {
      final regular = pw.Font.ttf(await rootBundle.load(regularFontAsset));
      final bold = pw.Font.ttf(await rootBundle.load(boldFontAsset));
      return _theme = pw.ThemeData.withFont(base: regular, bold: bold);
    } catch (e) {
      // إن غاب ملف الخط لا ينهار التطبيق (لكن العربية لن تظهر في الـ PDF).
      debugPrint('PDF font not found: $e');
      return _theme = pw.ThemeData.base();
    }
  }

  // ======================================================== كشف الحضور

  Future<Uint8List> buildAttendanceSheet(AttendanceSheetData d) async {
    final l = _Layout(d.languageCode);
    final s = l.s;
    final theme = await loadTheme();

    final present =
        d.statuses.values.where((e) => e == AttendanceStatus.present).length;
    final absent =
        d.statuses.values.where((e) => e == AttendanceStatus.absent).length;

    final classTitle = (d.classModel.level == null || d.classModel.level!.isEmpty)
        ? d.classModel.name
        : '${d.classModel.name} — ${d.classModel.level}';

    final doc = pw.Document(
      title: '${s.attendanceSheet} ${d.classModel.name}',
      author: 'EPS Assistant DZ',
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: theme,
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            '${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          l.header(d.schoolName, s.attendanceSheet),
          pw.SizedBox(height: 12),

          // بيانات الحصة: مؤسسة | أستاذ / قسم | تاريخ
          pw.Table(
            border: _Layout.tableBorder,
            columnWidths: l.columnWidths([
              pw.FlexColumnWidth(1.2),
              pw.FlexColumnWidth(2),
              pw.FlexColumnWidth(1.2),
              pw.FlexColumnWidth(2),
            ]),
            children: [
              l.row([
                l.cell(s.institution, bold: true, background: _Layout.labelBg),
                l.cell(_orDash(d.schoolName)),
                l.cell(s.teacherLabel, bold: true, background: _Layout.labelBg),
                l.cell(_orDash(d.teacherName)),
              ]),
              l.row([
                l.cell(s.classLabel, bold: true, background: _Layout.labelBg),
                l.cell(classTitle),
                l.cell(s.date, bold: true, background: _Layout.labelBg),
                l.cell(_fmtDate(d.date)),
              ]),
            ],
          ),
          pw.SizedBox(height: 10),

          // العدّادات
          pw.Container(
            alignment: pw.Alignment.center,
            child: pw.Text(
              '${s.countPresent}: $present      ${s.countAbsent}: $absent      ${s.countTotal}: ${d.students.length}',
              textDirection: l.dir,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),

          // جدول التلاميذ (يتكرر الترويس في كل صفحة)
          pw.Table(
            border: _Layout.tableBorder,
            columnWidths: l.columnWidths([
              pw.FixedColumnWidth(32),
              pw.FlexColumnWidth(3),
              pw.FixedColumnWidth(95),
              pw.FlexColumnWidth(2),
            ]),
            children: [
              l.row(
                [
                  l.cell(s.indexLabel,
                      bold: true,
                      background: _Layout.navy,
                      color: PdfColors.white,
                      alignment: pw.Alignment.center),
                  l.cell(s.studentLabel,
                      bold: true, background: _Layout.navy, color: PdfColors.white),
                  l.cell(s.statusTitle,
                      bold: true,
                      background: _Layout.navy,
                      color: PdfColors.white,
                      alignment: pw.Alignment.center),
                  l.cell(s.notesLabel,
                      bold: true, background: _Layout.navy, color: PdfColors.white),
                ],
                repeat: true,
              ),
              for (var i = 0; i < d.students.length; i++)
                _studentRow(l, i + 1, d),
            ],
          ),
          pw.SizedBox(height: 24),
          l.signatureRow([s.teacherSignature, s.directorVisa]),
        ],
      ),
    );

    return doc.save();
  }

  pw.TableRow _studentRow(_Layout l, int index, AttendanceSheetData d) {
    final student = d.students[index - 1];
    final id = student.id;
    final status = id == null ? null : d.statuses[id];
    final PdfColor? shade = index.isEven ? const PdfColor.fromInt(0xFFF6F8FA) : null;

    return l.row([
      l.cell('$index', alignment: pw.Alignment.center, background: shade),
      l.cell(student.fullName, background: shade),
      l.cell(
        status == null ? '—' : l.s.statusLabel(status.name),
        bold: status != null,
        color: status == null ? PdfColors.grey600 : _statusColor(status),
        alignment: pw.Alignment.center,
        background: shade,
      ),
      l.cell('', background: shade),
    ]);
  }

  // ======================================================== تقرير حادث

  Future<Uint8List> buildIncidentReport(IncidentReportData d) async {
    final l = _Layout(d.languageCode);
    final s = l.s;
    final theme = await loadTheme();
    final inc = d.incident;
    final st = d.student;

    final doc = pw.Document(
      title: '${s.incidentReport} — ${st.fullName}',
      author: 'EPS Assistant DZ',
    );

    String optional(String? v) => (v == null || v.trim().isEmpty) ? '—' : v.trim();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: theme,
        ),
        build: (ctx) => [
          l.header(d.schoolName, s.incidentReport),
          pw.SizedBox(height: 6),
          l.kvTable([
            [s.institution, _orDash(d.schoolName)],
            [s.teacherLabel, _orDash(d.teacherName)],
          ]),
          pw.SizedBox(height: 12),

          // 1) بيانات التلميذ
          l.sectionBar(s.studentInfo),
          l.kvTable([
            [s.fullName, st.fullName],
            [s.classLabel, _orDash(d.className)],
            [s.gender, s.genderLabel(st.gender.name)],
            if (st.birthDate != null) [s.birthDate, _fmtDate(st.birthDate!)],
          ]),
          pw.SizedBox(height: 12),

          // 2) تفاصيل الحادث وطبيعة الإصابة
          l.sectionBar(s.incidentDetails),
          l.kvTable([
            [s.incidentDate, _fmtDate(inc.incidentDate)],
            [s.incidentLocation, optional(s.placeLabel(inc.location ?? ''))],
            [s.injuryNature, optional(s.injuryLabel(inc.type))],
            [s.severityTitle, s.severityLabel(inc.severity.name)],
          ]),
          pw.SizedBox(height: 12),

          l.sectionBar(s.incidentDescription),
          l.textBox(optional(inc.description), minHeight: 60),
          pw.SizedBox(height: 12),

          // 3) الإسعافات المقدَّمة
          l.sectionBar(s.firstAid),
          l.textBox(optional(inc.actionTaken), minHeight: 50),
          pw.SizedBox(height: 12),

          // 4) إشعار الولي
          l.sectionBar(s.parentNotification),
          l.kvTable([
            [
              s.parentNotification,
              inc.parentNotified ? s.parentNotified : s.parentNotNotified,
            ],
            if (inc.parentNotificationNote != null &&
                inc.parentNotificationNote!.trim().isNotEmpty)
              [s.notesLabel, inc.parentNotificationNote!.trim()],
          ]),
          pw.SizedBox(height: 28),

          l.signatureRow([s.teacherSignature, s.directorVisa, s.parentSignature]),
        ],
      ),
    );

    return doc.save();
  }

  // ======================================================== مساعدات

  static String _orDash(String v) => v.trim().isEmpty ? '—' : v.trim();

  /// dd/MM/yyyy (أرقام لاتينية — الشائع في الوثائق الإدارية الجزائرية).
  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static PdfColor _statusColor(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:
        return const PdfColor.fromInt(0xFF2E7D32);
      case AttendanceStatus.absent:
        return const PdfColor.fromInt(0xFFC62828);
      case AttendanceStatus.late:
        return const PdfColor.fromInt(0xFFEF6C00);
      case AttendanceStatus.noUniform:
        return const PdfColor.fromInt(0xFFB88200);
      case AttendanceStatus.sick:
        return const PdfColor.fromInt(0xFF6A1B9A);
      case AttendanceStatus.escaped:
        return const PdfColor.fromInt(0xFF5D4037);
      case AttendanceStatus.exempt:
        return const PdfColor.fromInt(0xFF1565C0);
      case AttendanceStatus.excused:
        return const PdfColor.fromInt(0xFF00838F);
    }
  }
}

/// أدوات تخطيط مشتركة تراعي اتجاه اللغة (RTL للعربية).
///
/// الصفحة نفسها تبقى LTR، والاتجاه العربي يُطبَّق بطريقتين:
///  1) النص: `Text(textDirection: rtl)` ليُشكَّل ويُرتَّب صحيحاً (bidi).
///  2) التخطيط: نعكس ترتيب الخلايا/الأعمدة/المربعات يدوياً ([ordered]).
class _Layout {
  _Layout(this.languageCode)
      : s = AppStrings.forCode(languageCode),
        rtl = languageCode == 'ar',
        dir = languageCode == 'ar' ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  final String languageCode;
  final AppStrings s;
  final bool rtl;
  final pw.TextDirection dir;

  static const PdfColor navy = PdfColor.fromInt(0xFF003366);
  static const PdfColor labelBg = PdfColor.fromInt(0xFFE8EEF5);
  static const PdfColor borderColor = PdfColor.fromInt(0xFF9AA7B5);
  static final pw.TableBorder tableBorder =
      pw.TableBorder.all(color: borderColor, width: 0.5);

  pw.Alignment get startAlignment =>
      rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft;
  pw.TextAlign get textAlign => rtl ? pw.TextAlign.right : pw.TextAlign.left;

  /// يعكس ترتيب العناصر في العربية (العنصر الأول يصبح أقصى اليمين).
  List<T> ordered<T>(List<T> items) => rtl ? items.reversed.toList() : items;

  /// عروض الأعمدة بحسب الترتيب المنطقي، معكوسة تلقائياً في العربية.
  Map<int, pw.TableColumnWidth> columnWidths(List<pw.TableColumnWidth> logical) {
    final o = ordered(logical);
    return {for (var i = 0; i < o.length; i++) i: o[i]};
  }

  /// صف جدول: الخلايا بالترتيب المنطقي، وتُعكس في العربية.
  pw.TableRow row(List<pw.Widget> cells, {bool repeat = false}) =>
      pw.TableRow(repeat: repeat, children: ordered(cells));

  /// خلية نص.
  pw.Widget cell(
    String text, {
    bool bold = false,
    PdfColor? color,
    PdfColor? background,
    pw.Alignment? alignment,
    double fontSize = 11,
  }) {
    return pw.Container(
      color: background,
      alignment: alignment ?? startAlignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textDirection: dir,
        textAlign: alignment == pw.Alignment.center ? pw.TextAlign.center : textAlign,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  /// ترويس الوثيقة: اسم المؤسسة + شريط العنوان.
  pw.Widget header(String school, String title) {
    return pw.Column(children: [
      pw.Text(
        school.trim().isEmpty ? '—' : school.trim(),
        textDirection: dir,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      pw.Container(
        width: double.infinity,
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        color: navy,
        child: pw.Text(
          title,
          textDirection: dir,
          style: pw.TextStyle(
            fontSize: 17,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      ),
    ]);
  }

  /// شريط عنوان قسم.
  pw.Widget sectionBar(String title) {
    return pw.Container(
      width: double.infinity,
      alignment: startAlignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: navy,
      child: pw.Text(
        title,
        textDirection: dir,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  /// جدول (عنوان | قيمة).
  pw.Widget kvTable(List<List<String>> rows) {
    return pw.Table(
      border: tableBorder,
      columnWidths: columnWidths([
        pw.FlexColumnWidth(1),
        pw.FlexColumnWidth(3),
      ]),
      children: [
        for (final r in rows)
          row([
            cell(r[0], bold: true, background: labelBg),
            cell(r[1]),
          ]),
      ],
    );
  }

  /// مربع نص متعدد الأسطر (وصف، إسعافات...).
  pw.Widget textBox(String text, {double minHeight = 50}) {
    return pw.Container(
      width: double.infinity,
      constraints: pw.BoxConstraints(minHeight: minHeight),
      alignment: rtl ? pw.Alignment.topRight : pw.Alignment.topLeft,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor, width: 0.5),
      ),
      child: pw.Text(
        text,
        textDirection: dir,
        textAlign: textAlign,
        style: const pw.TextStyle(fontSize: 11),
      ),
    );
  }

  /// صفّ مربعات الإمضاء (الأول يظهر أقصى اليمين في العربية).
  pw.Widget signatureRow(List<String> labels) {
    final items = <pw.Widget>[
      for (var i = 0; i < labels.length; i++)
        pw.Expanded(
          child: pw.Container(
            height: 80,
            alignment: pw.Alignment.topCenter,
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderColor, width: 0.5),
            ),
            child: pw.Text(
              labels[i],
              textDirection: dir,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
    ];

    final children = <pw.Widget>[];
    for (final item in ordered(items)) {
      if (children.isNotEmpty) children.add(pw.SizedBox(width: 12));
      children.add(item);
    }
    return pw.Row(children: children);
  }
}

// --- features/security/data/pin_service.dart ---
/// قفل التطبيق برمز PIN من 4 أرقام.
///
/// يُخزَّن في shared_preferences: ملح عشوائي + تجزئة SHA-256 (لا الرمز نفسه).
/// ملاحظة: هذا قفل واجهة يمنع الاطلاع العابر، وليس تشفيراً لقاعدة البيانات؛
/// ولأن الرمز 4 أرقام فقط فهو لا يصمد أمام من يملك الملفات.
class PinService {
  PinService(this._prefs);
  final SharedPreferences _prefs;

  static const int pinLength = 4;
  static const String _hashKey = 'pin_hash';
  static const String _saltKey = 'pin_salt';

  bool get isEnabled => _prefs.getString(_hashKey) != null;

  Future<void> setPin(String pin) async {
    assert(RegExp(r'^\d{4}$').hasMatch(pin), 'PIN must be 4 digits');
    final salt = _newSalt();
    await _prefs.setString(_saltKey, salt);
    await _prefs.setString(_hashKey, _hash(pin, salt));
  }

  bool verify(String pin) {
    final salt = _prefs.getString(_saltKey);
    final hash = _prefs.getString(_hashKey);
    if (salt == null || hash == null) return false;
    return _hash(pin, salt) == hash;
  }

  Future<void> disable() async {
    await _prefs.remove(_hashKey);
    await _prefs.remove(_saltKey);
  }

  static String _newSalt() {
    final rnd = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
  }

  static String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}

// --- features/license/data/license_service.dart ---
/// الفترة التجريبية: 30 يوماً من أول تشغيل (التاريخ محفوظ في shared_preferences).
///
/// ملاحظة: هذا عرض للمدة فقط ولا يمنع الاستعمال بعد انتهائها؛ كما أن التحقق
/// المحلي بالتاريخ يمكن التحايل عليه بتغيير ساعة الجهاز أو مسح بيانات التطبيق.
class LicenseService {
  LicenseService(this._prefs);
  final SharedPreferences _prefs;

  static const int trialDays = 30;
  static const String _firstRunKey = 'first_run_at';

  /// يُستدعى مرة عند بدء التطبيق: يسجّل أول تشغيل إن لم يكن مسجّلاً.
  Future<void> ensureStarted() async {
    if (_prefs.getString(_firstRunKey) == null) {
      await _prefs.setString(_firstRunKey, DateTime.now().toIso8601String());
    }
  }

  DateTime get firstRunAt =>
      DateTime.tryParse(_prefs.getString(_firstRunKey) ?? '') ?? DateTime.now();

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// عدد الأيام المنقضية منذ أول تشغيل (بالتقويم، لا بالساعات).
  int get daysUsed {
    final used = _dateOnly(DateTime.now()).difference(_dateOnly(firstRunAt)).inDays;
    return used < 0 ? 0 : used;
  }

  int get daysRemaining {
    final left = trialDays - daysUsed;
    return left < 0 ? 0 : left;
  }

  bool get isTrialExpired => daysRemaining == 0;
}

// --- features/settings/data/services/backup_service.dart ---
enum BackupFailure { invalidFile, newerVersion }

class BackupException implements Exception {
  const BackupException(this.reason);
  final BackupFailure reason;
  @override
  String toString() => 'BackupException($reason)';
}

/// النسخ الاحتياطي والاستعادة لملف قاعدة بيانات SQLite.
class BackupService {
  BackupService(this._helper);
  final DatabaseHelper _helper;

  static const _requiredTables = {
    DbConstants.tTeachers,
    DbConstants.tClasses,
    DbConstants.tStudents,
    DbConstants.tSessions,
    DbConstants.tRecords,
    DbConstants.tIncidents,
  };

  String get _stamp {
    final n = DateTime.now();
    String t(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${t(n.month)}${t(n.day)}_${t(n.hour)}${t(n.minute)}';
  }

  String get _fileName => 'eps_assistant_backup_$_stamp.db';

  /// يدمج أي تغييرات معلّقة في الملف الرئيسي قبل نسخه.
  Future<String> _prepareDbPath() async {
    final db = await _helper.database;
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {/* غير مهم إن لم يكن WAL مفعّلاً */}
    return _helper.databasePath;
  }

  /// نسخة مؤقتة جاهزة للمشاركة.
  Future<File> createBackupFile() async {
    final dbPath = await _prepareDbPath();
    final dir = await getTemporaryDirectory();
    return File(dbPath).copy(p.join(dir.path, _fileName));
  }

  /// حفظ النسخة في مجلد التطبيق (path_provider).
  Future<File> saveBackupToPhone() async {
    final dbPath = await _prepareDbPath();
    final dir = await _backupDirectory();
    return File(dbPath).copy(p.join(dir.path, _fileName));
  }

  Future<Directory> _backupDirectory() async {
    Directory? base;
    try {
      if (Platform.isAndroid) {
        base = await getExternalStorageDirectory();
      } else if (!Platform.isIOS) {
        base = await getDownloadsDirectory();
      }
    } catch (_) {
      base = null;
    }
    base ??= await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'EPS Assistant', 'backups'));
    await dir.create(recursive: true);
    return dir;
  }

  /// يستبدل قاعدة البيانات الحالية بالملف [source] بعد التحقق من صلاحيته.
  /// عند أي فشل بعد بدء الاستبدال تُعاد النسخة السابقة تلقائياً.
  Future<void> restoreFrom(File source) async {
    await _validate(source);

    final dbPath = await _helper.databasePath;
    final dbFile = File(dbPath);
    final safety = File('$dbPath.pre_restore');

    // نسخة أمان من البيانات الحالية
    await _helper.database; // يضمن وجود الملف
    await _helper.close();
    if (await dbFile.exists()) await dbFile.copy(safety.path);

    try {
      final tmp = File('$dbPath.restore_tmp');
      await source.copy(tmp.path);
      for (final suffix in const ['-wal', '-shm', '-journal']) {
        final f = File('$dbPath$suffix');
        if (await f.exists()) await f.delete();
      }
      if (await dbFile.exists()) await dbFile.delete();
      await tmp.rename(dbPath);

      // فتح القاعدة المستعادة (يُجري الترحيل تلقائياً إن كانت أقدم)
      await _helper.database;
    } catch (_) {
      // تراجع إلى النسخة السابقة
      await _helper.close();
      if (await safety.exists()) {
        if (await dbFile.exists()) await dbFile.delete();
        await safety.copy(dbPath);
      }
      rethrow;
    }
  }

  /// يتحقق أن الملف قاعدة SQLite تحوي جداول التطبيق وليست أحدث من هذا الإصدار.
  Future<void> _validate(File f) async {
    // 1) ترويسة SQLite
    final raf = await f.open();
    List<int> header;
    try {
      header = await raf.read(16);
    } finally {
      await raf.close();
    }
    if (utf8.decode(header, allowMalformed: true) != 'SQLite format 3\u0000') {
      throw const BackupException(BackupFailure.invalidFile);
    }

    // 2) الجداول والإصدار
    Database? db;
    try {
      db = await openDatabase(f.path, readOnly: true, singleInstance: false);
      final names = (await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type = 'table'"))
          .map((r) => r['name'] as String)
          .toSet();
      if (!names.containsAll(_requiredTables)) {
        throw const BackupException(BackupFailure.invalidFile);
      }
      final version =
          Sqflite.firstIntValue(await db.rawQuery('PRAGMA user_version')) ?? 0;
      if (version > DbConstants.dbVersion) {
        throw const BackupException(BackupFailure.newerVersion);
      }
    } on DatabaseException {
      throw const BackupException(BackupFailure.invalidFile);
    } finally {
      await db?.close();
    }
  }
}

// ==========================================================================
// === PROVIDERS ===
// ==========================================================================

// --- shared/providers/core_providers.dart ---
/// يُستبدل في main() بالنسخة الجاهزة من SharedPreferences.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider in main()'),
);

final databaseHelperProvider =
    Provider<DatabaseHelper>((ref) => DatabaseHelper.instance);

final classesRepositoryProvider = Provider<ClassesRepository>(
    (ref) => ClassesRepository(ref.watch(databaseHelperProvider)));

final studentsRepositoryProvider = Provider<StudentsRepository>(
    (ref) => StudentsRepository(ref.watch(databaseHelperProvider)));

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
    (ref) => AttendanceRepository(ref.watch(databaseHelperProvider)));

final incidentsRepositoryProvider = Provider<IncidentsRepository>(
    (ref) => IncidentsRepository(ref.watch(databaseHelperProvider)));

final teachersRepositoryProvider = Provider<TeachersRepository>(
    (ref) => TeachersRepository(ref.watch(databaseHelperProvider)));

final backupServiceProvider = Provider<BackupService>(
    (ref) => BackupService(ref.watch(databaseHelperProvider)));

final pinServiceProvider =
    Provider<PinService>((ref) => PinService(ref.watch(sharedPreferencesProvider)));

final licenseServiceProvider = Provider<LicenseService>(
    (ref) => LicenseService(ref.watch(sharedPreferencesProvider)));

// --- features/settings/presentation/providers/settings_providers.dart ---
/// اللغات المدعومة: العربية (RTL) والفرنسية والإنجليزية (LTR).
const supportedAppLocales = <Locale>[
  Locale('ar'),
  Locale('fr'),
  Locale('en'),
];

/// الوضع: فاتح / داكن / حسب النظام — يُحفظ في shared_preferences.
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ref.watch(sharedPreferencesProvider)),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._prefs) : super(_read(_prefs));
  final SharedPreferences _prefs;
  static const _key = 'theme_mode';

  static ThemeMode _read(SharedPreferences p) {
    switch (p.getString(_key)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(_key, mode.name);
  }
}

/// اللغة الحالية (الافتراضي: العربية) — تُحفظ في shared_preferences.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(ref.watch(sharedPreferencesProvider)),
);

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(this._prefs) : super(_read(_prefs));
  final SharedPreferences _prefs;
  static const _key = 'locale';

  static Locale _read(SharedPreferences p) {
    final code = p.getString(_key);
    final match = supportedAppLocales.where((l) => l.languageCode == code);
    return match.isEmpty ? const Locale('ar') : match.first;
  }

  Future<void> setLanguage(String code) async {
    state = Locale(code);
    await _prefs.setString(_key, code);
  }
}

// --- features/settings/presentation/providers/teacher_provider.dart ---
/// بيانات الأستاذ (جدول teachers).
final teacherProvider =
    StateNotifierProvider<TeacherNotifier, AsyncValue<TeacherModel>>(
  (ref) => TeacherNotifier(ref.watch(teachersRepositoryProvider)),
);

class TeacherNotifier extends StateNotifier<AsyncValue<TeacherModel>> {
  TeacherNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  final TeachersRepository _repo;

  Future<void> load() async {
    try {
      final t = await _repo.getDefaultTeacher();
      if (mounted) state = AsyncValue.data(t);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(TeacherModel teacher) async {
    await _repo.updateTeacher(teacher);
    await load();
  }
}

// --- features/security/presentation/pin_providers.dart ---
/// هل قفل PIN مفعّل؟ (يبدأ من القيمة المخزَّنة ويُحدَّث من الإعدادات)
final pinEnabledProvider = StateProvider<bool>(
  (ref) => ref.watch(pinServiceProvider).isEnabled,
);

// --- features/classes/presentation/providers/classes_provider.dart ---
/// حالة قائمة الأقسام. أي إضافة/تعديل/حذف تكتب في SQLite ثم تعيد التحميل،
/// فتتحدّث الواجهة تلقائياً.
final classesProvider =
    StateNotifierProvider<ClassesNotifier, AsyncValue<List<ClassModel>>>(
  (ref) => ClassesNotifier(ref.watch(classesRepositoryProvider)),
);

class ClassesNotifier extends StateNotifier<AsyncValue<List<ClassModel>>> {
  ClassesNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  final ClassesRepository _repo;

  /// [showLoading] لإظهار مؤشر التحميل (مثلاً عند «إعادة المحاولة»).
  Future<void> load({bool showLoading = false}) async {
    if (showLoading) state = const AsyncValue.loading();
    try {
      final list = await _repo.getClasses();
      if (mounted) state = AsyncValue.data(list);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(ClassModel c) async {
    await _repo.insertClass(c);
    await load();
  }

  Future<void> edit(ClassModel c) async {
    await _repo.updateClass(c);
    await load();
  }

  Future<void> remove(int id) async {
    await _repo.deleteClass(id);
    await load();
  }
}

// --- features/classes/presentation/providers/students_provider.dart ---
/// حالة تلاميذ قسم معيّن (family حسب classId).
final studentsProvider = StateNotifierProvider.autoDispose
    .family<StudentsNotifier, AsyncValue<List<StudentModel>>, int>(
  (ref, classId) => StudentsNotifier(ref, classId),
);

class StudentsNotifier extends StateNotifier<AsyncValue<List<StudentModel>>> {
  StudentsNotifier(Ref ref, this.classId)
      : _ref = ref,
        _repo = ref.read(studentsRepositoryProvider),
        super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;
  final StudentsRepository _repo;
  final int classId;

  Future<void> load({bool showLoading = false}) async {
    if (showLoading) state = const AsyncValue.loading();
    try {
      final list = await _repo.getStudentsByClass(classId);
      if (mounted) state = AsyncValue.data(list);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(StudentModel s) async {
    await _repo.insertStudent(s);
    await _afterChange();
  }

  Future<void> edit(StudentModel s) async {
    await _repo.updateStudent(s);
    await _afterChange();
  }

  Future<void> remove(int id) async {
    await _repo.deleteStudent(id);
    await _afterChange();
  }

  Future<void> _afterChange() async {
    await load();
    // تحديث عدد التلاميذ المعروض في بطاقة القسم.
    if (mounted) await _ref.read(classesProvider.notifier).load();
  }
}

// --- features/classes/presentation/providers/attendance_provider.dart ---
/// مفتاح الـ family: القسم + اليوم (التاريخ بدون وقت).
class AttendanceArgs extends Equatable {
  AttendanceArgs({required this.classId, required DateTime date})
      : date = DateTime(date.year, date.month, date.day);

  final int classId;
  final DateTime date;

  @override
  List<Object?> get props => [classId, date];
}

/// حالة شاشة النداء.
class AttendanceState {
  const AttendanceState({
    required this.session,
    required this.students,
    required this.statuses,
  });

  final AttendanceSessionModel session;
  final List<StudentModel> students;

  /// studentId ← الحالة. التلميذ غير الموجود هنا «لم يُنادَ عليه بعد».
  final Map<int, AttendanceStatus> statuses;

  int get total => students.length;
  int get presentCount =>
      statuses.values.where((s) => s == AttendanceStatus.present).length;
  int get absentCount =>
      statuses.values.where((s) => s == AttendanceStatus.absent).length;

  /// هل توجد حالة مسجَّلة غير «حاضر» (لتأكيد «تعيين الكل حاضر»)؟
  bool get hasNonPresent =>
      statuses.values.any((s) => s != AttendanceStatus.present);

  AttendanceState copyWith({Map<int, AttendanceStatus>? statuses}) =>
      AttendanceState(
        session: session,
        students: students,
        statuses: statuses ?? this.statuses,
      );
}

final attendanceProvider = StateNotifierProvider.autoDispose
    .family<AttendanceNotifier, AsyncValue<AttendanceState>, AttendanceArgs>(
  (ref, args) => AttendanceNotifier(ref, args),
);

class AttendanceNotifier extends StateNotifier<AsyncValue<AttendanceState>> {
  AttendanceNotifier(Ref ref, this.args)
      : _repo = ref.read(attendanceRepositoryProvider),
        _studentsRepo = ref.read(studentsRepositoryProvider),
        super(const AsyncValue.loading()) {
    load();
  }

  final AttendanceArgs args;
  final AttendanceRepository _repo;
  final StudentsRepository _studentsRepo;

  Future<void> load({bool showLoading = false}) async {
    if (showLoading) state = const AsyncValue.loading();
    try {
      final session = await _repo.getOrCreateSession(args.classId, args.date);
      final students = await _studentsRepo.getStudentsByClass(args.classId);
      final statuses = await _repo.getStatuses(session.id!);
      if (mounted) {
        state = AsyncValue.data(AttendanceState(
          session: session,
          students: students,
          statuses: statuses,
        ));
      }
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// حفظ تلقائي: تتحدّث الواجهة فوراً، ثم تُكتب الحالة في SQLite مباشرة.
  /// عند فشل الكتابة نعيد التحميل من القاعدة حتى لا تعرض الواجهة ما لم يُحفظ.
  Future<void> setStatus(int studentId, AttendanceStatus status) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(
      current.copyWith(statuses: {...current.statuses, studentId: status}),
    );
    try {
      await _repo.setStatus(current.session.id!, studentId, status);
    } catch (_) {
      await load();
      rethrow;
    }
  }

  /// تعيين كل التلاميذ «حاضر» دفعة واحدة.
  Future<void> setAllPresent() async {
    final current = state.valueOrNull;
    if (current == null || current.students.isEmpty) return;

    final ids = current.students.map((s) => s.id!).toList();
    state = AsyncValue.data(current.copyWith(statuses: {
      for (final id in ids) id: AttendanceStatus.present,
    }));
    try {
      await _repo.setStatusForAll(
          current.session.id!, ids, AttendanceStatus.present);
    } catch (_) {
      await load();
      rethrow;
    }
  }
}

// --- features/incidents/presentation/providers/incidents_provider.dart ---
final incidentsProvider = StateNotifierProvider<IncidentsNotifier,
    AsyncValue<List<IncidentListItem>>>(
  (ref) => IncidentsNotifier(ref.watch(incidentsRepositoryProvider)),
);

class IncidentsNotifier
    extends StateNotifier<AsyncValue<List<IncidentListItem>>> {
  IncidentsNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  final IncidentsRepository _repo;

  Future<void> load({bool showLoading = false}) async {
    if (showLoading) state = const AsyncValue.loading();
    try {
      final list = await _repo.getAll();
      if (mounted) state = AsyncValue.data(list);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// يكتب الحادث في SQLite ويعيد التحميل. يُرجع معرّف السجل الجديد.
  Future<int> add(IncidentModel incident) async {
    final id = await _repo.insertIncident(incident);
    await load();
    return id;
  }

  Future<void> remove(int id) async {
    await _repo.deleteIncident(id);
    await load();
  }
}

// ==========================================================================
// === SHARED WIDGETS & UTILS ===
// ==========================================================================

// --- core/widgets/state_views.dart ---
/// حالة فارغة (لا بيانات).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title,
                style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// حالة خطأ مع زر إعادة المحاولة.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

// --- core/widgets/confirm_dialog.dart ---
/// نافذة تأكيد الحذف. تُرجع true عند التأكيد.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final s = AppStrings.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(s.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(s.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// نافذة تأكيد عادية (غير مدمِّرة). تُرجع true عند التأكيد.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final s = AppStrings.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

// --- core/utils/ui_helpers.dart ---
/// ينفّذ عملية على قاعدة البيانات، وعند الفشل يعرض SnackBar بدل أن ينهار التطبيق.
Future<void> runGuarded(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e, st) {
    debugPrint('Operation failed: $e\n$st');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AppStrings.of(context).errorGeneric)));
  }
}

// --- features/classes/presentation/utils/attendance_status_style.dart ---
/// لون وأيقونة كل حالة حضور (يتكيّف مع الوضع الفاتح/الداكن).
extension AttendanceStatusStyle on AttendanceStatus {
  Color color(BuildContext context) {
    final c = context.attendanceColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    switch (this) {
      case AttendanceStatus.present:
        return c.present;
      case AttendanceStatus.absent:
        return c.absent;
      case AttendanceStatus.late:
        return c.late;
      case AttendanceStatus.noUniform:
        return c.warning;
      case AttendanceStatus.sick:
        return dark ? AppColors.sickDark : AppColors.sickLight;
      case AttendanceStatus.escaped:
        return dark ? AppColors.escapedDark : AppColors.escapedLight;
      case AttendanceStatus.exempt:
        return dark ? AppColors.exemptDark : AppColors.exemptLight;
      case AttendanceStatus.excused:
        return dark ? AppColors.excusedDark : AppColors.excusedLight;
    }
  }

  IconData get icon {
    switch (this) {
      case AttendanceStatus.present:
        return Icons.check_circle_outline;
      case AttendanceStatus.absent:
        return Icons.cancel_outlined;
      case AttendanceStatus.late:
        return Icons.schedule;
      case AttendanceStatus.noUniform:
        return Icons.checkroom;
      case AttendanceStatus.sick:
        return Icons.local_hospital_outlined;
      case AttendanceStatus.escaped:
        return Icons.directions_run;
      case AttendanceStatus.exempt:
        return Icons.block;
      case AttendanceStatus.excused:
        return Icons.assignment_turned_in_outlined;
    }
  }
}

/// لون نص مقروء فوق خلفية بلون [background].
Color onColorFor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black87;

// --- features/reports/presentation/widgets/export_bottom_sheet.dart ---
/// نافذة التصدير السفلية: معاينة وطباعة، حفظ في الهاتف، مشاركة.
///
/// الاستعمال (يعمل مع أي تقرير):
/// ```dart
/// ExportBottomSheet.show(
///   context,
///   title: 'كشف الحضور',
///   fileName: 'attendance_4M1_20261030',
///   buildPdf: () => PdfService.instance.buildAttendanceSheet(data),
/// );
/// ```
class ExportBottomSheet extends StatefulWidget {
  const ExportBottomSheet({
    super.key,
    required this.title,
    required this.fileName,
    required this.buildPdf,
  });

  /// عنوان يظهر أعلى النافذة.
  final String title;

  /// اسم الملف بدون امتداد.
  final String fileName;

  /// يولّد بايتات الـ PDF (يُستدعى مرة واحدة عند فتح النافذة).
  final Future<Uint8List> Function() buildPdf;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String fileName,
    required Future<Uint8List> Function() buildPdf,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ExportBottomSheet(
        title: title,
        fileName: fileName,
        buildPdf: buildPdf,
      ),
    );
  }

  @override
  State<ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<ExportBottomSheet> {
  Uint8List? _bytes;
  bool _generating = true;
  bool _failed = false;
  bool _busy = false; // عملية طباعة/حفظ/مشاركة جارية
  String? _savedPath;

  /// اسم ملف آمن (حروف وأرقام وعربية وشرطات فقط).
  late final String _safeName = widget.fileName
      .replaceAll(RegExp(r'[^A-Za-z0-9_\-\u0600-\u06FF]+'), '_');

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _failed = false;
    });
    try {
      final bytes = await widget.buildPdf();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _generating = false;
      });
    } catch (e, st) {
      debugPrint('PDF generation failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _generating = false;
        _failed = true;
      });
    }
  }

  /// ينفّذ عملية على الملف مع إظهار حالة الانشغال ومعالجة الأخطاء.
  Future<void> _run(Future<void> Function(Uint8List bytes) action) async {
    final bytes = _bytes;
    if (bytes == null || _busy) return;
    setState(() => _busy = true);
    try {
      await action(bytes);
    } catch (e, st) {
      debugPrint('Export action failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
              SnackBar(content: Text(AppStrings.of(context).errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// معاينة الملف وطباعته (نافذة النظام: معاينة + اختيار الطابعة أو «حفظ كـ PDF»).
  Future<void> _previewAndPrint() => _run((bytes) async {
        await Printing.layoutPdf(
          name: '$_safeName.pdf',
          onLayout: (_) async => bytes,
        );
      });

  /// حفظ في الهاتف عبر path_provider.
  Future<void> _saveToPhone() => _run((bytes) async {
        final dir = await _targetDirectory();
        final file = File(p.join(dir.path, '$_safeName.pdf'));
        await file.writeAsBytes(bytes, flush: true);
        if (mounted) setState(() => _savedPath = file.path);
      });

  /// مشاركة الملف عبر قائمة المشاركة في النظام.
  Future<void> _share() => _run((bytes) async {
        await Printing.sharePdf(bytes: bytes, filename: '$_safeName.pdf');
      });

  /// مجلد الحفظ:
  ///  - أندرويد: مجلد التطبيق الخارجي (لا يحتاج إذناً).
  ///  - سطح المكتب: مجلد التنزيلات.
  ///  - غير ذلك/عند الفشل: مجلد مستندات التطبيق.
  Future<Directory> _targetDirectory() async {
    Directory? base;
    try {
      if (Platform.isAndroid) {
        base = await getExternalStorageDirectory();
      } else if (!Platform.isIOS) {
        base = await getDownloadsDirectory();
      }
    } catch (_) {
      base = null;
    }
    base ??= await getApplicationDocumentsDirectory();

    final dir = Directory(p.join(base.path, 'EPS Assistant'));
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final ready = _bytes != null && !_busy;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.picture_as_pdf, color: context.attendanceColors.absent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.title, style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$_safeName.pdf',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 16),

            if (_generating || _busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              if (_generating)
                Text(s.preparingPdf, textAlign: TextAlign.center),
              const SizedBox(height: 8),
            ],

            if (_failed) ...[
              Text(
                s.errorGeneric,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.refresh),
                label: Text(s.retry),
              ),
            ] else ...[
              _ExportAction(
                icon: Icons.print_outlined,
                label: s.previewPrint,
                color: theme.colorScheme.primary,
                onTap: ready ? _previewAndPrint : null,
              ),
              const SizedBox(height: 8),
              _ExportAction(
                icon: Icons.save_alt,
                label: s.saveToPhone,
                color: context.attendanceColors.present,
                onTap: ready ? _saveToPhone : null,
              ),
              const SizedBox(height: 8),
              _ExportAction(
                icon: Icons.share_outlined,
                label: s.shareFile,
                color: context.attendanceColors.late,
                onTap: ready ? _share : null,
              ),
            ],

            if (_savedPath != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle,
                      size: 20, color: context.attendanceColors.present),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: '${s.savedTo} ',
                            style: theme.textTheme.bodyMedium),
                        TextSpan(
                          text: _savedPath,
                          style: theme.textTheme.bodySmall,
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// زر كبير بأيقونة ملوّنة.
class _ExportAction extends StatelessWidget {
  const _ExportAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: enabled ? 0.18 : 0.08),
                foregroundColor: enabled ? color : theme.disabledColor,
                child: Icon(icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: enabled ? null : theme.disabledColor,
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  color: enabled ? theme.colorScheme.outline : theme.disabledColor),
            ],
          ),
        ),
      ),
    );
  }
}

// --- features/security/presentation/widgets/pin_pad.dart ---
/// لوحة إدخال رمز PIN: 4 نقاط + أزرار أرقام. عند اكتمال الرقم الرابع
/// تُمسح الخانات وتُستدعى [onCompleted] بالرمز.
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onCompleted, this.enabled = true});

  final ValueChanged<String> onCompleted;
  final bool enabled;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';

  void _tap(String digit) {
    if (!widget.enabled || _pin.length >= PinService.pinLength) return;
    setState(() => _pin += digit);

    if (_pin.length == PinService.pinLength) {
      final done = _pin;
      // مهلة قصيرة ليظهر امتلاء النقطة الرابعة قبل المسح.
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        setState(() => _pin = '');
        widget.onCompleted(done);
      });
    }
  }

  void _backspace() {
    if (!widget.enabled || _pin.isEmpty || _pin.length >= PinService.pinLength) {
      return;
    }
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget key(String digit) => _PinKey(
          onTap: widget.enabled ? () => _tap(digit) : null,
          child: Text(digit, style: theme.textTheme.headlineMedium),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // النقاط
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < PinService.pinLength; i++)
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(color: theme.colorScheme.primary, width: 2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 32),

        // لوحة الأرقام (دائماً LTR ليبقى ترتيب الأرقام مألوفاً)
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [for (final d in row) key(d)],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 88, height: 72),
                    key('0'),
                    _PinKey(
                      onTap: widget.enabled ? _backspace : null,
                      child: const Icon(Icons.backspace_outlined),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// === FEATURE WIDGETS ===
// ==========================================================================

// --- features/classes/presentation/widgets/class_card.dart ---
/// بطاقة قسم: الاسم، زر «إدارة التلاميذ»، وزر «النداء» الأخضر.
class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.classModel,
    required this.onManageStudents,
    required this.onAttendance,
    required this.onEdit,
    required this.onDelete,
  });

  final ClassModel classModel;
  final VoidCallback onManageStudents;
  final VoidCallback onAttendance;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final subtitleParts = <String>[
      if (classModel.level != null && classModel.level!.isNotEmpty)
        classModel.level!,
      s.cycleLabel(classModel.cycle.name),
      s.studentCount(classModel.studentCount ?? 0),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    classModel.name,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(s.edit)),
                    PopupMenuItem(value: 'delete', child: Text(s.delete)),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Text(
                subtitleParts.join(' • '),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onManageStudents,
                      icon: const Icon(Icons.people_alt_outlined),
                      label: Text(s.manageStudents),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: context.attendanceColors.present,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                      ),
                      onPressed: onAttendance,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(s.attendance),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- features/classes/presentation/widgets/class_form_dialog.dart ---
/// نافذة إضافة/تعديل قسم: الاسم، المستوى، الطور. تُرجع ClassModel أو null.
class ClassFormDialog extends StatefulWidget {
  const ClassFormDialog({super.key, this.initial});
  final ClassModel? initial;

  static Future<ClassModel?> show(BuildContext context, {ClassModel? initial}) =>
      showDialog<ClassModel>(
        context: context,
        builder: (_) => ClassFormDialog(initial: initial),
      );

  @override
  State<ClassFormDialog> createState() => _ClassFormDialogState();
}

class _ClassFormDialogState extends State<ClassFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _level;
  late Cycle _cycle;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _level = TextEditingController(text: widget.initial?.level ?? '');
    _cycle = widget.initial?.cycle ?? Cycle.middle;
  }

  @override
  void dispose() {
    _name.dispose();
    _level.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final level = _level.text.trim();
    final initial = widget.initial;
    Navigator.pop(
      context,
      ClassModel(
        id: initial?.id,
        teacherId: initial?.teacherId ?? DbConstants.defaultTeacherId,
        name: _name.text.trim(),
        level: level.isEmpty ? null : level,
        cycle: _cycle,
        schoolYear: initial?.schoolYear,
        createdAt: initial?.createdAt ?? DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isEdit = widget.initial != null;

    return AlertDialog(
      title: Text(isEdit ? s.editClass : s.addClass),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: s.className,
                  hintText: s.classNameHint,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? s.required : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _level,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: s.level,
                  hintText: s.levelHint,
                ),
              ),
              const SizedBox(height: 16),
              Text(s.cycle, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in Cycle.values)
                    ChoiceChip(
                      label: Text(s.cycleLabel(c.name)),
                      selected: _cycle == c,
                      onSelected: (_) => setState(() => _cycle = c),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(s.save)),
      ],
    );
  }
}

// --- features/classes/presentation/widgets/student_form_dialog.dart ---
/// نافذة إضافة/تعديل تلميذ: الاسم، اللقب، الجنس. تُرجع StudentModel أو null.
class StudentFormDialog extends StatefulWidget {
  const StudentFormDialog({super.key, required this.classId, this.initial});
  final int classId;
  final StudentModel? initial;

  static Future<StudentModel?> show(
    BuildContext context, {
    required int classId,
    StudentModel? initial,
  }) =>
      showDialog<StudentModel>(
        context: context,
        builder: (_) => StudentFormDialog(classId: classId, initial: initial),
      );

  @override
  State<StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends State<StudentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late Gender _gender;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.initial?.firstName ?? '');
    _lastName = TextEditingController(text: widget.initial?.lastName ?? '');
    _gender = widget.initial?.gender ?? Gender.male;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final i = widget.initial;
    Navigator.pop(
      context,
      StudentModel(
        id: i?.id,
        classId: widget.classId,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        gender: _gender,
        birthDate: i?.birthDate,
        isExempt: i?.isExempt ?? false,
        notes: i?.notes,
        createdAt: i?.createdAt ?? DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isEdit = widget.initial != null;
    String? required(String? v) =>
        (v == null || v.trim().isEmpty) ? s.required : null;

    return AlertDialog(
      title: Text(isEdit ? s.editStudent : s.addStudent),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _lastName,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: s.lastName),
                validator: required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _firstName,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: s.firstName),
                validator: required,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              Text(s.gender, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final g in Gender.values)
                    ChoiceChip(
                      label: Text(s.genderLabel(g.name)),
                      selected: _gender == g,
                      onSelected: (_) => setState(() => _gender = g),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(s.save)),
      ],
    );
  }
}

// --- features/classes/presentation/widgets/attendance_summary_header.dart ---
/// أعلى شاشة النداء: عدّادات (الحاضرون، الغائبون، المجموع) + زر «تعيين الكل حاضر».
class AttendanceSummaryHeader extends StatelessWidget {
  const AttendanceSummaryHeader({
    super.key,
    required this.present,
    required this.absent,
    required this.total,
    required this.onSetAllPresent,
  });

  final int present;
  final int absent;
  final int total;
  final VoidCallback? onSetAllPresent;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.attendanceColors;
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: _Counter(
                        label: s.countPresent,
                        value: present,
                        color: colors.present)),
                const SizedBox(width: 8),
                Expanded(
                    child: _Counter(
                        label: s.countAbsent,
                        value: absent,
                        color: colors.absent)),
                const SizedBox(width: 8),
                Expanded(
                    child: _Counter(
                        label: s.countTotal,
                        value: total,
                        color: theme.colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onSetAllPresent,
                icon: const Icon(Icons.done_all),
                label: Text(s.setAllPresent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: theme.textTheme.headlineSmall
                ?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

// --- features/classes/presentation/widgets/student_attendance_tile.dart ---
/// سطر تلميذ في شاشة النداء: [حاضر] [غائب] [أخرى ▾].
class StudentAttendanceTile extends StatelessWidget {
  const StudentAttendanceTile({
    super.key,
    required this.index,
    required this.student,
    required this.status,
    required this.onChanged,
  });

  final int index;
  final StudentModel student;

  /// null = لم يُنادَ عليه بعد.
  final AttendanceStatus? status;
  final ValueChanged<AttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    final isPresent = status == AttendanceStatus.present;
    final isAbsent = status == AttendanceStatus.absent;
    final otherStatus = (status != null && !isPresent && !isAbsent) ? status : null;

    final borderColor = status?.color(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: borderColor ?? Colors.transparent,
          width: borderColor == null ? 0 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text('$index', style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    student.fullName,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ChoiceBox(
                    label: s.statusLabel(AttendanceStatus.present.name),
                    icon: AttendanceStatus.present.icon,
                    color: AttendanceStatus.present.color(context),
                    selected: isPresent,
                    onTap: () => onChanged(AttendanceStatus.present),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChoiceBox(
                    label: s.statusLabel(AttendanceStatus.absent.name),
                    icon: AttendanceStatus.absent.icon,
                    color: AttendanceStatus.absent.color(context),
                    selected: isAbsent,
                    onTap: () => onChanged(AttendanceStatus.absent),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PopupMenuButton<AttendanceStatus>(
                    tooltip: '',
                    onSelected: onChanged,
                    itemBuilder: (_) => [
                      for (final st in AttendanceStatus.others)
                        PopupMenuItem<AttendanceStatus>(
                          value: st,
                          child: Row(
                            children: [
                              Icon(st.icon, color: st.color(context)),
                              const SizedBox(width: 12),
                              Text(
                                s.statusLabel(st.name),
                                style: TextStyle(
                                  color: st.color(context),
                                  fontWeight: st == otherStatus
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    child: _ChoiceBox(
                      label: otherStatus == null
                          ? s.other
                          : s.statusLabel(otherStatus.name),
                      icon: otherStatus?.icon,
                      color: otherStatus?.color(context) ??
                          theme.colorScheme.onSurfaceVariant,
                      selected: otherStatus != null,
                      trailing: Icons.arrow_drop_down,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// زر اختيار: معبّأ باللون عند التحديد، ومحاط به عند عدمه.
class _ChoiceBox extends StatelessWidget {
  const _ChoiceBox({
    required this.label,
    required this.color,
    required this.selected,
    this.icon,
    this.trailing,
    this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final IconData? icon;
  final IconData? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? onColorFor(color) : color;

    return Material(
      color: selected ? color : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: selected ? 1 : 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (trailing != null) Icon(trailing, size: 20, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

// --- features/incidents/presentation/widgets/incident_card.dart ---
/// بطاقة حادث في القائمة.
class IncidentCard extends StatelessWidget {
  const IncidentCard({
    super.key,
    required this.item,
    required this.onExport,
    required this.onDelete,
  });

  final IncidentListItem item;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  Color _severityColor(BuildContext context, IncidentSeverity sev) {
    final c = context.attendanceColors;
    switch (sev) {
      case IncidentSeverity.minor:
        return c.warning;
      case IncidentSeverity.moderate:
        return c.late;
      case IncidentSeverity.severe:
        return c.absent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final loc = MaterialLocalizations.of(context);
    final inc = item.incident;
    final color = _severityColor(context, inc.severity);
    final colors = context.attendanceColors;

    final when =
        '${loc.formatMediumDate(inc.incidentDate)} • ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(inc.incidentDate))}';
    final place = (inc.location == null || inc.location!.isEmpty)
        ? null
        : s.placeLabel(inc.location!);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // شريط لون الخطورة
            Container(width: 6, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.studentName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.className} • ${s.injuryLabel(inc.type)} • ${s.severityLabel(inc.severity.name)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      place == null ? when : '$when • $place',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          inc.parentNotified
                              ? Icons.check_circle_outline
                              : Icons.warning_amber_rounded,
                          size: 18,
                          color: inc.parentNotified ? colors.present : colors.late,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            inc.parentNotified
                                ? s.parentNotified
                                : s.parentNotNotified,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color:
                                  inc.parentNotified ? colors.present : colors.late,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: s.exportPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: onExport,
                ),
                IconButton(
                  tooltip: s.delete,
                  icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- features/incidents/presentation/utils/incident_export.dart ---
/// يولّد تقرير الحادث عبر PdfService ويفتح نافذة التصدير
/// (معاينة وطباعة / حفظ / مشاركة). يُستعمل بعد الحفظ وكذلك من القائمة.
Future<void> exportIncidentPdf(
  BuildContext context,
  WidgetRef ref,
  IncidentModel incident,
) async {
  final s = AppStrings.of(context);
  final lang = Localizations.localeOf(context).languageCode;

  await runGuarded(context, () async {
    final student = await ref
        .read(studentsRepositoryProvider)
        .getStudentById(incident.studentId);
    final cls =
        await ref.read(classesRepositoryProvider).getClassById(incident.classId);
    final teacher =
        await ref.read(teachersRepositoryProvider).getDefaultTeacher();

    if (student == null) throw StateError('Student ${incident.studentId} not found');
    if (!context.mounted) return;

    final data = IncidentReportData(
      languageCode: lang,
      schoolName: teacher.schoolName,
      teacherName: teacher.displayName,
      className: cls?.name ?? '',
      student: student,
      incident: incident,
    );

    final d = incident.incidentDate;
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');

    await ExportBottomSheet.show(
      context,
      title: s.incidentReport,
      fileName: 'incident_${student.lastName}_${d.year}$mm$dd',
      buildPdf: () => PdfService.instance.buildIncidentReport(data),
    );
  });
}

// --- features/settings/presentation/utils/backup_actions.dart ---
void _snack(BuildContext context, String text, {int seconds = 4}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: Duration(seconds: seconds)));
}

/// «نسخة احتياطية»: مشاركة (printing) أو حفظ في الهاتف (path_provider).
Future<void> showBackupOptions(BuildContext context, WidgetRef ref) async {
  final s = AppStrings.of(context);

  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: Text(s.shareBackup),
            onTap: () => Navigator.pop(ctx, 'share'),
          ),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: Text(s.saveToPhone),
            onTap: () => Navigator.pop(ctx, 'save'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  await runGuarded(context, () async {
    final service = ref.read(backupServiceProvider);
    if (choice == 'share') {
      final file = await service.createBackupFile();
      // printing هي مكتبة المشاركة الوحيدة المتبقية (share_plus محذوفة).
      final bytes = await file.readAsBytes();
      await Printing.sharePdf(
        bytes: bytes,
        filename: file.path.split(Platform.pathSeparator).last,
      );
    } else {
      final file = await service.saveBackupToPhone();
      if (!context.mounted) return;
      _snack(context, '${s.savedTo} ${file.path}', seconds: 8);
    }
  });
}

/// «استعادة»: اختيار ملف قاعدة بيانات (file_picker) واستبدال البيانات الحالية.
Future<void> restoreBackup(BuildContext context, WidgetRef ref) async {
  final s = AppStrings.of(context);

  final picked = await FilePicker.platform.pickFiles(type: FileType.any);
  final path = picked?.files.single.path;
  if (path == null || !context.mounted) return;

  final ok = await confirmAction(
    context,
    title: s.restoreConfirmTitle,
    message: s.restoreConfirmMessage,
    confirmLabel: s.restore,
  );
  if (!ok || !context.mounted) return;

  try {
    await ref.read(backupServiceProvider).restoreFrom(File(path));

    // إعادة تحميل كل ما كان مقروءاً من القاعدة القديمة
    ref.invalidate(classesProvider);
    ref.invalidate(incidentsProvider);
    ref.invalidate(teacherProvider);

    if (context.mounted) _snack(context, s.restoreDone);
  } on BackupException catch (e) {
    if (!context.mounted) return;
    _snack(
      context,
      e.reason == BackupFailure.newerVersion ? s.restoreNewer : s.restoreInvalid,
    );
  } catch (e, st) {
    debugPrint('Restore failed: $e\n$st');
    if (context.mounted) _snack(context, s.errorGeneric);
  }
}

// ==========================================================================
// === SCREENS ===
// ==========================================================================

// --- features/shell/presentation/pages/splash_screen.dart ---
/// شاشة البداية: شعار (كرة قدم) ثم انتقال تلقائي:
/// إلى شاشة PIN إن كان القفل مفعّلاً، وإلا إلى الشاشة الرئيسية.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _splashDuration = Duration(milliseconds: 2200);

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _timer = Timer(_splashDuration, _next);
  }

  static Route<void> _fadeRoute(Widget page) => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  void _next() {
    if (!mounted) return;
    final locked = ref.read(pinServiceProvider).isEnabled;

    final Widget destination = locked
        ? PinLockScreen(
            onSuccess: (ctx) =>
                Navigator.of(ctx).pushReplacement(_fadeRoute(const MainScreen())),
          )
        : const MainScreen();

    Navigator.of(context).pushReplacement(_fadeRoute(destination));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = AppStrings.of(context).appName;

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sports_soccer,
                    size: 80,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- features/shell/presentation/pages/main_screen.dart ---
/// الشاشة الرئيسية: شريط سفلي بأربعة تبويبات.
/// IndexedStack يُبقي كل صفحة حيّة، فلا تفقد حالتها عند التنقل.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const List<Widget> _pages = [
    TimetableScreen(),
    ClassesScreen(),
    LessonPlansScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_view_week_outlined),
            activeIcon: const Icon(Icons.calendar_view_week),
            label: s.timetable,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.groups_outlined),
            activeIcon: const Icon(Icons.groups),
            label: s.classes,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.description_outlined),
            activeIcon: const Icon(Icons.description),
            label: s.lessonPlans,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: s.settings,
          ),
        ],
      ),
    );
  }
}

// --- features/timetable/presentation/pages/timetable_screen.dart ---
/// شاشة مؤقتة — ستُبنى تفاصيلها في خطوة لاحقة.
class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final title = AppStrings.of(context).timetable;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}

// --- features/classes/presentation/pages/classes_screen.dart ---
/// التبويب الثاني: قائمة الأقسام (من SQLite عبر classesProvider).
class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final state = ref.watch(classesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.classes),
        actions: [
          IconButton(
            tooltip: s.incidents,
            icon: const Icon(Icons.healing_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const IncidentsScreen()),
            ),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorView(
          message: s.errorGeneric,
          retryLabel: s.retry,
          onRetry: () =>
              ref.read(classesProvider.notifier).load(showLoading: true),
        ),
        data: (classes) {
          if (classes.isEmpty) {
            return EmptyState(
              icon: Icons.groups_outlined,
              title: s.noClasses,
              subtitle: s.noClassesHint,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), // مساحة للـ FAB
            itemCount: classes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final c = classes[i];
              return ClassCard(
                classModel: c,
                onManageStudents: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StudentsScreen(classModel: c),
                  ),
                ),
                onAttendance: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AttendanceScreen(classModel: c),
                  ),
                ),
                onEdit: () => _edit(context, ref, c),
                onDelete: () => _delete(context, ref, c),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: Text(s.addClass),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result = await ClassFormDialog.show(context);
    if (result == null || !context.mounted) return;
    await runGuarded(context, () => ref.read(classesProvider.notifier).add(result));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, ClassModel c) async {
    final result = await ClassFormDialog.show(context, initial: c);
    if (result == null || !context.mounted) return;
    await runGuarded(context, () => ref.read(classesProvider.notifier).edit(result));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ClassModel c) async {
    final s = AppStrings.of(context);
    final ok = await confirmDelete(
      context,
      title: s.deleteClassTitle,
      message: s.deleteClassMessage(c.name),
    );
    if (!ok || !context.mounted) return;
    await runGuarded(context, () => ref.read(classesProvider.notifier).remove(c.id!));
  }
}

// --- features/classes/presentation/pages/students_screen.dart ---
/// قائمة تلاميذ قسم واحد فقط (من SQLite عبر studentsProvider(classId)).
class StudentsScreen extends ConsumerWidget {
  const StudentsScreen({super.key, required this.classModel});
  final ClassModel classModel;

  int get _classId => classModel.id!;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final state = ref.watch(studentsProvider(_classId));

    return Scaffold(
      appBar: AppBar(title: Text('${s.students} — ${classModel.name}')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorView(
          message: s.errorGeneric,
          retryLabel: s.retry,
          onRetry: () => ref
              .read(studentsProvider(_classId).notifier)
              .load(showLoading: true),
        ),
        data: (students) {
          if (students.isEmpty) {
            return EmptyState(
              icon: Icons.person_add_alt_1_outlined,
              title: s.noStudents,
              subtitle: s.noStudentsHint,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _StudentTile(
              student: students[i],
              index: i + 1,
              onEdit: () => _edit(context, ref, students[i]),
              onDelete: () => _delete(context, ref, students[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.person_add),
        label: Text(s.addStudent),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result = await StudentFormDialog.show(context, classId: _classId);
    if (result == null || !context.mounted) return;
    await runGuarded(
        context, () => ref.read(studentsProvider(_classId).notifier).add(result));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, StudentModel st) async {
    final result =
        await StudentFormDialog.show(context, classId: _classId, initial: st);
    if (result == null || !context.mounted) return;
    await runGuarded(
        context, () => ref.read(studentsProvider(_classId).notifier).edit(result));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, StudentModel st) async {
    final s = AppStrings.of(context);
    final ok = await confirmDelete(
      context,
      title: s.deleteStudentTitle,
      message: s.deleteStudentMessage(st.fullName),
    );
    if (!ok || !context.mounted) return;
    await runGuarded(
        context, () => ref.read(studentsProvider(_classId).notifier).remove(st.id!));
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.student,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  final StudentModel student;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Text('$index'),
        ),
        title: Text(student.fullName),
        subtitle: Text(s.genderLabel(student.gender.name)),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text(s.edit)),
            PopupMenuItem(value: 'delete', child: Text(s.delete)),
          ],
        ),
      ),
    );
  }
}

// --- features/classes/presentation/pages/attendance_screen.dart ---
/// شاشة النداء الميداني: حالة كل تلميذ تُحفظ في SQLite فور تغييرها.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key, required this.classModel});
  final ClassModel classModel;

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  AttendanceArgs get _args =>
      AttendanceArgs(classId: widget.classModel.id!, date: _date);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _setAllPresent() async {
    final s = AppStrings.of(context);
    final data = ref.read(attendanceProvider(_args)).valueOrNull;
    if (data == null || data.students.isEmpty) return;

    // نطلب التأكيد فقط إذا كانت هناك حالات (غياب، تأخر...) ستُستبدل.
    if (data.hasNonPresent) {
      final ok = await confirmAction(
        context,
        title: s.setAllTitle,
        message: s.setAllMessage,
        confirmLabel: s.confirm,
      );
      if (!ok || !mounted) return;
    }
    await runGuarded(
        context, () => ref.read(attendanceProvider(_args).notifier).setAllPresent());
  }

  /// تصدير كشف الحضور الحالي كـ PDF.
  Future<void> _export() async {
    final data = ref.read(attendanceProvider(_args)).valueOrNull;
    if (data == null) return;
    final s = AppStrings.of(context);
    final lang = Localizations.localeOf(context).languageCode;

    await runGuarded(context, () async {
      final teacher =
          await ref.read(teachersRepositoryProvider).getDefaultTeacher();
      if (!mounted) return;

      final sheet = AttendanceSheetData(
        languageCode: lang,
        schoolName: teacher.schoolName,
        teacherName: teacher.displayName,
        classModel: widget.classModel,
        date: _date,
        students: data.students,
        statuses: data.statuses,
      );
      final mm = _date.month.toString().padLeft(2, '0');
      final dd = _date.day.toString().padLeft(2, '0');

      await ExportBottomSheet.show(
        context,
        title: s.attendanceSheet,
        fileName: 'attendance_${widget.classModel.name}_${_date.year}$mm$dd',
        buildPdf: () => PdfService.instance.buildAttendanceSheet(sheet),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final state = ref.watch(attendanceProvider(_args));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${s.attendance} — ${widget.classModel.name}'),
            Text(
              MaterialLocalizations.of(context).formatFullDate(_date),
              style: const TextStyle(
                  fontSize: 12, color: Colors.white70, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: s.exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: state.hasValue ? _export : null,
          ),
          IconButton(
            tooltip: s.date,
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorView(
          message: s.errorGeneric,
          retryLabel: s.retry,
          onRetry: () =>
              ref.read(attendanceProvider(_args).notifier).load(showLoading: true),
        ),
        data: (d) => Column(
          children: [
            AttendanceSummaryHeader(
              present: d.presentCount,
              absent: d.absentCount,
              total: d.total,
              onSetAllPresent: d.students.isEmpty ? null : _setAllPresent,
            ),
            Expanded(
              child: d.students.isEmpty
                  ? EmptyState(
                      icon: Icons.person_add_alt_1_outlined,
                      title: s.noStudents,
                      subtitle: s.noStudentsHint,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      itemCount: d.students.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final st = d.students[i];
                        return StudentAttendanceTile(
                          index: i + 1,
                          student: st,
                          status: d.statuses[st.id],
                          onChanged: (status) => runGuarded(
                            context,
                            () => ref
                                .read(attendanceProvider(_args).notifier)
                                .setStatus(st.id!, status),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- features/incidents/presentation/pages/incidents_screen.dart ---
/// قائمة الحوادث المسجَّلة (من جدول incidents).
class IncidentsScreen extends ConsumerWidget {
  const IncidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final state = ref.watch(incidentsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.incidents)),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorView(
          message: s.errorGeneric,
          retryLabel: s.retry,
          onRetry: () =>
              ref.read(incidentsProvider.notifier).load(showLoading: true),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.healing_outlined,
              title: s.noIncidents,
              subtitle: s.noIncidentsHint,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final item = items[i];
              return IncidentCard(
                item: item,
                onExport: () => exportIncidentPdf(context, ref, item.incident),
                onDelete: () => _delete(context, ref, item),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<bool>(builder: (_) => const IncidentFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text(s.addIncident),
      ),
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, IncidentListItem item) async {
    final s = AppStrings.of(context);
    final ok = await confirmDelete(
      context,
      title: s.deleteIncidentTitle,
      message: s.deleteIncidentMessage(item.studentName),
    );
    if (!ok || !context.mounted) return;
    await runGuarded(
      context,
      () => ref.read(incidentsProvider.notifier).remove(item.incident.id!),
    );
  }
}

// --- features/incidents/presentation/pages/incident_form_screen.dart ---
/// نموذج تسجيل حادث. يُحفظ السجل في SQLite ثم يُولَّد تقرير PDF ويُعرض للتصدير.
class IncidentFormScreen extends ConsumerStatefulWidget {
  const IncidentFormScreen({super.key});

  @override
  ConsumerState<IncidentFormScreen> createState() => _IncidentFormScreenState();
}

class _IncidentFormScreenState extends ConsumerState<IncidentFormScreen> {
  /// رموز جاهزة (تُترجم عند العرض). «other» = نص حرّ.
  static const _locationPresets = ['outdoor', 'gym', 'yard'];
  static const _injuryPresets = [
    'bruise', 'sprain', 'fracture', 'cut', 'dislocation', 'strain', 'head', 'faint',
  ];
  static const _other = 'other';

  final _formKey = GlobalKey<FormState>();

  int? _classId;
  int? _studentId;
  late DateTime _dateTime;

  String? _location; // رمز جاهز أو 'other'
  final _locationOther = TextEditingController();

  String? _injury; // رمز جاهز أو 'other'
  final _injuryOther = TextEditingController();

  IncidentSeverity _severity = IncidentSeverity.minor;
  final _description = TextEditingController();
  final _firstAid = TextEditingController();

  bool _parentNotified = false;
  final _parentNote = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dateTime = DateTime.now();
  }

  @override
  void dispose() {
    _locationOther.dispose();
    _injuryOther.dispose();
    _description.dispose();
    _firstAid.dispose();
    _parentNote.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ التاريخ والوقت

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _dateTime = DateTime(
        picked.year, picked.month, picked.day, _dateTime.hour, _dateTime.minute));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (picked == null || !mounted) return;
    setState(() => _dateTime = DateTime(_dateTime.year, _dateTime.month,
        _dateTime.day, picked.hour, picked.minute));
  }

  // ------------------------------------------------------------------- الحفظ

  String _resolve(String? preset, TextEditingController other) =>
      preset == _other ? other.text.trim() : (preset ?? '');

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    IncidentModel? saved;
    await runGuarded(context, () async {
      final note = _parentNote.text.trim();
      final incident = IncidentModel(
        studentId: _studentId!,
        classId: _classId!,
        incidentDate: _dateTime,
        type: _resolve(_injury, _injuryOther),
        severity: _severity,
        location: _resolve(_location, _locationOther),
        description: _description.text.trim(),
        actionTaken:
            _firstAid.text.trim().isEmpty ? null : _firstAid.text.trim(),
        parentNotified: _parentNotified,
        parentNotificationNote: (_parentNotified && note.isNotEmpty) ? note : null,
        createdAt: DateTime.now(),
      );
      // 1) كتابة السجل في SQLite
      final id = await ref.read(incidentsProvider.notifier).add(incident);
      saved = incident.copyWith(id: id);
    });

    final result = saved;
    if (!mounted) return;
    if (result == null) {
      setState(() => _saving = false); // فشل الحفظ: نبقى في النموذج
      return;
    }

    // 2) توليد تقرير PDF وعرض نافذة التصدير (السجل محفوظ مسبقاً)
    await exportIncidentPdf(context, ref, result);
    if (mounted) Navigator.of(context).pop(true);
  }

  // ------------------------------------------------------------------ الواجهة

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final loc = MaterialLocalizations.of(context);

    final classes = ref.watch(classesProvider).valueOrNull ?? const [];
    final students = _classId == null
        ? const <StudentModel>[]
        : (ref.watch(studentsProvider(_classId!)).valueOrNull ??
            const <StudentModel>[]);

    return Scaffold(
      appBar: AppBar(title: Text(s.newIncident)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (classes.isEmpty)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Icon(Icons.info_outline,
                        color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(s.needClassFirst,
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer)),
                    ),
                  ]),
                ),
              ),

            // ---- القسم
            _label(s.classLabel),
            DropdownButtonFormField<int>(
              // ignore: deprecated_member_use
              value: _classId,
              isExpanded: true,
              hint: Text(s.chooseClass),
              items: [
                for (final c in classes)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: classes.isEmpty
                  ? null
                  : (v) => setState(() {
                        _classId = v;
                        _studentId = null; // قائمة التلاميذ تتغير مع القسم
                      }),
              validator: (v) => v == null ? s.required : null,
            ),
            const SizedBox(height: 16),

            // ---- التلميذ المصاب (يتغير حسب القسم)
            _label(s.injuredStudent),
            DropdownButtonFormField<int>(
              // ignore: deprecated_member_use
              value: _studentId,
              isExpanded: true,
              hint: Text(_classId != null && students.isEmpty
                  ? s.noStudents
                  : s.chooseStudent),
              items: [
                for (final st in students)
                  DropdownMenuItem(value: st.id, child: Text(st.fullName)),
              ],
              onChanged: students.isEmpty
                  ? null
                  : (v) => setState(() => _studentId = v),
              validator: (v) => v == null ? s.required : null,
            ),
            const SizedBox(height: 16),

            // ---- التاريخ والوقت
            _label(s.dateTime),
            Row(children: [
              Expanded(
                child: _PickerField(
                  icon: Icons.calendar_month,
                  text: loc.formatMediumDate(_dateTime),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickerField(
                  icon: Icons.access_time,
                  text: loc.formatTimeOfDay(TimeOfDay.fromDateTime(_dateTime)),
                  onTap: _pickTime,
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ---- المكان
            _label(s.incidentLocation),
            _chipsField(
              presets: _locationPresets,
              labelOf: s.placeLabel,
              selected: _location,
              onSelected: (v) => setState(() => _location = v),
              requiredMessage: s.required,
              otherLabel: s.other,
            ),
            if (_location == _other) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationOther,
                decoration: InputDecoration(labelText: s.specify),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? s.required : null,
              ),
            ],
            const SizedBox(height: 16),

            // ---- طبيعة الإصابة
            _label(s.injuryNature),
            _chipsField(
              presets: _injuryPresets,
              labelOf: s.injuryLabel,
              selected: _injury,
              onSelected: (v) => setState(() => _injury = v),
              requiredMessage: s.required,
              otherLabel: s.other,
            ),
            if (_injury == _other) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _injuryOther,
                decoration: InputDecoration(labelText: s.specify),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? s.required : null,
              ),
            ],
            const SizedBox(height: 16),

            // ---- درجة الخطورة
            _label(s.severityTitle),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final sev in IncidentSeverity.values)
                ChoiceChip(
                  label: Text(s.severityLabel(sev.name)),
                  selected: _severity == sev,
                  onSelected: (_) => setState(() => _severity = sev),
                ),
            ]),
            const SizedBox(height: 16),

            // ---- وصف الحادث (اختياري)
            _label('${s.incidentDescription} (${s.optionalHint})'),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),

            // ---- الإسعافات الأولية
            _label(s.firstAid),
            TextFormField(
              controller: _firstAid,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(hintText: s.firstAidHint),
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 8),

            // ---- إشعار الولي
            Card(
              child: Column(children: [
                SwitchListTile(
                  title: Text(s.parentNotification),
                  subtitle: Text(
                      _parentNotified ? s.parentNotified : s.parentNotNotified),
                  secondary: Icon(
                    _parentNotified
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    color: _parentNotified
                        ? context.attendanceColors.present
                        : null,
                  ),
                  value: _parentNotified,
                  onChanged: (v) => setState(() => _parentNotified = v),
                ),
                if (_parentNotified)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: TextFormField(
                      controller: _parentNote,
                      decoration: InputDecoration(hintText: s.parentNoteHint),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 24),

            // ---- حفظ التقرير
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(s.saveReport),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );

  /// أزرار اختيار (Chips) مع خيار «أخرى» ورسالة خطأ عند عدم الاختيار.
  Widget _chipsField({
    required List<String> presets,
    required String Function(String) labelOf,
    required String? selected,
    required ValueChanged<String> onSelected,
    required String requiredMessage,
    required String otherLabel,
  }) {
    return FormField<String>(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (_) => selected == null ? requiredMessage : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in [...presets, _other])
              ChoiceChip(
                label: Text(p == _other ? otherLabel : labelOf(p)),
                selected: selected == p,
                onSelected: (_) {
                  onSelected(p);
                  field.didChange(p);
                },
              ),
          ]),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12, right: 12),
              child: Text(
                field.errorText!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// حقل بشكل TextField يفتح منتقياً عند النقر (للتاريخ والوقت).
class _PickerField extends StatelessWidget {
  const _PickerField({required this.icon, required this.text, required this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(prefixIcon: Icon(icon)),
        child: Text(text, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

// --- features/lesson_plans/presentation/pages/lesson_plans_screen.dart ---
/// شاشة مؤقتة — ستُبنى تفاصيلها في خطوة لاحقة.
class LessonPlansScreen extends StatelessWidget {
  const LessonPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final title = AppStrings.of(context).lessonPlans;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}

// --- features/settings/presentation/pages/settings_screen.dart ---
/// التبويب الرابع: بيانات الأستاذ، المظهر واللغة، قفل PIN، النسخ الاحتياطي، الترخيص.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final pinEnabled = ref.watch(pinEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- بيانات الأستاذ
          _Section(
            icon: Icons.person_outline,
            title: s.teacherData,
            child: const _TeacherForm(),
          ),

          // ---- المظهر واللغة
          _Section(
            icon: Icons.palette_outlined,
            title: s.appearance,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode_outlined),
                        label: Text(s.themeLight),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode_outlined),
                        label: Text(s.themeDark),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: const Icon(Icons.brightness_auto_outlined),
                        label: Text(s.themeSystem),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (v) =>
                        ref.read(themeModeProvider.notifier).setMode(v.first),
                  ),
                ),
                const SizedBox(height: 16),
                Text(s.language, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'ar', label: Text('العربية')),
                      ButtonSegment(value: 'fr', label: Text('Français')),
                    ],
                    selected: {locale.languageCode == 'fr' ? 'fr' : 'ar'},
                    onSelectionChanged: (v) =>
                        ref.read(localeProvider.notifier).setLanguage(v.first),
                  ),
                ),
              ],
            ),
          ),

          // ---- الأمان
          _Section(
            icon: Icons.lock_outline,
            title: s.security,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.pinLock),
              subtitle: Text(s.pinLockSubtitle),
              value: pinEnabled,
              onChanged: (v) => _togglePin(context, ref, v),
            ),
          ),

          // ---- النسخ الاحتياطي والاستعادة
          _Section(
            icon: Icons.backup_outlined,
            title: s.backupRestore,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: Text(s.backup),
                  subtitle: Text(s.backupSubtitle),
                  onTap: () => showBackupOptions(context, ref),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.settings_backup_restore),
                  title: Text(s.restore),
                  subtitle: Text(s.restoreSubtitle),
                  onTap: () => restoreBackup(context, ref),
                ),
              ],
            ),
          ),

          // ---- الترخيص
          _Section(
            icon: Icons.verified_outlined,
            title: s.license,
            child: const _LicenseInfo(),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePin(BuildContext context, WidgetRef ref, bool enable) async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (enable) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(builder: (_) => const PinSetupScreen()),
      );
      if (ok == true) {
        ref.read(pinEnabledProvider.notifier).state = true;
        messenger.showSnackBar(SnackBar(content: Text(s.pinEnabledMsg)));
      }
    } else {
      // التحقق من الرمز الحالي قبل الإيقاف
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => PinLockScreen(
            title: s.pinVerifyToDisable,
            allowBack: true,
            onSuccess: (ctx) => Navigator.of(ctx).pop(true),
          ),
        ),
      );
      if (ok == true) {
        await ref.read(pinServiceProvider).disable();
        ref.read(pinEnabledProvider.notifier).state = false;
        messenger.showSnackBar(SnackBar(content: Text(s.pinDisabledMsg)));
      }
    }
  }
}

/// بطاقة قسم في الإعدادات.
class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ]),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- بيانات الأستاذ

class _TeacherForm extends ConsumerWidget {
  const _TeacherForm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    return ref.watch(teacherProvider).when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => ErrorView(
            message: s.errorGeneric,
            retryLabel: s.retry,
            onRetry: () => ref.read(teacherProvider.notifier).load(),
          ),
          data: (t) => _TeacherFormBody(teacher: t),
        );
  }
}

class _TeacherFormBody extends ConsumerStatefulWidget {
  const _TeacherFormBody({required this.teacher});
  final TeacherModel teacher;

  @override
  ConsumerState<_TeacherFormBody> createState() => _TeacherFormBodyState();
}

class _TeacherFormBodyState extends ConsumerState<_TeacherFormBody> {
  late final TextEditingController _lastName;
  late final TextEditingController _firstName;
  late final TextEditingController _school;
  late final TextEditingController _rank;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.teacher;
    _lastName = TextEditingController(text: t.lastName);
    _firstName = TextEditingController(text: t.firstName);
    _school = TextEditingController(text: t.schoolName);
    _rank = TextEditingController(text: t.rank);
  }

  @override
  void dispose() {
    _lastName.dispose();
    _firstName.dispose();
    _school.dispose();
    _rank.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _saving = true);
    var ok = true;
    await runGuarded(context, () async {
      try {
        final updated = widget.teacher.copyWith(
          lastName: _lastName.text.trim(),
          firstName: _firstName.text.trim(),
          schoolName: _school.text.trim(),
          rank: _rank.text.trim(),
        );
        await ref.read(teacherProvider.notifier).save(updated);
      } catch (_) {
        ok = false;
        rethrow;
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.saved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Column(
      children: [
        TextField(
          controller: _lastName,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: s.lastName),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _firstName,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: s.firstName),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _school,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: s.schoolName),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _rank,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: s.rank),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(s.save),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- الترخيص

class _LicenseInfo extends ConsumerWidget {
  const _LicenseInfo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final license = ref.watch(licenseServiceProvider);

    final total = LicenseService.trialDays;
    final used = license.daysUsed > total ? total : license.daysUsed;
    final expired = license.isTrialExpired;
    final started =
        MaterialLocalizations.of(context).formatMediumDate(license.firstRunAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.trialPeriod(total),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: used / total,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          color: expired ? theme.colorScheme.error : theme.colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          expired ? s.trialExpired : s.trialRemaining(license.daysRemaining),
          style: TextStyle(
            color: expired ? theme.colorScheme.error : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.trialStarted(started),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// --- features/security/presentation/pages/pin_lock_screen.dart ---
/// شاشة طلب رمز PIN. عند النجاح تُستدعى [onSuccess] (مثلاً الانتقال للرئيسية
/// عند فتح التطبيق، أو الرجوع بـ true عند التحقق قبل إيقاف القفل).
/// بعد 5 محاولات خاطئة تُقفل اللوحة 30 ثانية.
class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({
    super.key,
    required this.onSuccess,
    this.title,
    this.allowBack = false,
  });

  final void Function(BuildContext context) onSuccess;
  final String? title;
  final bool allowBack;

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  static const _maxAttempts = 5;
  static const _lockDuration = Duration(seconds: 30);

  int _failures = 0;
  DateTime? _lockedUntil;
  int _secondsLeft = 0;
  String? _error;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onPin(String pin) {
    if (ref.read(pinServiceProvider).verify(pin)) {
      widget.onSuccess(context);
      return;
    }
    final s = AppStrings.of(context);
    _failures++;
    if (_failures >= _maxAttempts) {
      _failures = 0;
      _lockedUntil = DateTime.now().add(_lockDuration);
      _tick();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else {
      setState(() => _error = s.pinWrong);
    }
  }

  void _tick() {
    final until = _lockedUntil;
    if (until == null) return;
    final ms = until.difference(DateTime.now()).inMilliseconds;
    if (ms <= 0) {
      _timer?.cancel();
      setState(() {
        _lockedUntil = null;
        _error = null;
      });
    } else {
      setState(() => _secondsLeft = (ms / 1000).ceil());
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final locked = _lockedUntil != null;
    final message = locked ? s.pinTooMany(_secondsLeft) : _error;

    return PopScope(
      canPop: widget.allowBack,
      child: Scaffold(
        appBar: widget.allowBack ? AppBar(title: Text(s.pinLock)) : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline,
                      size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(widget.title ?? s.pinEnter,
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 24,
                    child: message == null
                        ? null
                        : Text(message,
                            style: TextStyle(color: theme.colorScheme.error)),
                  ),
                  const SizedBox(height: 16),
                  PinPad(enabled: !locked, onCompleted: _onPin),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- features/security/presentation/pages/pin_setup_screen.dart ---
/// إنشاء رمز PIN جديد: إدخال ثم تأكيد. تُرجع true عند النجاح.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String? _first; // الإدخال الأول (null = المرحلة الأولى)
  String? _error;

  Future<void> _onPin(String pin) async {
    final s = AppStrings.of(context);

    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
      return;
    }
    if (pin != _first) {
      setState(() {
        _first = null;
        _error = s.pinMismatch;
      });
      return;
    }
    await ref.read(pinServiceProvider).setPin(pin);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.pinLock)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pin_outlined,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  _first == null ? s.pinCreate : s.pinConfirm,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 24,
                  child: _error == null
                      ? null
                      : Text(_error!,
                          style: TextStyle(color: theme.colorScheme.error)),
                ),
                const SizedBox(height: 16),
                PinPad(onCompleted: _onPin),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// === APP ENTRY POINT ===
// ==========================================================================

// --- main.dart ---
/// نقطة الدخول: تهيئة SharedPreferences، تسجيل أول تشغيل (الفترة التجريبية)،
/// ثم تغليف التطبيق بـ ProviderScope.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await LicenseService(prefs).ensureStarted();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const EpsAssistantApp(),
    ),
  );
}

class EpsAssistantApp extends ConsumerWidget {
  const EpsAssistantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppStrings.of(context).appName,

      // السمات
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,

      // اللغات: الاتجاه (RTL/LTR) يُضبط تلقائياً حسب اللغة (ar ← RTL).
      locale: locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const SplashScreen(),
    );
  }
}
