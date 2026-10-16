import 'package:flutter/material.dart';
import 'cloud_store.dart' show friendlyError;
import 'design.dart';

class ProfileDialog extends StatefulWidget {
  final String initialName;
  final Future<void> Function(String) save;
  const ProfileDialog(
      {super.key, required this.initialName, required this.save});
  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  late final name = TextEditingController(text: widget.initialName);
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.save(name.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !busy,
        child: AlertDialog(
          title: const Text('Your username'),
          content: Form(
              key: form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CartoonAvatar(size: 56),
                const SizedBox(height: 16),
                TextFormField(
                    controller: name,
                    autofocus: true,
                    enabled: !busy,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Username'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Choose a username.' : null),
                if (error != null)
                  Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ])),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Saving…' : 'Save username')),
          ],
        ),
      );
}

class CartoonAvatar extends StatelessWidget {
  final double size;
  const CartoonAvatar({super.key, this.size = 32});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: CustomPaint(size: Size.square(size), painter: _AvatarPainter()));
}

class _AvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);
    canvas.clipPath(Path()..addOval(const Rect.fromLTWH(0, 0, 40, 40)));
    final brush = Paint();
    canvas.drawCircle(
        const Offset(20, 20), 20, brush..color = const Color(0xff293e32));
    canvas.drawOval(const Rect.fromLTWH(6, 29, 28, 25), brush..color = accent);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(16, 24, 8, 9), const Radius.circular(3)),
        brush..color = const Color(0xffdba77c));
    canvas.drawOval(const Rect.fromLTWH(10, 7, 20, 23),
        brush..color = const Color(0xffffcd9d));
    canvas.drawPath(
        Path()
          ..moveTo(10, 17)
          ..lineTo(10, 12)
          ..quadraticBezierTo(11, 4, 21, 5)
          ..quadraticBezierTo(31, 5, 30, 16)
          ..lineTo(26, 11)
          ..quadraticBezierTo(18, 16, 13, 11)
          ..close(),
        brush..color = const Color(0xff49352c));
    brush.color = paper;
    canvas.drawCircle(const Offset(16, 19), 1.1, brush);
    canvas.drawCircle(const Offset(24, 19), 1.1, brush);
    canvas.drawArc(
        const Rect.fromLTWH(16, 20, 8, 6),
        .2,
        2.7,
        false,
        brush
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) => false;
}
