class BackendConfig {
  BackendConfig._();

  static const _chatEndpointOverride = String.fromEnvironment(
    'DARDITO_CHAT_ENDPOINT',
    defaultValue: '',
  );

  static Uri get chatEndpoint {
    if (_chatEndpointOverride.isNotEmpty) {
      return Uri.parse(_chatEndpointOverride);
    }
    if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
      return Uri.parse(
        'https://southamerica-east1-dardito-742d2.cloudfunctions.net/darditoChat',
      );
    }
    return Uri.base.resolve('/api/chat');
  }

  static Uri get storySubmissionEndpoint {
    if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
      return Uri.parse(
        'https://southamerica-east1-dardito-742d2.cloudfunctions.net/submitStory',
      );
    }
    return Uri.base.resolve('/api/story-submissions');
  }

  static Uri get profileEndpoint {
    if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
      return Uri.parse(
        'https://southamerica-east1-dardito-742d2.cloudfunctions.net/upsertUserProfile',
      );
    }
    return Uri.base.resolve('/api/profile');
  }
}
