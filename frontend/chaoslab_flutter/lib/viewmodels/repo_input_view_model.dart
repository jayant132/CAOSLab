import 'package:flutter/foundation.dart';

import '../core/network/dio_client.dart';
import '../core/utils/view_state.dart';
import '../data/models/repository_inspect_result.dart';
import '../domain/repositories/repository_repository.dart';

/// Backs the "paste a GitHub link" entry screen. On success it exposes the
/// parsed [RepositoryInspectResult] for the router to hand off to the
/// Architecture Preview screen.
class RepoInputViewModel extends ChangeNotifier {
  RepoInputViewModel(this._repository);

  final RepositoryRepository _repository;

  ViewState state = ViewState.idle;
  String? errorMessage;
  RepositoryInspectResult? result;

  bool get isLoading => state == ViewState.loading;

  Future<bool> inspectRepository(String repoUrl) async {
    final trimmed = repoUrl.trim();
    if (trimmed.isEmpty) {
      errorMessage = 'Paste a public GitHub repository URL first.';
      state = ViewState.error;
      notifyListeners();
      return false;
    }

    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      result = await _repository.inspectRepository(trimmed);
      state = ViewState.success;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = error is ApiException ? error.message : 'Something went wrong.';
      state = ViewState.error;
      notifyListeners();
      return false;
    }
  }

  void reset() {
    state = ViewState.idle;
    errorMessage = null;
    result = null;
    notifyListeners();
  }
}
