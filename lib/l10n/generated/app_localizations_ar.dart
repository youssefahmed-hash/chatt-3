// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'شات';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get save => 'حفظ';

  @override
  String get back => 'رجوع';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get loading => 'جارِ التحميل...';

  @override
  String get error => 'خطأ';

  @override
  String get success => 'تم بنجاح';

  @override
  String get today => 'اليوم';

  @override
  String get yesterday => 'أمس';

  @override
  String get search => 'بحث';

  @override
  String get send => 'إرسال';

  @override
  String get close => 'إغلاق';

  @override
  String get chats => 'المحادثات';

  @override
  String chatsWithUser(String name) {
    return 'المحادثات · $name';
  }

  @override
  String get searchChatsHint => 'ابحث في المحادثات...';

  @override
  String get noChatsYet => 'لا توجد محادثات بعد. اضغط على الزر لبدء محادثة.';

  @override
  String get couldNotLoadChats => 'تعذّر تحميل المحادثات';

  @override
  String get startNewChat => 'ابدأ محادثة جديدة';

  @override
  String get noOtherUsersYet => 'لا يوجد مستخدمون آخرون بعد.';

  @override
  String get newGroup => 'مجموعة جديدة';

  @override
  String get starredMessages => 'الرسائل المميزة';

  @override
  String get callHistory => 'سجل المكالمات';

  @override
  String get archivedChats => 'المحادثات المؤرشفة';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get settings => 'الإعدادات';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get logoutConfirm => 'هل أنت متأكد من تسجيل الخروج؟';

  @override
  String get group_ => 'مجموعة';

  @override
  String get reply => 'رد';

  @override
  String get forward => 'إعادة توجيه';

  @override
  String get star => 'تمييز';

  @override
  String get unstar => 'إلغاء التمييز';

  @override
  String get pin => 'تثبيت';

  @override
  String get unpin => 'إلغاء التثبيت';

  @override
  String get pinChat => 'تثبيت المحادثة';

  @override
  String get unpinChat => 'إلغاء تثبيت المحادثة';

  @override
  String get pinnedChat => 'مثبّتة';

  @override
  String get edit => 'تعديل';

  @override
  String get deleteMessage => 'حذف الرسالة';

  @override
  String get deleteMessageConfirm => 'هل أنت متأكد أنك تريد حذف هذه الرسالة؟';

  @override
  String get forwardedLabel => 'معاد توجيهها';

  @override
  String get editedLabel => 'معدّلة';

  @override
  String get typeMessageHint => 'اكتب رسالة...';

  @override
  String get editingMessage => 'جارٍ تعديل الرسالة';

  @override
  String get sendMessage => 'إرسال الرسالة';

  @override
  String get attach => 'إرفاق';

  @override
  String get attachImage => 'صورة';

  @override
  String get attachVideo => 'فيديو';

  @override
  String get attachFile => 'ملف';

  @override
  String get connectionLost =>
      'انقطع الاتصال. سيتم إرسال رسائلك تلقائيًا عند عودة الاتصال.';

  @override
  String get messagesWillBeSent =>
      'لا يوجد اتصال بالإنترنت. تم حفظ الرسالة وستُرسل تلقائيًا.';

  @override
  String get sendFailed => 'تعذّر إرسال الرسالة.';

  @override
  String get pinnedMessages => 'الرسائل المثبّتة';

  @override
  String get noPinnedMessages => 'لا توجد رسائل مثبّتة بعد.';

  @override
  String get noMessagesYet => 'لا توجد رسائل بعد. ابدأ بالتحية!';

  @override
  String get voiceCall => 'مكالمة صوتية';

  @override
  String get videoCall => 'مكالمة فيديو';

  @override
  String get callRejectedLabel => 'تم رفض المكالمة';

  @override
  String get calls => 'المكالمات';

  @override
  String get noCallsYet => 'لا توجد مكالمات بعد.';

  @override
  String get searchMessagesHint => 'ابحث في الرسائل';

  @override
  String get noSearchResults => 'لا توجد نتائج.';

  @override
  String get recordingCancelHint => 'اسحب للإلغاء';

  @override
  String get recordingSendHint => 'اسحب للإرسال';

  @override
  String get recordingPaused => 'متوقف مؤقتًا';

  @override
  String get recording => 'جارٍ التسجيل...';

  @override
  String get startRecording => 'اضغط باستمرار للتسجيل';

  @override
  String get appearance => 'المظهر';

  @override
  String get light => 'فاتح';

  @override
  String get dark => 'داكن';

  @override
  String get systemDefault => 'افتراضي النظام';

  @override
  String get theme => 'الثيم';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get account => 'الحساب';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get confirmNewPassword => 'تأكيد كلمة المرور الجديدة';

  @override
  String get show => 'إظهار';

  @override
  String get hide => 'إخفاء';

  @override
  String get passwordMismatch => 'كلمتا المرور غير متطابقتين.';

  @override
  String get passwordTooShort => 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.';

  @override
  String get passwordRequired => 'كلمة المرور مطلوبة.';

  @override
  String get currentPasswordWrong => 'كلمة المرور الحالية غير صحيحة.';

  @override
  String get passwordChangedSuccess => 'تم تغيير كلمة المرور بنجاح.';

  @override
  String get passwordChangeError => 'تعذّر تغيير كلمة المرور. حاول مرة أخرى.';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get loginFailed => 'فشل تسجيل الدخول. تحقق من البيانات.';

  @override
  String get register => 'تسجيل';

  @override
  String get name => 'الاسم';

  @override
  String get serverDomain => 'السيرفر (اختياري)';

  @override
  String get verifyOtp => 'تحقق';

  @override
  String get otpSent => 'أدخل الرمز المرسل إلى بريدك';

  @override
  String get otpInvalid => 'الرمز غير صحيح. حاول مرة أخرى.';

  @override
  String get resendOtp => 'إعادة إرسال الرمز';

  @override
  String get download => 'تنزيل';

  @override
  String get downloading => 'جارٍ التنزيل...';

  @override
  String downloadSuccess(String path) {
    return 'تم الحفظ: $path';
  }

  @override
  String get savedToGallery => 'تم الحفظ في المعرض.';

  @override
  String get downloadFailed => 'فشل التنزيل. حاول مرة أخرى.';

  @override
  String get saveButton => 'حفظ';

  @override
  String get newMessageNotificationTitle => 'رسالة جديدة';

  @override
  String get photoNotification => '📷 صورة';

  @override
  String get voiceNotification => '🎤 رسالة صوتية';

  @override
  String get fileNotification => '📎 ملف';

  @override
  String get videoNotification => '🎬 فيديو';

  @override
  String get videoCallNotification => '📹 مكالمة فيديو';

  @override
  String get voiceCallNotification => '📞 مكالمة صوتية';

  @override
  String get channelDescription => 'رسائل المحادثة الجديدة';

  @override
  String get channelName => 'رسائل المحادثة';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get bio => 'السيرة الذاتية';

  @override
  String get noArchivedChats => 'لا توجد محادثات مؤرشفة';

  @override
  String get noConversationsYet => 'لا توجد محادثات بعد';

  @override
  String get noStarredMessages => 'لا توجد رسائل مميزة بعد';

  @override
  String get videoCouldNotLoad => 'تعذّر تحميل الفيديو';

  @override
  String get unknown => 'غير معروف';

  @override
  String get outgoingCall => 'صادرة';

  @override
  String get incomingCall => 'واردة';

  @override
  String get missedCall => 'مفقودة';

  @override
  String get rejectedCall => 'مرفوضة';

  @override
  String get recordingPermissionDenied => 'تم رفض إذن التسجيل';

  @override
  String get imageUploadedSuccess => 'تم رفع الصورة بنجاح';

  @override
  String get messageDeletedSuccess => 'تم حذف الرسالة بنجاح';

  @override
  String get messageGeneric => 'رسالة';

  @override
  String get searchInChat => 'ابحث في المحادثة';
}
