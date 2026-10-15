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

static String normalizeDigits(String input) => _VerifyAccountScreenState.normalizeDigits(input);

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

  static String normalizeDigits(String input) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const easternArabicIndic = '۰۱۲۳۴۵۶۷۸۹';
    final sb = StringBuffer();
    for (final char in input.characters) {
      final idxAr = arabicIndic.indexOf(char);
      if (idxAr != -1) {
        sb.write(idxAr);
        continue;
      }
      final idxFa = easternArabicIndic.indexOf(char);
      if (idxFa != -1) {
        sb.write(idxFa);
        continue;
      }
      if (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) {
        sb.write(char);
      }
    }
    return sb.toString();
  }

  void _onPasteCode(String pastedText, int startIndex) {
    final digits = normalizeDigits(pastedText);
    if (digits.isEmpty) return;

    // Distribute digits into controllers starting from index 0 if it's a 6-digit code, or from startIndex
    final start = digits.length >= 6 ? 0 : startIndex;
    for (int i = 0; i < 6 && (i - start) < digits.length; i++) {
      if (i >= start) {
        final char = digits[i - start];
        _digitControllers[i].text = char;
      }
    }

    setState(() {});

    final filledCount = _digitControllers.where((c) => c.text.isNotEmpty).length;
    if (filledCount == 6) {
      _digitNodes[5].requestFocus();
      _submit();
    } else {
      final nextEmpty = _digitControllers.indexWhere((c) => c.text.isEmpty);
      if (nextEmpty >= 0 && nextEmpty < 6) {
        _digitNodes[nextEmpty].requestFocus();
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
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: TextInputType.number,
        textInputAction:
            index == 5 ? TextInputAction.done : TextInputAction.next,
        maxLength: 1,
        autofocus: index == 0,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.0,
          color: colorScheme.onSurface,
        ),
        cursorColor: colorScheme.primary,
        inputFormatters: [
          _DigitNormalizingInputFormatter(),
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

          if (value.length > 1) {
            _onPasteCode(value, index);
            return;
          }

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
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        6,
                        _buildDigitBox,
                      ),
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

class _DigitNormalizingInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = _VerifyAccountScreenState.normalizeDigits(newValue.text);
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}
