import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'flowchart_editor_dialog.dart';

class FlowchartWidget extends StatefulWidget {
  final Map<String, dynamic> flowchartData;
  final Function(Map<String, dynamic>)? onChanged;
  final bool isEditable;
  final bool showCustomizeButton;

  const FlowchartWidget({
    super.key,
    required this.flowchartData,
    this.onChanged,
    this.isEditable = false,
    this.showCustomizeButton = true,
  });

  @override
  State<FlowchartWidget> createState() => _FlowchartWidgetState();
}

class _FlowchartWidgetState extends State<FlowchartWidget> {
  final Graph graph = Graph()..isTree = false;
  final BuchheimWalkerConfiguration builder = BuchheimWalkerConfiguration();

  final List<Map<String, dynamic>> _nodes = [];
  final List<Map<String, dynamic>> _edges = [];
  final Map<String, Node> _nodeMap = {};

  final Map<String, Offset> _manualPositions = {};
  Key _graphKey = UniqueKey();

  late final BuchheimWalkerAlgorithm _algorithm = BuchheimWalkerAlgorithm(
    builder,
    TreeEdgeRenderer(builder),
  );

  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _initializeData();

    builder
      ..siblingSeparation = (80)
      ..levelSeparation = (100)
      ..subtreeSeparation = (100)
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT;
  }

  void _initializeData() {
    _nodes.clear();
    _edges.clear();

    final nodesData = widget.flowchartData['nodes'] as List<dynamic>? ?? [];
    final edgesData = widget.flowchartData['edges'] as List<dynamic>? ?? [];

    for (var n in nodesData) {
      _nodes.add(Map<String, dynamic>.from(n));
      if (n['x'] != null && n['y'] != null) {
        _manualPositions[n['id'].toString()] = Offset(
          (n['x'] as num).toDouble(),
          (n['y'] as num).toDouble(),
        );
      }
    }
    for (var e in edgesData) {
      _edges.add(Map<String, dynamic>.from(e));
    }
    _rebuildGraph();
  }

  @override
  void didUpdateWidget(FlowchartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flowchartData != oldWidget.flowchartData) {
      setState(() {
        _initializeData();
        _graphKey = UniqueKey();
      });
    }
  }

  void _rebuildGraph() {
    graph.nodes.clear();
    final List<Edge> edgesToRemove = List.from(graph.edges);
    for (var edge in edgesToRemove) {
      graph.removeEdge(edge);
    }
    _nodeMap.clear();

    for (var nodeData in _nodes) {
      final id = nodeData['id'].toString();
      final node = Node.Id(id);
      _nodeMap[id] = node;
      graph.addNode(node);

      if (_manualPositions.containsKey(id)) {
        node.position = _manualPositions[id]!;
      }
    }

    for (var edgeData in _edges) {
      final from = edgeData['from'].toString();
      final to = edgeData['to'].toString();
      if (_nodeMap.containsKey(from) && _nodeMap.containsKey(to)) {
        graph.addEdge(_nodeMap[from]!, _nodeMap[to]!);
      }
    }
  }

  void _zoomIn() {
    final Matrix4 matrix = _transformationController.value.clone();
    matrix.scale(1.15, 1.15);
    _transformationController.value = matrix;
  }

  void _zoomOut() {
    final Matrix4 matrix = _transformationController.value.clone();
    matrix.scale(1 / 1.15, 1 / 1.15);
    _transformationController.value = matrix;
  }

  void _resetZoom() {
    setState(() {
      _transformationController.value = Matrix4.identity();
      _manualPositions.clear();
      _graphKey = UniqueKey();
      _rebuildGraph();
    });
  }

  Future<void> _openEditor() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          FlowchartEditorDialog(initialData: widget.flowchartData),
    );

    if (result != null && widget.onChanged != null) {
      widget.onChanged!(result);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditable = widget.isEditable;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Update orientation based on device
    builder.orientation = isMobile
        ? BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM
        : BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT;

    builder.siblingSeparation = (isMobile ? 40 : 80);
    builder.levelSeparation = (isMobile ? 60 : 100);

    return ClipRect(
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: Stack(
          children: [
            // Background Dots
            Positioned.fill(
              child: CustomPaint(
                painter: GridPainter(
                  gridColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
            ),
            InteractiveViewer(
              transformationController: _transformationController,
              constrained: false,
              boundaryMargin: isEditable
                  ? const EdgeInsets.all(2000)
                  : const EdgeInsets.all(400),
              minScale: 0.05,
              maxScale: 2.5,
              scaleEnabled: true,
              panEnabled: true,
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 40 : 120,
                  vertical: isMobile ? 60 : 100,
                ),
                child: GraphView(
                  key: _graphKey,
                  graph: graph,
                  algorithm: _algorithm,
                  paint: Paint()
                    ..color = isDark
                        ? theme.colorScheme.primary.withValues(alpha: 0.5)
                        : theme.colorScheme.primary.withValues(alpha: 0.4)
                    ..strokeWidth = 2.0
                    ..style = PaintingStyle.stroke,
                  builder: (Node node) {
                    final id = node.key!.value.toString();
                    final nodeData = _nodes.firstWhere(
                      (n) => n['id'].toString() == id,
                      orElse: () => {},
                    );
                    if (nodeData.isEmpty) return const SizedBox();

                    final label = nodeData['label'] ?? '';
                    final colorValue = nodeData['color'];

                    Color nodeBackground;
                    if (colorValue is int) {
                      nodeBackground = Color(colorValue);
                    } else {
                      nodeBackground = isDark
                          ? theme.colorScheme.secondaryContainer
                          : theme.colorScheme.primaryContainer;
                    }

                    return _buildNode(
                      id,
                      label,
                      nodeBackground,
                      theme,
                      node,
                      isDark,
                    );
                  },
                ),
              ),
            ),
            // Tool Buttons
            Positioned(
              right: isMobile ? 12 : 24,
              bottom: isMobile ? 12 : 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.showCustomizeButton && !isEditable)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FloatingActionButton.extended(
                        heroTag: 'customize_flowchart_fab',
                        onPressed: _openEditor,
                        icon: const Icon(Icons.auto_fix_high_rounded),
                        label: const Text("Customize"),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        elevation: 6,
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.cardColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToolButton(Icons.zoom_in, _zoomIn, "Zoom In"),
                        _buildToolButton(Icons.zoom_out, _zoomOut, "Zoom Out"),
                        _buildToolButton(
                          Icons.center_focus_strong,
                          _resetZoom,
                          "Reset",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton(
    IconData icon,
    VoidCallback onPressed,
    String tooltip,
  ) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: theme.colorScheme.primary),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildNode(
    String id,
    String label,
    Color color,
    ThemeData theme,
    Node node,
    bool isDark,
  ) {
    // Determine contrast color
    final textColor = color.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return Container(
      constraints: const BoxConstraints(maxWidth: 180, minWidth: 90),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Potential for node-specific actions
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: textColor,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color gridColor;
  final double spacing;
  GridPainter({required this.gridColor, this.spacing = 30.0});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeCap = StrokeCap.round;
    for (double i = 0; i < size.width; i += spacing) {
      for (double j = 0; j < size.height; j += spacing) {
        canvas.drawCircle(Offset(i, j), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => false;
}
