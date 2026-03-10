import 'package:flutter/material.dart';
import 'flowchart_widget.dart';

class FlowchartEditorDialog extends StatefulWidget {
  final Map<String, dynamic> initialData;

  const FlowchartEditorDialog({super.key, required this.initialData});

  @override
  State<FlowchartEditorDialog> createState() => _FlowchartEditorDialogState();
}

class _FlowchartEditorDialogState extends State<FlowchartEditorDialog> {
  late List<Map<String, dynamic>> _nodes;
  late List<Map<String, dynamic>> _edges;

  // Track controllers to avoid disposal/recreation issues during list rebuilds
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    final nodesData = widget.initialData['nodes'] as List<dynamic>? ?? [];
    final edgesData = widget.initialData['edges'] as List<dynamic>? ?? [];

    _nodes = nodesData.map((n) => Map<String, dynamic>.from(n)).toList();
    _edges = edgesData.map((e) => Map<String, dynamic>.from(e)).toList();

    for (var node in _nodes) {
      _controllers[node['id']] = TextEditingController(text: node['label']);
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addNode() {
    final id = "node_${DateTime.now().millisecondsSinceEpoch}";
    setState(() {
      _nodes.add({
        'id': id,
        'label': 'New Node',
        'color': Colors.blue[100]!.value,
      });
      _controllers[id] = TextEditingController(text: 'New Node');
    });
  }

  void _removeNode(String id) {
    setState(() {
      _nodes.removeWhere((n) => n['id'] == id);
      _edges.removeWhere((e) => e['from'] == id || e['to'] == id);
      _controllers[id]?.dispose();
      _controllers.remove(id);
    });
  }

  void _updateLabels() {
    setState(() {
      for (var node in _nodes) {
        node['label'] = _controllers[node['id']]?.text ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Manual Flowchart Editor"),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton.icon(
              onPressed: _addNode,
              icon: const Icon(Icons.add),
              label: const Text("Add Node"),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                _updateLabels();
                Navigator.pop(context, {'nodes': _nodes, 'edges': _edges});
              },
              child: const Text("Apply & Save"),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Row(
          children: [
            // Left Pane: Editor Form
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: theme.dividerColor)),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: _nodes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final node = _nodes[index];
                    final id = node['id'];

                    // Find parent
                    final edge = _edges.firstWhere(
                      (e) => e['to'] == id,
                      orElse: () => {},
                    );
                    String? parentId = edge.isNotEmpty ? edge['from'] : null;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: theme.dividerColor),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _controllers[id],
                                    decoration: const InputDecoration(
                                      labelText: "Node Label",
                                      isDense: true,
                                    ),
                                    onChanged: (val) => node['label'] = val,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => _removeNode(id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: parentId,
                                    decoration: const InputDecoration(
                                      labelText: "Parent Node",
                                      isDense: true,
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: null,
                                        child: Text("None (Root)"),
                                      ),
                                      ..._nodes
                                          .where((n) => n['id'] != id)
                                          .map(
                                            (n) => DropdownMenuItem(
                                              value: n['id'].toString(),
                                              child: Text(
                                                n['label'].toString(),
                                              ),
                                            ),
                                          ),
                                    ],
                                    onChanged: (newParentId) {
                                      setState(() {
                                        _edges.removeWhere(
                                          (e) => e['to'] == id,
                                        );
                                        if (newParentId != null) {
                                          _edges.add({
                                            'from': newParentId,
                                            'to': id,
                                          });
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Color Selector
                                Wrap(
                                  spacing: 4,
                                  children:
                                      [
                                        Colors.blue[100]!,
                                        Colors.green[100]!,
                                        Colors.orange[100]!,
                                        Colors.red[100]!,
                                        Colors.purple[100]!,
                                      ].map((c) {
                                        final bool isSelected =
                                            node['color'] == c.value;
                                        return GestureDetector(
                                          onTap: () => setState(
                                            () => node['color'] = c.value,
                                          ),
                                          child: CircleAvatar(
                                            radius: 12,
                                            backgroundColor: c,
                                            child: isSelected
                                                ? const Icon(
                                                    Icons.check,
                                                    size: 12,
                                                  )
                                                : null,
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Right Pane: Live Preview
            Expanded(
              flex: 6,
              child: Container(
                color: theme.brightness == Brightness.dark
                    ? Colors.black26
                    : Colors.grey[50],
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: theme.cardColor,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Live Preview",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: _updateLabels,
                            icon: const Icon(Icons.refresh),
                            label: const Text("Refresh Preview"),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: FlowchartWidget(
                        flowchartData: {'nodes': _nodes, 'edges': _edges},
                        isEditable: false, // Keep preview static
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
