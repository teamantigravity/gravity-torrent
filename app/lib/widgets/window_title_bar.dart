import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

class WindowTitleBar extends StatefulWidget implements PreferredSizeWidget {
  const WindowTitleBar({super.key, this.leading, this.backgroundColor});

  final Widget? leading;
  final Color? backgroundColor;

  @override
  Size get preferredSize => const Size(0, kYaruTitleBarHeight);

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<YaruWindowState>(
      stream: YaruWindow.states(context),
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isMaximized = state?.isMaximized == true;
        return YaruWindowTitleBar(
          leading: widget.leading,
          backgroundColor: widget.backgroundColor ??
              Theme.of(context).scaffoldBackgroundColor,
          border: BorderSide.none,
          isActive: state?.isActive,
          isMaximizable: (state?.isMaximizable ?? true) && !isMaximized,
          isMinimizable: state?.isMinimizable ?? true,
          isRestorable: isMaximized,
        );
      },
    );
  }
}
