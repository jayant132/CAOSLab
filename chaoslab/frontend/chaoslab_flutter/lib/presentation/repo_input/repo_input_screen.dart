import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/view_state.dart';
import '../../viewmodels/repo_input_view_model.dart';
import '../architecture_preview/architecture_preview_screen.dart';
import '../shared/widgets/error_banner.dart';

class RepoInputScreen extends StatelessWidget {
  const RepoInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RepoInputViewModel(ServiceLocator.instance.repositoryRepository),
      child: const _RepoInputView(),
    );
  }
}

class _RepoInputView extends StatefulWidget {
  const _RepoInputView();

  @override
  State<_RepoInputView> createState() => _RepoInputViewState();
}

class _RepoInputViewState extends State<_RepoInputView> {
  final TextEditingController _controller = TextEditingController(
    text: 'https://github.com/dockersamples/example-voting-app',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(RepoInputViewModel vm) async {
    final success = await vm.inspectRepository(_controller.text);
    if (success && mounted && vm.result != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ArchitecturePreviewScreen(inspectResult: vm.result!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RepoInputViewModel>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 28),
                  Text(
                    'Before your users discover how your system fails,\nlet AI find out first.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'PUBLIC GITHUB REPOSITORY',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _controller,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'https://github.com/owner/repo',
                      prefixIcon: Icon(Icons.link, color: AppColors.textMuted, size: 18),
                    ),
                    onSubmitted: (_) => _submit(vm),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: vm.isLoading ? null : () => _submit(vm),
                      child: vm.isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            )
                          : const Text('IMPORT ARCHITECTURE'),
                    ),
                  ),
                  if (vm.state == ViewState.error && vm.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    ErrorBanner(message: vm.errorMessage!),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    'We read docker-compose.yml at the repo root and reconstruct the '
                    'service topology. No compose file, or a private repo? We fall back '
                    'to a minimal 3-tier reference architecture so you can still try the '
                    'pipeline end to end.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(color: AppColors.statusHealthy, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        const Text(
          'CHAOSLAB',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
