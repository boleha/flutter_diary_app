import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WriteDiaryHeader extends StatelessWidget {
  final DateTime selectedDate;
  final ValueListenable<bool> isLoadingListenable;
  final VoidCallback onSave;

  const WriteDiaryHeader({
    super.key,
    required this.selectedDate,
    required this.isLoadingListenable,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Row(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              _buildDateText('${selectedDate.year}', 28, textColor),
              _buildDateText('年', 14, textColor),
              _buildDateText('${selectedDate.month}', 28, textColor),
              _buildDateText('月', 14, textColor),
              _buildDateText('${selectedDate.day}', 28, textColor),
              _buildDateText('日', 14, textColor),
            ],
          ),
          const Spacer(),
          ValueListenableBuilder<bool>(
            valueListenable: isLoadingListenable,
            builder: (context, isLoading, _) {
              return IconButton(
                icon: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                onPressed: isLoading ? null : onSave,
                tooltip: '保存日记',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateText(String text, double fontSize, Color color) {
    return Text(
      text,
      style: GoogleFonts.righteous(fontSize: fontSize, color: color),
    );
  }
}

class WriteDiaryTimestamp extends StatelessWidget {
  final String text;
  final Color color;

  const WriteDiaryTimestamp({
    super.key,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color),
        textAlign: TextAlign.center,
      ),
    );
  }
}
