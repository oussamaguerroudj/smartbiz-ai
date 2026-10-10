import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuickSearchIntent extends Intent {
  const QuickSearchIntent();
}

class NewSaleIntent extends Intent {
  const NewSaleIntent();
}

class PrintIntent extends Intent {
  const PrintIntent();
}

class RefreshIntent extends Intent {
  const RefreshIntent();
}

class EscapeIntent extends Intent {
  const EscapeIntent();
}

class DesktopShortcutsWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onQuickSearch;
  final VoidCallback? onNewSale;
  final VoidCallback? onPrint;
  final VoidCallback? onRefresh;
  final VoidCallback? onEscape;

  const DesktopShortcutsWrapper({
    super.key,
    required this.child,
    this.onQuickSearch,
    this.onNewSale,
    this.onPrint,
    this.onRefresh,
    this.onEscape,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
            const QuickSearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
            const NewSaleIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyP):
            const PrintIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR):
            const RefreshIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const EscapeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          QuickSearchIntent: CallbackAction<QuickSearchIntent>(
            onInvoke: (_) => onQuickSearch?.call(),
          ),
          NewSaleIntent: CallbackAction<NewSaleIntent>(
            onInvoke: (_) => onNewSale?.call(),
          ),
          PrintIntent: CallbackAction<PrintIntent>(
            onInvoke: (_) => onPrint?.call(),
          ),
          RefreshIntent: CallbackAction<RefreshIntent>(
            onInvoke: (_) => onRefresh?.call(),
          ),
          EscapeIntent: CallbackAction<EscapeIntent>(
            onInvoke: (_) => onEscape?.call(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}
