/// The app's display name, in one place.
///
/// It reached four hardcoded copies across three files before this existed,
/// which is how a rename leaves the old name showing in a corner nobody
/// opened.
///
/// Its own file rather than a constant in main.dart: the services need it
/// too, and importing main.dart from a service to reach it would point the
/// dependency back the way it came.
///
/// Two places still repeat it and can't read this — the Android launcher
/// label and the four widget picker entries, both in AndroidManifest.xml.
const String kAppName = 'Upkeep';
