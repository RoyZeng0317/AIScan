import 'package:flutter/material.dart';

class ScanResultCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color valueColor;
  final List<Widget> children;

  const ScanResultCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.valueColor,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: valueColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
            if (children.isNotEmpty) ...[
              const Divider(height: 24),
              ...children,
            ],
          ],
        ),
      ),
    );
  }
}

class RiskIndicator extends StatelessWidget {
  final double score;
  final double size;

  const RiskIndicator({super.key, required this.score, this.size = 80});

  @override
  Widget build(BuildContext context) {
    final color = score >= 0.6
        ? Colors.red
        : score >= 0.3
            ? Colors.orange
            : Colors.green;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: score,
              strokeWidth: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            '${(score * 100).toInt()}%',
            style: TextStyle(
              fontSize: size * 0.22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  final String label;
  final double value;

  const DetailRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value >= 0.5 ? Colors.red : value >= 0.2 ? Colors.orange : Colors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
