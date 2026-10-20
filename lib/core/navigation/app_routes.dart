/// Route names that more than one feature has to reference.
///
/// Page-specific routes live as `routeName` on their page; the shell is shared
/// because the review flow returns to it after saving.
abstract final class AppRoutes {
  static const String shell = '/app';
}
