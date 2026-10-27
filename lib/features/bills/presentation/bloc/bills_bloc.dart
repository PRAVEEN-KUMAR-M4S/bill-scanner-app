import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_category.dart';
import '../../domain/entities/bills_snapshot.dart';
import '../../domain/failures/bill_failure.dart';
import '../../domain/usecases/fetch_bills.dart';
import 'bills_event.dart';
import 'bills_state.dart';

class BillsBloc extends Bloc<BillsEvent, BillsState> {
  BillsBloc({required FetchBills fetchBills})
    : _fetchBills = fetchBills,
      super(const BillsLoading()) {
    on<BillsStarted>(_onStarted);
    on<BillsReloaded>(_onReloaded);
    on<BillsSearchChanged>(_onSearchChanged);
    on<BillsCategoryChanged>(_onCategoryChanged);
    on<BillsRetryRequested>(_onRetryRequested);
  }

  final FetchBills _fetchBills;

  List<Bill> _bills = const <Bill>[];
  BillsSource _source = BillsSource.server;
  String _query = '';
  BillCategory? _category;

  Future<void> _onStarted(BillsStarted event, Emitter<BillsState> emit) async {
    emit(const BillsLoading());
    await _load(emit);
  }

  Future<void> _onRetryRequested(
    BillsRetryRequested event,
    Emitter<BillsState> emit,
  ) async {
    emit(const BillsLoading());
    await _load(emit);
  }

  Future<void> _onReloaded(
    BillsReloaded event,
    Emitter<BillsState> emit,
  ) async {
    await _load(emit);
  }

  Future<void> _load(Emitter<BillsState> emit) async {
    try {
      final BillsSnapshot snapshot = await _fetchBills();
      _bills = snapshot.bills;
      _source = snapshot.source;
      emit(_loaded());
    } on BillFailure catch (failure) {
      emit(BillsFailure(failure.message));
    } on Exception {
      emit(const BillsFailure('Could not load your bills. Try again.'));
    }
  }

  void _onSearchChanged(BillsSearchChanged event, Emitter<BillsState> emit) {
    _query = event.query;
    final BillsState current = state;
    if (current is BillsLoaded) emit(_loaded());
  }

  void _onCategoryChanged(
    BillsCategoryChanged event,
    Emitter<BillsState> emit,
  ) {
    _category = event.category;
    final BillsState current = state;
    if (current is BillsLoaded) emit(_loaded());
  }

  BillsLoaded _loaded() {
    return BillsLoaded(
      bills: List<Bill>.unmodifiable(_bills),
      visibleBills: List<Bill>.unmodifiable(_bills.where(_matches).toList()),
      source: _source,
      query: _query,
      category: _category,
    );
  }

  bool _matches(Bill bill) {
    if (_category != null && bill.category != _category) return false;

    final String needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return true;

    if (bill.merchant.toLowerCase().contains(needle)) return true;
    if (bill.category.label.toLowerCase().contains(needle)) return true;
    return bill.items.any((item) => item.name.toLowerCase().contains(needle));
  }
}
