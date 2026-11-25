import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData? icon;
  final ValueChanged<String>? onSubmitted;

  const PasswordField({
    required this.controller,
    required this.label,
    this.hintText,
    this.icon,
    this.onSubmitted,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        hintStyle: TextStyle(color: Colors.blueGrey.shade500),
        labelStyle: TextStyle(color: Colors.blueGrey.shade300),
        prefixIcon: widget.icon != null
            ? Icon(widget.icon, color: Colors.blueGrey.shade400)
            : null,
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.blueGrey.shade400,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        filled: true,
        fillColor: Colors.blueGrey.shade800,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      onSubmitted: widget.onSubmitted,
    );
  }
}

@Preview(
  name: 'PasswordField',
  size: Size(320, 80),
  brightness: Brightness.dark,
)
Widget passwordFieldPreview() => Padding(
  padding: const EdgeInsets.all(16),
  child: PasswordField(
    controller: _controller,
    label: '房间密码',
    hintText: '输入密码',
    icon: Icons.lock,
  ),
);

final _controller = TextEditingController();
