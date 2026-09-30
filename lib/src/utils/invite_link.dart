/// Host of the invite links, the web app's own site. On Android the Android
/// app opens them directly where installed (App Links, verified by
/// web/.well-known/assetlinks.json), and Chrome's installed web app
/// otherwise; a link that still lands in a browser tab is handed on by
/// web/index.html in the same order, then to Google Play with the invite
/// attached. Elsewhere the tab's install screen carries it into the app.
const inviteLinkHost = 'split.rsaw409.me';

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

/// The Android app's Play Store listing. With [inviteId], the app joins that
/// group on its first launch, through the install referrer that
/// [inviteIdFromInstallReferrer] reads, encoded the same way as
/// web/index.html's hand-off.
Uri playStoreLink({String? inviteId}) => Uri.parse(
      'https://play.google.com/store/apps/details?id=developer.rohitsaw.split'
      '${inviteId == null ? '' : '&referrer=${Uri.encodeComponent('invite=${Uri.encodeComponent(inviteId)}')}'}',
    );

/// The invite id carried by a Google Play install referrer, or null.
///
/// Invite links send Android users without the app to the Play Store with
/// `&referrer=<encoded "invite=<encoded id>">` (web/index.html's hand-off,
/// and [playStoreLink] on the install screen). Play decodes the outer layer
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

/// The invite id in whatever someone pasted into the join form: a bare id,
/// the shared link, or a message with the link somewhere inside it. Null if
/// there is nothing to join with.
///
/// The link is decoded rather than taken as text: a shared link carries the
/// id's `/` as `%2F`, and sending that to the server verbatim would fail.
String? inviteIdFromInput(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;

  final link = RegExp(
    // `*`, not `+`: a link with the id missing must not be taken as an id.
    'https?://${RegExp.escape(inviteLinkHost)}/joinGroup/?\\S*',
  ).firstMatch(text);
  if (link == null) return text;

  final Uri uri;
  try {
    uri = Uri.parse(link.group(0)!);
  } on FormatException {
    return null;
  }
  // As in [inviteIdFromRoute]: everything after `joinGroup`, since an id
  // can start with `/` and older links left it unencoded.
  final inviteId = uri.pathSegments.skip(1).join('/');
  return inviteId.isEmpty ? null : inviteId;
}
