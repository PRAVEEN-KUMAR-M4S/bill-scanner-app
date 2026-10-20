/// The categories offered by the review form and the bills filter.
enum BillCategory {
  foodAndDrink('Food & drink'),
  groceries('Groceries'),
  travel('Travel'),
  shopping('Shopping'),
  home('Home');

  const BillCategory(this.label);

  /// Label shown in chips and in a bill's metadata line.
  final String label;
}
