import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.isAnonymous,
  });

  final String id;
  final bool isAnonymous;

  @override
  List<Object?> get props => [id, isAnonymous];
}
