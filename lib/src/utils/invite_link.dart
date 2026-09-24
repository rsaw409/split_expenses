/// Host serving the invite links; Android verifies it for App Links through
/// its `/.well-known/assetlinks.json`, so the app opens them directly.
const inviteLinkHost = 'portfolio.rsaw409.me';

/// The link that joins [inviteId]'s group, shared as text and as a QR code.
///
/// Invite ids are base64-like, so they can contain `/`, `+` and `=`. Building
/// it from path segments percent-encodes the `/`, keeping the id one segment
/// for anything else that reads the link, such as a web fallback page.
Uri inviteLink(String inviteId) => Uri(
      scheme: 'https',
      host: inviteLinkHost,
      pathSegments: ['joinGroup', inviteId],
    );

/// The invite id in a `/joinGroup/<id>` route name, or null if it has none.
///
/// Everything after `joinGroup` is the id, not just the next segment. Flutter
/// decodes the whole route name before the app sees it, so an encoded `%2F`
/// arrives as a real `/` and the id spans several segments. Taking only the
/// first one truncated it, and roughly half of all invite ids contain a `/`.
String? inviteIdFromRoute(String routeName) {
  final segments = Uri.parse(routeName).pathSegments;
  if (segments.length < 2 || segments.first != 'joinGroup') return null;

  final inviteId = segments.skip(1).join('/');
  return inviteId.isEmpty ? null : inviteId;
}

/// Whether [routeName] is a `/joinGroup` deep link, with or without an id.
bool isJoinGroupRoute(String routeName) {
  final segments = Uri.parse(routeName).pathSegments;
  return segments.isNotEmpty && segments.first == 'joinGroup';
}

/// The invite id carried by a Google Play install referrer, or null.
///
/// The web fallback page (the portfolio repo's `public/split-join.html`)
/// sends people without the app to the Play Store with
/// `&referrer=<encoded "invite=<encoded id>">`. Play decodes the outer layer
/// and hands the app `invite=<encoded id>`, a query string, so the id still
/// arrives intact even though it contains `/`, `+` and `=`. Installs that did
/// not come from an invite get Play's own value, such as
/// `utm_source=google-play&utm_medium=organic`, which has no `invite`.
String? inviteIdFromInstallReferrer(String? referrer) {
  if (referrer == null || referrer.isEmpty) return null;

  final Map<String, String> params;
  try {
    params = Uri.splitQueryString(referrer);
  } on FormatException {
    return null;
  } on ArgumentError {
    // What splitQueryString throws for a bad escape such as `%zz`.
    return null;
  }
  final inviteId = params['invite'];
  return inviteId == null || inviteId.isEmpty ? null : inviteId;
}
