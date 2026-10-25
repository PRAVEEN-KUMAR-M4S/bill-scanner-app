/// The ten categories the backend accepts, with their UI label, API slug and
/// the HugeIcons name the backend uses as that category's default.
///
/// The label is what a person sees; [slug] is what goes over the wire; [icon]
/// is only sent back on confirm, so the saved row always has a drawable icon.
enum BillCategory {
  foodAndDrink('Food & drink', 'dining', 'strokeRoundedRestaurant01'),
  groceries('Groceries', 'groceries', 'strokeRoundedShoppingBasket01'),
  travel('Travel', 'transport', 'strokeRoundedBus01'),
  health('Health', 'health', 'strokeRoundedMedicine01'),
  utilities('Utilities', 'utilities', 'strokeRoundedFlash'),
  shopping('Shopping', 'shopping', 'strokeRoundedShoppingBag01'),
  home('Home', 'rent', 'strokeRoundedHome01'),
  entertainment('Entertainment', 'entertainment', 'strokeRoundedFilm01'),
  education('Education', 'education', 'strokeRoundedBook01'),
  other('Other', 'other', 'strokeRoundedHelpCircle');

  const BillCategory(this.label, this.slug, this.icon);

  /// Display name in chips, tiles and the bills filter.
  final String label;

  /// Value stored by the API (`groceries`, `dining`, ...).
  final String slug;

  /// Default HugeIcons member for this category.
  final String icon;

  /// Resolves an API slug, falling back to [other] for a value this build does
  /// not know instead of crashing on a newer backend.
  static BillCategory fromSlug(String? slug) {
    for (final BillCategory category in values) {
      if (category.slug == slug) return category;
    }
    return other;
  }
}
