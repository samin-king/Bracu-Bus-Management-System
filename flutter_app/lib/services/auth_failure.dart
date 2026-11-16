class AuthFailure implements Exception {
  const AuthFailure(this.code);
  final String code;

  String get message => switch (code) {
    'invalid_email' =>
      'Enter your complete BRACU email ending in @g.bracu.ac.bd.',
    'invalid_email_token' =>
      'This sign-in link is invalid or expired. Request a new link.',
    'email_not_configured' =>
      'Email sign-in is not configured. Contact the transport administrator.',
    'email_delivery_failed' =>
      'The sign-in email could not be delivered. Please try again later.',
    'account_unavailable' =>
      'Your account is unavailable. Contact the transport administrator.',
    'invalid_institution' =>
      'Use your BRACU student Google Workspace account to sign in.',
    'invalid_callback' =>
      'Your sign-in request expired or was invalid. Please start again.',
    'google_denied' ||
    'cancelled' => 'Google sign-in was cancelled. You can try again.',
    'google_failed' =>
      'Google could not verify your identity. Please try again.',
    'account_conflict' =>
      'This email is already linked to another identity. Contact support.',
    'oauth_not_configured' =>
      'Google sign-in is not configured on the server. Contact support.',
    'too_many_attempts' => 'Too many sign-in attempts. Try again later.',
    'unauthenticated' => 'Your session has expired. Please sign in again.',
    'invalid_origin' =>
      'The server rejected this app configuration. Contact support.',
    'configuration' =>
      'Authentication configuration is missing or invalid. Contact support.',
    'browser_unavailable' =>
      'Could not complete browser sign-in. Please try again.',
    'unsupported_role' =>
      'This account role is not supported. Contact support.',
    _ => 'Authentication is temporarily unavailable. Please try again.',
  };
}
