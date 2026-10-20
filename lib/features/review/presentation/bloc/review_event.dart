import 'package:equatable/equatable.dart';

import '../../../bills/domain/entities/bill_category.dart';

sealed class ReviewEvent extends Equatable {
  const ReviewEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

final class ReviewMerchantChanged extends ReviewEvent {
  const ReviewMerchantChanged(this.value);

  final String value;

  @override
  List<Object?> get props => <Object?>[value];
}

final class ReviewDateChanged extends ReviewEvent {
  const ReviewDateChanged(this.value);

  final String value;

  @override
  List<Object?> get props => <Object?>[value];
}

final class ReviewTotalChanged extends ReviewEvent {
  const ReviewTotalChanged(this.value);

  final String value;

  @override
  List<Object?> get props => <Object?>[value];
}

final class ReviewCategoryChanged extends ReviewEvent {
  const ReviewCategoryChanged(this.category);

  final BillCategory category;

  @override
  List<Object?> get props => <Object?>[category];
}

final class ReviewItemNameChanged extends ReviewEvent {
  const ReviewItemNameChanged({required this.index, required this.value});

  final int index;
  final String value;

  @override
  List<Object?> get props => <Object?>[index, value];
}

final class ReviewItemQuantityChanged extends ReviewEvent {
  const ReviewItemQuantityChanged({required this.index, required this.value});

  final int index;
  final String value;

  @override
  List<Object?> get props => <Object?>[index, value];
}

final class ReviewItemPriceChanged extends ReviewEvent {
  const ReviewItemPriceChanged({required this.index, required this.value});

  final int index;
  final String value;

  @override
  List<Object?> get props => <Object?>[index, value];
}

final class ReviewItemAdded extends ReviewEvent {
  const ReviewItemAdded();
}

final class ReviewItemRemoved extends ReviewEvent {
  const ReviewItemRemoved(this.index);

  final int index;

  @override
  List<Object?> get props => <Object?>[index];
}

final class ReviewSubmitted extends ReviewEvent {
  const ReviewSubmitted();
}
