// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Chatt';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get back => 'Back';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get search => 'Search';

  @override
  String get send => 'Send';

  @override
  String get close => 'Close';

  @override
  String get chats => 'Chats';

  @override
  String chatsWithUser(String name) {
    return 'Chats · $name';
  }

  @override
  String get searchChatsHint => 'Search chats...';

  @override
  String get noChatsYet => 'No chats yet. Tap the button to start one.';

  @override
  String get couldNotLoadChats => 'Could not load chats';

  @override
  String get startNewChat => 'Start a new chat';

  @override
  String get noOtherUsersYet => 'No other users yet. Register another account.';

  @override
  String get newGroup => 'New group';

  @override
  String get starredMessages => 'Starred Messages';

  @override
  String get callHistory => 'Call History';

  @override
  String get archivedChats => 'Archived Chats';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirm => 'Are you sure you want to log out?';

  @override
  String get group_ => 'Group';

  @override
  String get reply => 'Reply';

  @override
  String get forward => 'Forward';

  @override
  String get star => 'Star';

  @override
  String get unstar => 'Unstar';

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get pinChat => 'Pin Chat';

  @override
  String get unpinChat => 'Unpin Chat';

  @override
  String get archiveChat => 'Archive Chat';

  @override
  String get groupLabel => 'Group';

  @override
  String get react => 'React';

  @override
  String get pinnedChat => 'Pinned';

  @override
  String get edit => 'Edit';

  @override
  String get deleteMessage => 'Delete Message';

  @override
  String get deleteMessageConfirm =>
      'Are you sure you want to delete this message?';

  @override
  String get forwardedLabel => 'Forwarded';

  @override
  String get editedLabel => 'edited';

  @override
  String get typeMessageHint => 'Type a message...';

  @override
  String get editingMessage => 'Editing message';

  @override
  String get sendMessage => 'Send message';

  @override
  String get attach => 'Attach';

  @override
  String get attachImage => 'Image';

  @override
  String get attachVideo => 'Video';

  @override
  String get attachFile => 'File';

  @override
  String get connectionLost =>
      'Connection lost. Your messages will be sent when you are back online.';

  @override
  String get messagesWillBeSent =>
      'No internet connection. Message saved and will be sent automatically.';

  @override
  String get sendFailed => 'Could not send the message.';

  @override
  String get pinnedMessages => 'Pinned Messages';

  @override
  String get noPinnedMessages => 'No pinned messages yet.';

  @override
  String get noMessagesYet => 'No messages yet. Say hello!';

  @override
  String get voiceCall => 'Voice call';

  @override
  String get videoCall => 'Video call';

  @override
  String get callRejectedLabel => 'Call rejected';

  @override
  String get calls => 'Calls';

  @override
  String get noCallsYet => 'No calls yet.';

  @override
  String get searchMessagesHint => 'Search messages';

  @override
  String get noSearchResults => 'No results found.';

  @override
  String get recordingCancelHint => 'Release to cancel';

  @override
  String get recordingSendHint => 'Release to send';

  @override
  String get recordingPaused => 'Paused';

  @override
  String get recording => 'Recording...';

  @override
  String get startRecording => 'Hold to record';

  @override
  String get appearance => 'Appearance';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get systemDefault => 'System Default';

  @override
  String get theme => 'Theme';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get account => 'Account';

  @override
  String get changePassword => 'Change Password';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get newPassword => 'New Password';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get show => 'Show';

  @override
  String get hide => 'Hide';

  @override
  String get passwordMismatch => 'Passwords do not match.';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters.';

  @override
  String get passwordRequired => 'Password is required.';

  @override
  String get currentPasswordWrong => 'Current password is incorrect.';

  @override
  String get passwordChangedSuccess => 'Password changed successfully.';

  @override
  String get passwordChangeError =>
      'Failed to change the password. Please try again.';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get login => 'Login';

  @override
  String get loginFailed => 'Login failed. Check your credentials.';

  @override
  String get register => 'Register';

  @override
  String get name => 'Name';

  @override
  String get serverDomain => 'Server (optional)';

  @override
  String get verifyOtp => 'Verify';

  @override
  String get otpSent => 'Enter the code sent to your email';

  @override
  String get otpInvalid => 'Invalid code. Please try again.';

  @override
  String get resendOtp => 'Resend code';

  @override
  String get download => 'Download';

  @override
  String get downloading => 'Downloading...';

  @override
  String downloadSuccess(String path) {
    return 'Saved: $path';
  }

  @override
  String get savedToGallery => 'Saved to your gallery.';

  @override
  String get downloadFailed => 'Download failed. Please try again.';

  @override
  String get saveButton => 'Save';

  @override
  String get newMessageNotificationTitle => 'New message';

  @override
  String get photoNotification => '📷 Photo';

  @override
  String get voiceNotification => '🎤 Voice message';

  @override
  String get fileNotification => '📎 File';

  @override
  String get videoNotification => '🎬 Video';

  @override
  String get videoCallNotification => '📹 Video call';

  @override
  String get voiceCallNotification => '📞 Voice call';

  @override
  String get channelDescription => 'New chat messages';

  @override
  String get channelName => 'Chat Messages';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get bio => 'Bio';

  @override
  String get noArchivedChats => 'No archived chats';

  @override
  String get noConversationsYet => 'No conversations yet';

  @override
  String get noStarredMessages => 'No starred messages yet';

  @override
  String get videoCouldNotLoad => 'Video could not be loaded';

  @override
  String get unknown => 'Unknown';

  @override
  String get outgoingCall => 'Outgoing';

  @override
  String get incomingCall => 'Incoming';

  @override
  String get missedCall => 'Missed';

  @override
  String get rejectedCall => 'Rejected';

  @override
  String get recordingPermissionDenied => 'Recording permission denied';

  @override
  String get imageUploadedSuccess => 'Image uploaded successfully';

  @override
  String get messageDeletedSuccess => 'Message deleted successfully';

  @override
  String get messageGeneric => 'Message';

  @override
  String get searchInChat => 'Search in chat';
}
