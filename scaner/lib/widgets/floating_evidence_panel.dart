import 'package:flutter/material.dart';

class EvidenceItem {
  final String category;
  final String detail;
  final double contribution;
  final bool isRisk;

  const EvidenceItem({
    required this.category,
    required this.detail,
    required this.contribution,
    required this.isRisk,
  });
}

class FloatingEvidencePanel extends StatefulWidget {
  final List<EvidenceItem> items;
  final double overallScore;
  final String title;

  const FloatingEvidencePanel({
    super.key,
    required this.items,
    required this.overallScore,
    required this.title,
  });

  @override
  State<FloatingEvidencePanel> createState() => _FloatingEvidencePanelState();
}

class _FloatingEvidencePanelState extends State<FloatingEvidencePanel>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(16, 80);
  bool _isMinimized = false;
  bool _initialized = false;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color get _riskColor {
    if (widget.overallScore >= 0.6) return Colors.red.shade600;
    if (widget.overallScore >= 0.3) return Colors.orange.shade700;
    return Colors.green.shade600;
  }

  Color get _bgColor {
    if (widget.overallScore >= 0.6) return Colors.red.shade50;
    if (widget.overallScore >= 0.3) return Colors.orange.shade50;
    return Colors.green.shade50;
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      final size = MediaQuery.of(context).size;
      _position = Offset(size.width - 300, 88);
      _initialized = true;
    }

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: ScaleTransition(
        scale: _scaleAnim,
        alignment: Alignment.topRight,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              final size = MediaQuery.of(context).size;
              final newX = (_position.dx + details.delta.dx).clamp(0.0, size.width - 284);
              final newY = (_position.dy + details.delta.dy).clamp(0.0, size.height - 80);
              _position = Offset(newX, newY);
            });
          },
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(14),
            shadowColor: _riskColor.withValues(alpha: 0.3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isMinimized ? null : 284,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _riskColor.withValues(alpha: 0.4), width: 1.5),
              ),
              child: _isMinimized ? _buildMinimized() : _buildExpanded(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimized() {
    final riskCount = widget.items.where((i) => i.isRisk).length;
    final safeCount = widget.items.where((i) => !i.isRisk).length;
    return InkWell(
      onTap: () => setState(() => _isMinimized = false),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined, size: 16, color: _riskColor),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '判斷依據',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _riskColor,
                  ),
                ),
                Text(
                  '⚠ $riskCount  ✓ $safeCount',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 14, color: _riskColor),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        if (widget.items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '無明顯判斷依據',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Column(
                  children: widget.items.map(_buildEvidenceRow).toList(),
                ),
              ),
            ),
          ),
        _buildRiskBar(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.analytics_outlined, size: 15, color: _riskColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _riskColor,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _isMinimized = true),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: _riskColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.remove, size: 13, color: _riskColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceRow(EvidenceItem item) {
    final color = item.isRisk ? Colors.red.shade600 : Colors.green.shade600;
    final bgColor = item.isRisk ? Colors.red.shade50 : Colors.green.shade50;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.isRisk ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.category,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (item.detail.isNotEmpty)
                  Text(
                    item.detail,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (item.isRisk && item.contribution > 0)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '+${(item.contribution * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 9, color: Colors.red.shade700, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRiskBar() {
    final pct = (widget.overallScore * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '綜合風險分數',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              Text(
                '$pct%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _riskColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: widget.overallScore,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(_riskColor),
              minHeight: 7,
            ),
          ),
        ],
      ),
    );
  }
}
