enum MessageType {
  text,
  image,
  voice,
  videoCall,
  voiceCall,
}

/// Maps the backend string values to the [MessageType] enum.
MessageType messageTypeFromString(String? value) {
  switch (value) {
    case 'image':
      return MessageType.image;

    case 'voice':
      return MessageType.voice;

    case 'videoCall':
      return MessageType.videoCall;

    case 'voiceCall':
      return MessageType.voiceCall;

    case 'text':
    default:
      return MessageType.text;
  }
}

extension MessageTypeX on MessageType {
  /// The wire value expected by the backend.
  String get asString {
    switch (this) {
      case MessageType.text:
        return 'text';

      case MessageType.image:
        return 'image';

      case MessageType.voice:
        return 'voice';

      case MessageType.videoCall:
        return 'videoCall';

      case MessageType.voiceCall:
        return 'voiceCall';
    }
  }
}