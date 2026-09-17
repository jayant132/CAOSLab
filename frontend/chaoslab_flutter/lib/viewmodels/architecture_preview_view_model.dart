import 'package:flutter/foundation.dart';

import '../data/models/architecture_graph.dart';

/// Backs the "confirm/edit parsed architecture before simulating" screen.
/// This is the trust-building step: the user can correct replica counts
/// the auto-parse guessed wrong before any agent touches the data, which
/// is what keeps the whole pipeline honest rather than a black box.
class ArchitecturePreviewViewModel extends ChangeNotifier {
  ArchitecturePreviewViewModel(ArchitectureGraph initialArchitecture)
      : _architecture = initialArchitecture;

  ArchitectureGraph _architecture;
  ArchitectureGraph get architecture => _architecture;

  void updateReplicas(String serviceName, int newReplicas) {
    final updatedServices = _architecture.services.map((service) {
      if (service.name == serviceName) {
        return service.copyWith(replicas: newReplicas.clamp(1, 999));
      }
      return service;
    }).toList();

    _architecture = _architecture.copyWithServices(updatedServices);
    notifyListeners();
  }
}
