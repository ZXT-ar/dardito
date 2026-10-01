class BackendConfig {
  BackendConfig._();

  static const _functionsOrigin =
      'https://southamerica-east1-dardito-742d2.cloudfunctions.net';

  static const _chatEndpointOverride = String.fromEnvironment(
    'DARDITO_CHAT_ENDPOINT',
    defaultValue: '',
  );

  static Uri get chatEndpoint {
    if (_chatEndpointOverride.isNotEmpty) {
      return Uri.parse(_chatEndpointOverride);
    }
    if (const {
      'dardito-742d2.web.app',
      'dardito-742d2.firebaseapp.com',
    }.contains(Uri.base.host)) {
      return Uri.base.resolve('/api/chat');
    }
    return Uri.parse('$_functionsOrigin/darditoChat');
  }

  static const _storiesEndpointOverride = String.fromEnvironment(
    'DARDITO_STORIES_ENDPOINT',
    defaultValue: '',
  );

  static Uri get publicStoriesEndpoint {
    if (_storiesEndpointOverride.isNotEmpty) {
      return Uri.parse(_storiesEndpointOverride);
    }
    return Uri.parse('$_functionsOrigin/publicStories');
  }

  static Uri get publicCatalogsEndpoint {
    return Uri.parse('$_functionsOrigin/publicCatalogs');
  }

  static Uri get storySubmissionEndpoint {
    return Uri.parse('$_functionsOrigin/submitStory');
  }

  static Uri get profileEndpoint {
    return Uri.parse('$_functionsOrigin/upsertUserProfile');
  }

  static Uri get accessEndpoint {
    return Uri.parse('$_functionsOrigin/userAccessStatus');
  }

  static Uri get storyLikesEndpoint {
    return Uri.parse('$_functionsOrigin/storyLikes');
  }

  static Uri get usageEndpoint {
    return Uri.parse('$_functionsOrigin/usageAnalytics');
  }

  static Uri publicStoryUri(String storyId) => Uri.parse(
    'https://dardito-742d2.web.app/historias/${Uri.encodeComponent(storyId)}',
  );
}
