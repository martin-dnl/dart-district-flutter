import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';

class DartInput extends StatefulWidget {
  final int maxScore;
  final ValueChanged<int> onSubmit;

  const DartInput({super.key, required this.maxScore, required this.onSubmit});

  @override
  State<DartInput> createState() => _DartInputState();
}

class _DartInputState extends State<DartInput> {
  String _input = '';

  void _addDigit(String digit) {
    if (_input.length >= 3) return;
    setState(() => _input += digit);
  }

  void _delete() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _submit() {
    if (_input.isEmpty) return;
    final score = int.tryParse(_input) ?? 0;
    if (score > 180) {
      // Max possible score per visit is 180
      setState(() => _input = '');
      return;
    }
    widget.onSubmit(score);
    setState(() => _input = '');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceLight, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Score display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _input.isEmpty ? '0' : _input,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: _input.isEmpty
                    ? AppColors.textHint
                    : AppColors.textPrimary,
              ),
            ),
          ),

          // Number pad
          _buildNumberPad(),
        ],
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        Row(children: [_numButton('1'), _numButton('2'), _numButton('3')]),
        Row(children: [_numButton('4'), _numButton('5'), _numButton('6')]),
        Row(children: [_numButton('7'), _numButton('8'), _numButton('9')]),
        Row(
          children: [
            _actionButton(
              Icons.backspace_outlined,
              _delete,
              color: AppColors.textHint,
            ),
            _numButton('0'),
            _actionButton(Icons.check, _submit, color: AppColors.primary),
          ],
        ),
      ],
    );
  }

  Widget _numButton(String digit) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _addDigit(digit),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              child: Text(
                digit,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: color == AppColors.primary
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: color ?? AppColors.textPrimary,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
