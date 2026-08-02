import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'model/car_profile.dart';
import 'model/octane_log.dart';
import 'services/analytics_service.dart';
import 'utils/display_format.dart';

class HistoryDetailPage extends StatefulWidget {
  final OctaneLog log;
  final dynamic logKey;

  const HistoryDetailPage({super.key, required this.log, required this.logKey});

  static const Map<String, String> inputLabelMap = {
    'highLiter': '고급유 주유량 (L)',
    'regularLiter': '일반유 주유량 (L)',
    'beforeLiter': '기존 연료량 (L)',
    'beforeOctane': '기존 연료 옥탄가',
    'addLiter': '추가 주유량 (L)',
    'addOctane': '추가 연료 옥탄가',
    'tankCapacity': '탱크 용량 (L)',
    'targetOctane': '목표 옥탄가',
    'currentLiter': '현재 남은 연료량 (L)',
    'currentOctane': '현재 추정 옥탄가',
    'fuelOctane': '넣을 연료 옥탄가',
    'requiredLiter': '필요 주유량 (L)',
    'unitPrice': '리터당 단가 (원)',
    'highUnitPrice': '고급유 리터당 단가 (원)',
    'highTotalCost': '고급유 총액 (원)',
    'regularUnitPrice': '일반유 리터당 단가 (원)',
    'regularTotalCost': '일반유 총액 (원)',
    'totalCost': '총 주유 금액 (원)',
    'station': '주유 장소',
  };

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  late OctaneLog _log;

  @override
  void initState() {
    super.initState();
    _log = widget.log;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status(_log.result);
    final visibleInputs = _log.inputs.entries.where(_shouldShowInput).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('기록 상세'),
        actions: [
          IconButton(
            tooltip: '기록 수정',
            onPressed: _showEditSheet,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '기록 삭제',
            onPressed: _confirmDelete,
            color: Colors.redAccent,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(
            title: '계산 정보',
            children: [
              _row('계산 방식', _typeTitle(_log.type)),
              _row(
                '계산 시각',
                '${_log.time.year}.${_log.time.month.toString().padLeft(2, '0')}.${_log.time.day.toString().padLeft(2, '0')} '
                    '${_log.time.hour.toString().padLeft(2, '0')}:${_log.time.minute.toString().padLeft(2, '0')}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoCard(
            title: '입력값',
            children:
                visibleInputs.isEmpty
                    ? [
                      const Text(
                        '저장된 계산 입력값이 없습니다.',
                        style: TextStyle(color: Color(0xFF97A4B1)),
                      ),
                    ]
                    : visibleInputs.map((entry) {
                      final label =
                          HistoryDetailPage.inputLabelMap[entry.key] ??
                          entry.key;
                      return _row(
                        label,
                        DisplayFormat.inputValue(entry.key, entry.value),
                      );
                    }).toList(),
          ),
          if (_log.memo.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoCard(
              title: '메모',
              children: [
                Text(
                  _log.memo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      DisplayFormat.ron(_log.result, detail: true),
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status.label,
                      style: TextStyle(
                        color: status.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    status.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('기록 삭제'),
                content: const Text('이 기록을 삭제할까요? 삭제 후에는 복구할 수 없습니다.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('삭제'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    await Hive.box<OctaneLog>('octane_logs').delete(widget.logKey);
    AnalyticsService.log('record_deleted');
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context, true);
    messenger.showSnackBar(const SnackBar(content: Text('기록을 삭제했습니다.')));
  }

  Future<void> _showEditSheet() async {
    final inputKeys = _editableInputKeys(_log.type);
    final controllers = {
      for (final key in inputKeys)
        key: TextEditingController(text: _log.inputs[key]?.toString() ?? ''),
    };
    final memoController = TextEditingController(text: _log.memo);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
            top: 4,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                '${_typeTitle(_log.type)} 수정',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ...inputKeys.map((key) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[key],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: HistoryDetailPage.inputLabelMap[key] ?? key,
                    ),
                  ),
                );
              }),
              TextField(
                controller: memoController,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: '메모',
                  hintText: '기록 메모',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final updatedInputs = Map<String, dynamic>.from(_log.inputs);
                  for (final key in inputKeys) {
                    final text = controllers[key]!.text.trim();
                    if (text.isEmpty && _optionalInputKeys.contains(key)) {
                      updatedInputs.remove(key);
                    } else {
                      updatedInputs[key] = text;
                    }
                  }

                  final updated = _buildUpdatedLog(
                    inputs: updatedInputs,
                    memo: memoController.text.trim(),
                  );
                  if (updated == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('입력값을 확인해 주세요.')),
                    );
                    return;
                  }

                  await Hive.box<OctaneLog>(
                    'octane_logs',
                  ).put(widget.logKey, updated);
                  if (!mounted || !context.mounted) return;
                  AnalyticsService.log('record_edited');
                  setState(() {
                    _log = updated;
                  });
                  Navigator.pop(context, true);
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('수정 저장'),
              ),
            ],
          ),
        );
      },
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }
    memoController.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('기록을 수정했습니다.')));
    }
  }

  List<String> _editableInputKeys(String type) {
    final keys = switch (type) {
      'average' => [
        'highLiter',
        'regularLiter',
        'highUnitPrice',
        'highTotalCost',
        'regularUnitPrice',
        'regularTotalCost',
      ],
      'mixed' => [
        'beforeLiter',
        'beforeOctane',
        'addLiter',
        'addOctane',
        'tankCapacity',
      ],
      'target' => [
        'targetOctane',
        'currentLiter',
        'currentOctane',
        'fuelOctane',
      ],
      _ => <String>[],
    };

    return [...keys, if (type != 'average') 'unitPrice', 'totalCost'];
  }

  bool _shouldShowInput(MapEntry<String, dynamic> entry) {
    if (!DisplayFormat.hasValue(entry.value)) return false;
    if (!_optionalInputKeys.contains(entry.key)) return true;
    final number = DisplayFormat.asDouble(entry.value);
    return number == null || number > 0;
  }

  static const _optionalInputKeys = {
    'tankCapacity',
    'unitPrice',
    'highUnitPrice',
    'highTotalCost',
    'regularUnitPrice',
    'regularTotalCost',
    'totalCost',
    'station',
  };

  OctaneLog? _buildUpdatedLog({
    required Map<String, dynamic> inputs,
    required String memo,
  }) {
    final result = _recalculateResult(_log.type, inputs);
    if (result == null || result <= 0 || result.isNaN || result.isInfinite) {
      return null;
    }

    final normalizedInputs = Map<String, dynamic>.from(inputs);
    if (_log.type == 'target') {
      final requiredLiter = _targetRequiredLiter(normalizedInputs);
      if (requiredLiter == null || requiredLiter.isInfinite) {
        return null;
      }
      normalizedInputs['requiredLiter'] = requiredLiter.toStringAsFixed(1);
    }

    return OctaneLog(
      time: _log.time,
      type: _log.type,
      result: result,
      inputs: normalizedInputs,
      memo: memo,
    );
  }

  double? _recalculateResult(String type, Map<String, dynamic> inputs) {
    double? value(String key) {
      return double.tryParse(inputs[key]?.toString().trim() ?? '');
    }

    if (type == 'average') {
      final high = value('highLiter');
      final regular = value('regularLiter');
      if (high == null || regular == null) return null;
      final total = high + regular;
      if (total <= 0) return null;
      return ((high * 97) + (regular * 92)) / total;
    }

    if (type == 'mixed') {
      final beforeLiter = value('beforeLiter');
      final beforeOctane = value('beforeOctane');
      final addLiter = value('addLiter');
      final addOctane = value('addOctane');
      if (beforeLiter == null ||
          beforeOctane == null ||
          addLiter == null ||
          addOctane == null) {
        return null;
      }
      final total = beforeLiter + addLiter;
      if (total <= 0) return null;
      return ((beforeLiter * beforeOctane) + (addLiter * addOctane)) / total;
    }

    if (type == 'target') {
      final target = value('targetOctane');
      final currentOctane = value('currentOctane');
      final requiredLiter = _targetRequiredLiter(inputs);
      if (target == null || currentOctane == null || requiredLiter == null) {
        return null;
      }
      if (requiredLiter.isInfinite) return null;
      return currentOctane >= target ? currentOctane : target;
    }

    return null;
  }

  double? _targetRequiredLiter(Map<String, dynamic> inputs) {
    final target = double.tryParse(
      inputs['targetOctane']?.toString().trim() ?? '',
    );
    final currentLiter = double.tryParse(
      inputs['currentLiter']?.toString().trim() ?? '',
    );
    final currentOctane = double.tryParse(
      inputs['currentOctane']?.toString().trim() ?? '',
    );
    final fuelOctane = double.tryParse(
      inputs['fuelOctane']?.toString().trim() ?? '',
    );

    if (target == null ||
        currentLiter == null ||
        currentOctane == null ||
        fuelOctane == null ||
        target <= 0 ||
        currentLiter <= 0 ||
        currentOctane <= 0 ||
        fuelOctane <= 0) {
      return null;
    }

    if (currentOctane >= target) return 0;
    if (fuelOctane <= target) return double.infinity;
    return ((target - currentOctane) * currentLiter) / (fuelOctane - target);
  }

  Widget _infoCard({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _typeTitle(String type) {
    switch (type) {
      case 'average':
        return '단순 혼합';
      case 'mixed':
        return '탱크 기준';
      case 'target':
        return '목표 맞추기';
      default:
        return type;
    }
  }

  _DetailStatus _status(double value) {
    final car = Hive.box<CarProfile>('car_profile').get('main');
    if (car == null) {
      return const _DetailStatus(
        '차량 기준 미설정',
        '차량 정보를 저장하면 권장/경고 기준으로 결과를 판단합니다.',
        Colors.blueGrey,
      );
    }

    final recommend = car.recommendedOctane;
    final warning = car.warningOctane;

    if (value >= recommend) {
      return const _DetailStatus(
        '권장 기준 충족',
        '차량 기준에서 권장 옥탄가를 충족한 상태입니다.',
        Colors.green,
      );
    } else if (value >= warning) {
      return const _DetailStatus(
        '일반 주행 적합',
        '일상 주행에는 무리가 없지만 다음 주유에서 보강하면 더 좋습니다.',
        Colors.orange,
      );
    } else {
      return const _DetailStatus(
        '고부하 주행 주의',
        '노킹 가능성을 줄이기 위해 고부하 주행을 피하고 옥탄가를 보강해 주세요.',
        Colors.red,
      );
    }
  }
}

class _DetailStatus {
  final String label;
  final String message;
  final Color color;

  const _DetailStatus(this.label, this.message, this.color);
}
