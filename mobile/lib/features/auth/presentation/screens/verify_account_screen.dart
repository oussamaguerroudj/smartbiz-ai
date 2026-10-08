import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/auth_repository.dart';

/// Verify Account Screen
///
/// Shown right after registration and reachable again from Login if an
/// unverified account tries to sign in.
///
/// Asks for the 6-digit verification code sent to the user's email
/// and calls the verification endpoint through AuthRepository.
///
/// Includes a resend-code action with a short cooldown.
class VerifyAccountScreen extends ConsumerStatefulWidget {
const VerifyAccountScreen({
super.key,
required this.email,
required this.onVerified,
required this.onGoToLogin,
});

final String email;
final VoidCallback onVerified;
final VoidCallback onGoToLogin;

@override
ConsumerState<VerifyAccountScreen> createState() =>
_VerifyAccountScreenState();
}

class _VerifyAccountScreenState
extends ConsumerState<VerifyAccountScreen> {
final List<TextEditingController> _digitControllers =
List.generate(6, (_) => TextEditingController());

final List<FocusNode> _digitNodes =
List.generate(6, (_) => FocusNode());

bool _isLoading = false;
bool _isResending = false;
int _resendCooldown = 0;

Timer? _cooldownTimer;

@override
void dispose() {
for (final controller in _digitControllers) {
controller.dispose();
}

for (final node in _digitNodes) {
  node.dispose();
}

_cooldownTimer?.cancel();

super.dispose();

}

String get _code =>
_digitControllers.map((controller) => controller.text).join();

void _startCooldown() {
_cooldownTimer?.cancel();

setState(() {
  // Matches the backend's 1-minute code expiry (see
  // VERIFICATION_CODE_TTL_SECONDS in auth.service.js).
  _resendCooldown = 60;
});

_cooldownTimer = Timer.periodic(
  const Duration(seconds: 1),
  (timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }

    setState(() {
      _resendCooldown -= 1;

      if (_resendCooldown <= 0) {
        _resendCooldown = 0;
        timer.cancel();
      }
    });
  },
);

}

Future<void> _submit() async {
final l10n = AppLocalizations.of(context)!;

if (_code.length != 6) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.verifyEnterFullCode),
    ),
  );
  return;
}

if (_isLoading) {
  return;
}

setState(() {
  _isLoading = true;
});

try {
  await ref.read(authRepositoryProvider).verifyAccount(
        email: widget.email,
        code: _code,
      );

  if (!mounted) {
    return;
  }

  widget.onVerified();
} on ApiException catch (e) {
  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(e.message),
    ),
  );
} catch (_) {
  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.networkError),
    ),
  );
} finally {
  if (mounted) {
    setState(() {
      _isLoading = false;
    });
  }
}

}

Future<void> _resend() async {
final l10n = AppLocalizations.of(context)!;

if (_isResending || _resendCooldown > 0) {
  return;
}

setState(() {
  _isResending = true;
});

try {
  await ref
      .read(authRepositoryProvider)
      .resendVerificationCode(
        email: widget.email,
      );

  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.verifyCodeResent),
    ),
  );

  _startCooldown();
} on ApiException catch (e) {
  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(e.message),
    ),
  );
} catch (_) {
  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.networkError),
    ),
  );
} finally {
  if (mounted) {
    setState(() {
      _isResending = false;
    });
  }
}

}

  Widget _buildDigitBox(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasValue = _digitControllers[index].text.isNotEmpty;

    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: _digitControllers[index],
        focusNode: _digitNodes[index],
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: TextInputType.number,
        textInputAction:
            index == 5 ? TextInputAction.done : TextInputAction.next,
        maxLength: 1,
        autofocus: index == 0,
        // FIX (reported bug): the digit typed here rendered huge and
        // hard to read. The box had a fixed height but the default
        // TextField internals (counter row + default vertical padding)
        // needed more vertical space than that, so the field clipped  - 
        // only the top sliver of the glyph was visible, which read as
        // "giant and invisible". isDense + zero content padding +
        // textAlignVertical.center makes the whole digit fit and sit
        // dead-center in the box instead of being cropped.
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.0,
          color: colorScheme.onSurface,
        ),
        cursorColor: colorScheme.primary,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          counterText: '',
          isDense: true,
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: hasValue
              ? colorScheme.primary.withValues(alpha: 0.08)
              : colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        ),
        onChanged: (value) {
          setState(() {});

          if (value.isNotEmpty && index < 5) {
            _digitNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _digitNodes[index - 1].requestFocus();
          }

          if (index == 5 &&
              value.isNotEmpty &&
              _code.length == 6) {
            _submit();
          }
        },
        onSubmitted: (_) {
          if (index == 5) {
            _submit();
          }
        },
      ),
    );
  }

@override
Widget build(BuildContext context) {
final l10n = AppLocalizations.of(context)!;
final colorScheme = Theme.of(context).colorScheme;

return Scaffold(
  body: SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: FadeSlideIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.verifyAccountTitle,
              style: AppTypography.screenTitle(
                colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.verifyAccountSubtitle(widget.email),
              style: AppTypography.body(
                Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color ??
                    Colors.grey,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(
                AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(
                  AppSpacing.radiusCard,
                ),
                boxShadow: AppSpacing.cardElevation,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.verifyCodeLabel,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge,
                  ),
                  const SizedBox(
                    height: AppSpacing.xs,
                  ),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      6,
                      _buildDigitBox,
                    ),
                  ),
                  const SizedBox(
                    height: AppSpacing.sm,
                  ),
                  Center(
                    child: _isResending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : TextButton(
                            onPressed:
                                _resendCooldown > 0
                                    ? null
                                    : _resend,
                            child: Text(
                              _resendCooldown > 0
                                  ? l10n.verifyResendIn(
                                      _resendCooldown,
                                    )
                                  : l10n.verifyResendCode,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: AppSpacing.md,
            ),
            AnimatedSwitcher(
              duration: const Duration(
                milliseconds: 200,
              ),
              child: ElevatedButton(
                key: ValueKey(_isLoading),
                onPressed:
                    _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l10n.verifyAccountButton,
                      ),
              ),
            ),
            const SizedBox(
              height: AppSpacing.sm,
            ),
            Center(
              child: TextButton(
                onPressed: widget.onGoToLogin,
                child: Text(
                  l10n.backToLogin,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

}
}
