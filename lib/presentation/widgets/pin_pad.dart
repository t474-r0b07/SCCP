import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/constants/app_constants.dart';

class PinPad extends StatefulWidget {
  final Function(String) onComplete;
  final String title;
  final int pinLength;

  const PinPad({
    super.key,
    required this.onComplete,
    this.title = 'INGRESE PIN DE SEGURIDAD',
    this.pinLength = 4,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  List<int> _shuffledNumbers = [];

  @override
  void initState() {
    super.initState();
    _shuffleNumbers();
  }

  void _shuffleNumbers() {
    _shuffledNumbers = List.generate(10, (index) => index);
    _shuffledNumbers.shuffle(Random());
  }

  void _onNumberPressed(int number) {
    if (_pin.length < widget.pinLength) {
      setState(() {
        _pin += number.toString();
      });

      if (_pin.length == widget.pinLength) {
        Future.delayed(const Duration(milliseconds: 300), () {
          widget.onComplete(_pin);
          setState(() {
            _pin = '';
            _shuffleNumbers();
          });
        });
      }
    }
  }

  void _onDeletePressed() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingL),
      decoration: BoxDecoration(
        color: AppConstants.darkPanel,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppConstants.neonCyan.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppConstants.neonCyan.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: AppConstants.paddingL),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.pinLength,
              (index) => Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < _pin.length
                      ? AppConstants.neonCyan
                      : AppConstants.gridColor,
                  boxShadow: index < _pin.length
                      ? [
                          BoxShadow(
                            color: AppConstants.neonCyan.withValues(alpha: 0.5),
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.paddingL),
          SizedBox(
            width: 280,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                if (index == 9) {
                  return const SizedBox(); // Empty space
                } else if (index == 10) {
                  return _buildNumberButton(_shuffledNumbers[0]);
                } else if (index == 11) {
                  return _buildDeleteButton();
                } else {
                  return _buildNumberButton(_shuffledNumbers[index + 1]);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberButton(int number) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onNumberPressed(number),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        child: Container(
          decoration: BoxDecoration(
            color: AppConstants.darkBg,
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
            border: Border.all(
              color: AppConstants.neonCyan.withValues(alpha: 0.3),
            ),
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: AppConstants.neonCyan,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onDeletePressed,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        child: Container(
          decoration: BoxDecoration(
            color: AppConstants.warningRed.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
            border: Border.all(
              color: AppConstants.warningRed.withValues(alpha: 0.5),
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.backspace_outlined,
              color: AppConstants.warningRed,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
