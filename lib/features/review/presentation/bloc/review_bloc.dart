import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bills/domain/entities/bill.dart';
import '../../../bills/domain/usecases/save_bill.dart';
import 'review_event.dart';
import 'review_state.dart';

class ReviewBloc extends Bloc<ReviewEvent, ReviewState> {
  ReviewBloc({required Bill bill, required SaveBill saveBill})
    : _saveBill = saveBill,
      super(ReviewEditing.fromBill(bill)) {
    on<ReviewMerchantChanged>(_onMerchantChanged);
    on<ReviewDateChanged>(_onDateChanged);
    on<ReviewTotalChanged>(_onTotalChanged);
    on<ReviewCategoryChanged>(_onCategoryChanged);
    on<ReviewItemNameChanged>(_onItemNameChanged);
    on<ReviewItemQuantityChanged>(_onItemQuantityChanged);
    on<ReviewItemPriceChanged>(_onItemPriceChanged);
    on<ReviewItemAdded>(_onItemAdded);
    on<ReviewItemRemoved>(_onItemRemoved);
    on<ReviewSubmitted>(_onSubmitted);
  }

  final SaveBill _saveBill;

  ReviewEditing? get _editing {
    final ReviewState current = state;
    return current is ReviewEditing ? current : null;
  }

  void _onMerchantChanged(
    ReviewMerchantChanged event,
    Emitter<ReviewState> emit,
  ) {
    final ReviewEditing? editing = _editing;
    if (editing == null) return;
    emit(editing.copyWith(merchant: event.value));
  }

  void _onDateChanged(ReviewDateChanged event, Emitter<ReviewState> emit) {
    final ReviewEditing? editing = _editing;
    if (editing == null) return;
    emit(editing.copyWith(dateText: event.value));
  }

  void _onTotalChanged(ReviewTotalChanged event, Emitter<ReviewState> emit) {
    final ReviewEditing? editing = _editing;
    if (editing == null) return;
    emit(editing.copyWith(totalText: event.value));
  }

  void _onCategoryChanged(
    ReviewCategoryChanged event,
    Emitter<ReviewState> emit,
  ) {
    final ReviewEditing? editing = _editing;
    if (editing == null) return;
    emit(editing.copyWith(category: event.category));
  }

  void _onItemNameChanged(
    ReviewItemNameChanged event,
    Emitter<ReviewState> emit,
  ) {
    _updateItem(emit, event.index, (item) => item.copyWith(name: event.value));
  }

  void _onItemQuantityChanged(
    ReviewItemQuantityChanged event,
    Emitter<ReviewState> emit,
  ) {
    _updateItem(
      emit,
      event.index,
      (item) => item.copyWith(quantityText: event.value),
    );
  }

  void _onItemPriceChanged(
    ReviewItemPriceChanged event,
    Emitter<ReviewState> emit,
  ) {
    _updateItem(
      emit,
      event.index,
      (item) => item.copyWith(priceText: event.value),
    );
  }

  void _updateItem(
    Emitter<ReviewState> emit,
    int index,
    ReviewItemInput Function(ReviewItemInput) transform,
  ) {
    final ReviewEditing? editing = _editing;
    if (editing == null || index < 0 || index >= editing.items.length) return;

    final List<ReviewItemInput> items = List<ReviewItemInput>.of(editing.items);
    items[index] = transform(items[index]);
    emit(editing.copyWith(items: items));
  }

  void _onItemAdded(ReviewItemAdded event, Emitter<ReviewState> emit) {
    final ReviewEditing? editing = _editing;
    if (editing == null) return;

    final int nextId = editing.items.isEmpty
        ? 1
        : editing.items
                  .map((ReviewItemInput item) => item.id)
                  .reduce((int a, int b) => a > b ? a : b) +
              1;

    emit(
      editing.copyWith(
        items: <ReviewItemInput>[
          ...editing.items,
          ReviewItemInput(
            id: nextId,
            name: '',
            quantityText: '1',
            priceText: '',
          ),
        ],
      ),
    );
  }

  void _onItemRemoved(ReviewItemRemoved event, Emitter<ReviewState> emit) {
    final ReviewEditing? editing = _editing;
    if (editing == null || event.index < 0 || event.index >= editing.items.length) {
      return;
    }

    final List<ReviewItemInput> items = List<ReviewItemInput>.of(editing.items)
      ..removeAt(event.index);
    emit(editing.copyWith(items: items));
  }

  Future<void> _onSubmitted(
    ReviewSubmitted event,
    Emitter<ReviewState> emit,
  ) async {
    final ReviewEditing? editing = _editing;
    if (editing == null || editing.isSaving) return;

    if (!editing.isValid) {
      emit(editing.copyWith(submitted: true));
      return;
    }

    emit(
      editing.copyWith(
        isSaving: true,
        submitted: true,
        clearFailure: true,
      ),
    );
    try {
      final Bill saved = await _saveBill(editing.toBill());
      emit(ReviewSaved(saved));
    } on Exception {
      emit(
        editing.copyWith(
          isSaving: false,
          failureMessage: 'Could not save that bill. Try again.',
        ),
      );
    }
  }
}
