import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/auth/google_id_token.dart';
import '../../core/net/api_client.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.kata;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          final stripH = (box.maxHeight * 0.3).clamp(120.0, 280.0);
          return Column(
            children: [
              Opacity(
                opacity: p.dark ? 0.62 : 1,
                child: SizedBox(
                  height: stripH,
                  child: Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 2),
                        const Expanded(
                          child: FrameSlot(
                            radius: 0,
                            placeholder: 'sample frame',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 30, 28, 34),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: box.maxHeight - stripH - 64,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: p.hairline),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '型',
                                  style: KataType.displayStyle(
                                    size: 22,
                                    weight: FontWeight.w400,
                                    color: p.fg,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'KATA',
                                style: KataType.displayStyle(
                                  size: 34,
                                  weight: FontWeight.w900,
                                  color: p.fg,
                                  letterSpacing: 0.06,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'RECIPES, STRAIGHT INTO YOUR FUJIFILM',
                            style: KataType.displayStyle(
                              size: 32,
                              color: p.fg,
                              letterSpacing: 0,
                              height: 1.06,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 290),
                            child: Text(
                              'A kata is a practised form. Keep yours in a library and write it into C1–C7 over USB-C — no retyping menus.',
                              style: KataType.bodyStyle(
                                size: 13,
                                color: p.muted,
                                height: 1.55,
                              ),
                            ),
                          ),
                          const Spacer(),
                          KataPillButton(
                            label: 'Continue with Google',
                            display: false,
                            leading: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: p.bg, width: 1.5),
                              ),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  width: 4,
                                  height: 18,
                                  color: p.fg,
                                ),
                              ),
                            ),
                            onPressed: () async {
                              try {
                                await ref.read(sessionProvider.notifier).signIn();
                              } on AuthCancelled {
                                // user dismissed the account picker
                              } on AuthNotConfigured {
                                if (context.mounted) KataToast.show(context, "Google sign-in isn't configured in this build");
                              } on ApiException catch (e) {
                                if (context.mounted) KataToast.show(context, e.isNetwork ? 'No connection — try again' : 'Sign-in failed: ${e.message}');
                              } catch (_) {
                                if (context.mounted) KataToast.show(context, 'Sign-in failed');
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: p.hairline,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Sign-in keeps your katas synced',
                                  overflow: TextOverflow.ellipsis,
                                  style: KataType.bodyStyle(
                                    size: 11,
                                    color: p.muted,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              'Privacy',
                              style:
                                  KataType.bodyStyle(
                                    size: 11,
                                    color: p.muted,
                                    height: 1,
                                  ).copyWith(
                                    decoration: TextDecoration.underline,
                                    decorationColor: p.muted,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
