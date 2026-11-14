/// A balance problem whose [message] is safe to put in front of the user.
///
/// The data layer raises it; `BalanceBloc` shows the message and never looks at
/// an HTTP status code. [offline] marks the one case the card can ride out: the
/// API could not be reached, so the last figure stored on the device is used.
class BalanceException implements Exception {
  const BalanceException(this.message, {this.offline = false});

  /// The connection failed, or the request timed out.
  const BalanceException.offline(
    this.message,
  ) : offline = true;

  final String message;
  final bool offline;

  @override
  String toString() => 'BalanceException($message)';
}
