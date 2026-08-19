import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Chatt'**
  String get appName;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @chatsWithUser.
  ///
  /// In en, this message translates to:
  /// **'Chats · {name}'**
  String chatsWithUser(String name);

  /// No description provided for @searchChatsHint.
  ///
  /// In en, this message translates to:
  /// **'Search chats...'**
  String get searchChatsHint;

  /// No description provided for @noChatsYet.
  ///
  /// In en, this message translates to:
  /// **'No chats yet. Tap the button to start one.'**
  String get noChatsYet;

  /// No description provided for @couldNotLoadChats.
  ///
  /// In en, this message translates to:
  /// **'Could not load chats'**
  String get couldNotLoadChats;

  /// No description provided for @startNewChat.
  ///
  /// In en, this message translates to:
  /// **'Start a new chat'**
  String get startNewChat;

  /// No description provided for @noOtherUsersYet.
  ///
  /// In en, this message translates to:
  /// **'No other users yet. Register another account.'**
  String get noOtherUsersYet;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @starredMessages.
  ///
  /// In en, this message translates to:
  /// **'Starred Messages'**
  String get starredMessages;

  /// No description provided for @callHistory.
  ///
  /// In en, this message translates to:
  /// **'Call History'**
  String get callHistory;

  /// No description provided for @archivedChats.
  ///
  /// In en, this message translates to:
  /// **'Archived Chats'**
  String get archivedChats;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logoutConfirm;

  /// No description provided for @group_.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group_;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @forward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forward;

  /// No description provided for @star.
  ///
  /// In en, this message translates to:
  /// **'Star'**
  String get star;

  /// No description provided for @unstar.
  ///
  /// In en, this message translates to:
  /// **'Unstar'**
  String get unstar;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @pinChat.
  ///
  /// In en, this message translates to:
  /// **'Pin Chat'**
  String get pinChat;

  /// No description provided for @unpinChat.
  ///
  /// In en, this message translates to:
  /// **'Unpin Chat'**
  String get unpinChat;

  /// No description provided for @pinnedChat.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinnedChat;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @deleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete Message'**
  String get deleteMessage;

  /// No description provided for @deleteMessageConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this message?'**
  String get deleteMessageConfirm;

  /// No description provided for @forwardedLabel.
  ///
  /// In en, this message translates to:
  /// **'Forwarded'**
  String get forwardedLabel;

  /// No description provided for @editedLabel.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get editedLabel;

  /// No description provided for @typeMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessageHint;

  /// No description provided for @editingMessage.
  ///
  /// In en, this message translates to:
  /// **'Editing message'**
  String get editingMessage;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get sendMessage;

  /// No description provided for @attach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attach;

  /// No description provided for @attachImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get attachImage;

  /// No description provided for @attachVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get attachVideo;

  /// No description provided for @attachFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get attachFile;

  /// No description provided for @connectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost. Your messages will be sent when you are back online.'**
  String get connectionLost;

  /// No description provided for @messagesWillBeSent.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Message saved and will be sent automatically.'**
  String get messagesWillBeSent;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the message.'**
  String get sendFailed;

  /// No description provided for @pinnedMessages.
  ///
  /// In en, this message translates to:
  /// **'Pinned Messages'**
  String get pinnedMessages;

  /// No description provided for @noPinnedMessages.
  ///
  /// In en, this message translates to:
  /// **'No pinned messages yet.'**
  String get noPinnedMessages;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hello!'**
  String get noMessagesYet;

  /// No description provided for @voiceCall.
  ///
  /// In en, this message translates to:
  /// **'Voice call'**
  String get voiceCall;

  /// No description provided for @videoCall.
  ///
  /// In en, this message translates to:
  /// **'Video call'**
  String get videoCall;

  /// No description provided for @callRejectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Call rejected'**
  String get callRejectedLabel;

  /// No description provided for @calls.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get calls;

  /// No description provided for @noCallsYet.
  ///
  /// In en, this message translates to:
  /// **'No calls yet.'**
  String get noCallsYet;

  /// No description provided for @searchMessagesHint.
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get searchMessagesHint;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get noSearchResults;

  /// No description provided for @recordingCancelHint.
  ///
  /// In en, this message translates to:
  /// **'Release to cancel'**
  String get recordingCancelHint;

  /// No description provided for @recordingSendHint.
  ///
  /// In en, this message translates to:
  /// **'Release to send'**
  String get recordingSendHint;

  /// No description provided for @recordingPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get recordingPaused;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get recording;

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Hold to record'**
  String get startRecording;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordMismatch;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get passwordTooShort;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required.'**
  String get passwordRequired;

  /// No description provided for @currentPasswordWrong.
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect.'**
  String get currentPasswordWrong;

  /// No description provided for @passwordChangedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully.'**
  String get passwordChangedSuccess;

  /// No description provided for @passwordChangeError.
  ///
  /// In en, this message translates to:
  /// **'Failed to change the password. Please try again.'**
  String get passwordChangeError;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Check your credentials.'**
  String get loginFailed;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @serverDomain.
  ///
  /// In en, this message translates to:
  /// **'Server (optional)'**
  String get serverDomain;

  /// No description provided for @verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyOtp;

  /// No description provided for @otpSent.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to your email'**
  String get otpSent;

  /// No description provided for @otpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid code. Please try again.'**
  String get otpInvalid;

  /// No description provided for @resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendOtp;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloading;

  /// No description provided for @downloadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved: {path}'**
  String downloadSuccess(String path);

  /// No description provided for @savedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Saved to your gallery.'**
  String get savedToGallery;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Please try again.'**
  String get downloadFailed;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @newMessageNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get newMessageNotificationTitle;

  /// No description provided for @photoNotification.
  ///
  /// In en, this message translates to:
  /// **'📷 Photo'**
  String get photoNotification;

  /// No description provided for @voiceNotification.
  ///
  /// In en, this message translates to:
  /// **'🎤 Voice message'**
  String get voiceNotification;

  /// No description provided for @fileNotification.
  ///
  /// In en, this message translates to:
  /// **'📎 File'**
  String get fileNotification;

  /// No description provided for @videoNotification.
  ///
  /// In en, this message translates to:
  /// **'🎬 Video'**
  String get videoNotification;

  /// No description provided for @videoCallNotification.
  ///
  /// In en, this message translates to:
  /// **'📹 Video call'**
  String get videoCallNotification;

  /// No description provided for @voiceCallNotification.
  ///
  /// In en, this message translates to:
  /// **'📞 Voice call'**
  String get voiceCallNotification;

  /// No description provided for @channelDescription.
  ///
  /// In en, this message translates to:
  /// **'New chat messages'**
  String get channelDescription;

  /// No description provided for @channelName.
  ///
  /// In en, this message translates to:
  /// **'Chat Messages'**
  String get channelName;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @noArchivedChats.
  ///
  /// In en, this message translates to:
  /// **'No archived chats'**
  String get noArchivedChats;

  /// No description provided for @noConversationsYet.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noConversationsYet;

  /// No description provided for @noStarredMessages.
  ///
  /// In en, this message translates to:
  /// **'No starred messages yet'**
  String get noStarredMessages;

  /// No description provided for @videoCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Video could not be loaded'**
  String get videoCouldNotLoad;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @outgoingCall.
  ///
  /// In en, this message translates to:
  /// **'Outgoing'**
  String get outgoingCall;

  /// No description provided for @incomingCall.
  ///
  /// In en, this message translates to:
  /// **'Incoming'**
  String get incomingCall;

  /// No description provided for @missedCall.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get missedCall;

  /// No description provided for @rejectedCall.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejectedCall;

  /// No description provided for @recordingPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Recording permission denied'**
  String get recordingPermissionDenied;

  /// No description provided for @imageUploadedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Image uploaded successfully'**
  String get imageUploadedSuccess;

  /// No description provided for @messageDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Message deleted successfully'**
  String get messageDeletedSuccess;

  /// No description provided for @messageGeneric.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageGeneric;

  /// No description provided for @searchInChat.
  ///
  /// In en, this message translates to:
  /// **'Search in chat'**
  String get searchInChat;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
