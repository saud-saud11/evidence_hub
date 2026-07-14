class Failure {
  final String message;
  
  Failure(this.message);

  @override
  String toString() => message;
}

class NetworkFailure extends Failure {
  NetworkFailure() : super('Connection error. Please check your internet and try again.');
}

class AuthFailure extends Failure {
  AuthFailure(String message) : super(message);
}

class PermissionFailure extends Failure {
  PermissionFailure() : super('You do not have permission to perform this action.');
}

class StorageFailure extends Failure {
  StorageFailure(String message) : super(message);
}
