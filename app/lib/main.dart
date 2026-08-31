import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'history_detail_page.dart';
import 'model/car_profile.dart';
import 'model/octane_log.dart';
import 'services/analytics_service.dart';
import 'services/backup_service.dart';
import 'services/review_prompt_service.dart';
import 'utils/display_format.dart';
import 'utils/target_octane_calculator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFF7FAFC),
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFF7FAFC),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final imagePicker = ImagePickerPlatform.instance;
  if (imagePicker is ImagePickerAndroid) {
    imagePicker.useAndroidPhotoPicker = true;
  }

  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(OctaneLogAdapter());
  }
  await Hive.openBox<OctaneLog>('octane_logs');

  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(CarProfileAdapter());
  }

  await Hive.openBox<CarProfile>('car_profile');
  await ReviewPromptService.registerLaunch();
  await AnalyticsService.init();
  await AnalyticsService.logAppOpen();

  runApp(const OctaneApp());
}

class OctaneApp extends StatelessWidget {
  const OctaneApp({super.key});

  static const Color _brand = Color(0xFFD32F2F);
  static const Color _brandDark = Color(0xFFB71C1C);
  static const Color _bg = Color(0xFFF7FAFC);
  static const Color _card = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _brand,
        brightness: Brightness.light,
        primary: _brand,
        surface: _card,
      ),
      scaffoldBackgroundColor: _bg,
    );

    return MaterialApp(
      title: '고급유노트',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          titleTextStyle: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        dividerColor: const Color(0xFFE2E8F0),
        tabBarTheme: const TabBarThemeData(
          labelColor: _brand,
          unselectedLabelColor: Color(0xFF64748B),
          indicatorColor: _brand,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Color(0xFFE2E8F0),
          labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            backgroundColor: _brandDark,
            foregroundColor: Color(0xFFFFFFFF),
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: _card,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          isDense: true,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 22,
          ),
          hintStyle: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            borderSide: BorderSide(color: _brand, width: 1.8),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: _bg,
          surfaceTintColor: Colors.transparent,
          modalBackgroundColor: _bg,
          modalBarrierColor: Color(0xB3000000),
          dragHandleColor: Color(0xFF64748B),
          showDragHandle: true,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: _card,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const OctaneHomePage(),
    );
  }
}

class OctaneHomePage extends StatefulWidget {
  const OctaneHomePage({super.key});

  @override
  State<OctaneHomePage> createState() => _OctaneHomePageState();
}

class _OctaneHomePageState extends State<OctaneHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController highFuelCtrl = TextEditingController();
  final TextEditingController regFuelCtrl = TextEditingController();
  final TextEditingController highOctaneCtrl = TextEditingController(
    text: '97',
  );
  final TextEditingController regularOctaneCtrl = TextEditingController(
    text: '92',
  );

  final TextEditingController beforeLiterCtrl = TextEditingController();
  final TextEditingController beforeOctaneCtrl = TextEditingController();
  final TextEditingController addLiterCtrl = TextEditingController();
  final TextEditingController addOctaneCtrl = TextEditingController();
  final TextEditingController mixTankCtrl = TextEditingController();

  final TextEditingController targetOctaneCtrl = TextEditingController();
  final TextEditingController targetCurrentLiterCtrl = TextEditingController();
  final TextEditingController targetCurrentOctaneCtrl = TextEditingController();
  final TextEditingController targetFuelOctaneCtrl = TextEditingController();

  final TextEditingController carNameCtrl = TextEditingController();
  final TextEditingController carYearCtrl = TextEditingController();
  final TextEditingController carRecCtrl = TextEditingController();
  final TextEditingController carWarnCtrl = TextEditingController();
  final TextEditingController carTankCtrl = TextEditingController();
  final TextEditingController recordSearchCtrl = TextEditingController();

  Uint8List? _selectedCarPhoto;

  double? _avgResult;

  double? _mixResult;

  double? _targetRequiredLiter;
  String? _targetComment;
  bool _targetImpossible = false;
  double? _targetResultOctane;
  double? _targetTotalLiter;
  bool _isTankMixedRefuel = false;
  bool _isTankCapacityExpanded = false;
  String? _tankInputMessage;

  int _currentMainTab = 0;
  int _recordFilter = 0;
  bool _recordSearchVisible = false;
  bool _reviewPromptInProgress = false;
  bool _dataOperationInProgress = false;
  double? _touchedValue;
  int? _selectedSpotIndex;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(_syncMainTab);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await _showOnboardingIfNeeded();
    });
  }

  void _syncMainTab() {
    if (_currentMainTab == _tabController.index) return;
    setState(() {
      _currentMainTab = _tabController.index;
    });
    _logMainTabOpen(_currentMainTab);
  }

  void _logMainTabOpen(int index) {
    if (index == 1) {
      AnalyticsService.log('open_records');
    } else if (index == 2) {
      AnalyticsService.log('open_calculator');
    } else if (index == 3) {
      AnalyticsService.log('open_stats');
    } else if (index == 4) {
      AnalyticsService.log('open_vehicle');
    } else if (index == 5) {
      AnalyticsService.log('open_more');
    }
  }

  void _goToMainTab(int index) {
    if (index == 2 && _calcMode == 1) {
      _prefillTankOctaneFromLatestRecord();
    }
    setState(() => _currentMainTab = index);
    _logMainTabOpen(index);
    _tabController.animateTo(index);
  }

  void _prefillTankOctaneFromLatestRecord() {
    if (beforeOctaneCtrl.text.trim().isNotEmpty) return;

    final box = Hive.box<OctaneLog>('octane_logs');
    if (box.isEmpty) return;

    beforeOctaneCtrl.text = DisplayFormat.decimal(box.values.last.result, 2);
  }

  Future<void> _showOnboardingIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('onboarding_shown_v1') ?? false;
    if (alreadyShown || !mounted) return;

    Future<void> finish() async {
      await prefs.setBool('onboarding_shown_v1', true);
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.local_gas_station_rounded,
                    color: Color(0xFFD32F2F),
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '고급유 노트',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '내 차의 연료 상태를 기록하고 관리하세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                const _OnboardingStep(
                  number: '1',
                  title: '차량 등록',
                  icon: Icons.directions_car_outlined,
                ),
                const _OnboardingStep(
                  number: '2',
                  title: '주유 기록 작성',
                  icon: Icons.receipt_long_outlined,
                ),
                const _OnboardingStep(
                  number: '3',
                  title: '내 차량 기준으로 옥탄가 확인',
                  icon: Icons.speed_outlined,
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: finish,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('시작하기'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteLog(int indexFromTop) async {
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

    if (!confirmed) return;

    final box = Hive.box<OctaneLog>('octane_logs');
    await box.deleteAt(box.length - 1 - indexFromTop);
    AnalyticsService.log('record_deleted');

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('기록을 삭제했습니다.')));
  }

  Future<void> _confirmDeleteCar(Box<CarProfile> box) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('차량 정보 삭제'),
                content: const Text('저장된 차량 정보를 삭제할까요? 기준 옥탄가 설정도 함께 지워집니다.'),
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

    if (!confirmed) return;

    box.delete('main');
    carNameCtrl.clear();
    carYearCtrl.clear();
    carRecCtrl.clear();
    carWarnCtrl.clear();
    carTankCtrl.clear();
    setState(() => _selectedCarPhoto = null);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('차량 정보를 삭제했습니다.')));
  }

  @override
  void dispose() {
    _tabController.removeListener(_syncMainTab);
    _tabController.dispose();
    highFuelCtrl.dispose();
    regFuelCtrl.dispose();
    highOctaneCtrl.dispose();
    regularOctaneCtrl.dispose();
    beforeLiterCtrl.dispose();
    beforeOctaneCtrl.dispose();
    addLiterCtrl.dispose();
    addOctaneCtrl.dispose();
    mixTankCtrl.dispose();
    targetOctaneCtrl.dispose();
    targetCurrentLiterCtrl.dispose();
    targetCurrentOctaneCtrl.dispose();
    targetFuelOctaneCtrl.dispose();
    carNameCtrl.dispose();
    carYearCtrl.dispose();
    carRecCtrl.dispose();
    carWarnCtrl.dispose();
    carTankCtrl.dispose();
    recordSearchCtrl.dispose();

    super.dispose();
  }

  double _parseDouble(TextEditingController ctrl) {
    return double.tryParse(ctrl.text.trim()) ?? 0;
  }

  double _weightedOctane({
    required double premiumLiter,
    required double premiumRon,
    required double regularLiter,
    required double regularRon,
  }) {
    final total = premiumLiter + regularLiter;
    if (total <= 0 ||
        (premiumLiter > 0 && premiumRon <= 0) ||
        (regularLiter > 0 && regularRon <= 0)) {
      return 0;
    }
    return ((premiumLiter * premiumRon) + (regularLiter * regularRon)) / total;
  }

  double _calcAverageOctane() => _weightedOctane(
    premiumLiter: _parseDouble(highFuelCtrl),
    premiumRon: _parseDouble(highOctaneCtrl),
    regularLiter: _parseDouble(regFuelCtrl),
    regularRon: _parseDouble(regularOctaneCtrl),
  );

  double _tankRefuelLiter() {
    if (!_isTankMixedRefuel) return _parseDouble(addLiterCtrl);
    return _parseDouble(highFuelCtrl) + _parseDouble(regFuelCtrl);
  }

  double _tankRefuelRon() {
    if (!_isTankMixedRefuel) return _parseDouble(addOctaneCtrl);
    return _weightedOctane(
      premiumLiter: _parseDouble(highFuelCtrl),
      premiumRon: _parseDouble(highOctaneCtrl),
      regularLiter: _parseDouble(regFuelCtrl),
      regularRon: _parseDouble(regularOctaneCtrl),
    );
  }

  String? _validateTankInputs() {
    final beforeL = _parseDouble(beforeLiterCtrl);
    final beforeO = _parseDouble(beforeOctaneCtrl);
    if (beforeL <= 0 || beforeO <= 0) {
      return '현재 탱크의 연료량과 옥탄가는 모두 0보다 크게 입력해 주세요.';
    }

    if (!_isTankMixedRefuel) {
      if (_parseDouble(addLiterCtrl) <= 0 || _parseDouble(addOctaneCtrl) <= 0) {
        return '이번 주유의 주유량과 옥탄가는 모두 0보다 크게 입력해 주세요.';
      }
      return null;
    }

    final premiumLiter = _parseDouble(highFuelCtrl);
    final regularLiter = _parseDouble(regFuelCtrl);
    if (premiumLiter + regularLiter <= 0) {
      return '고급유와 일반유 중 한 종류 이상에 주유량을 입력해 주세요.';
    }
    if (premiumLiter > 0 && _parseDouble(highOctaneCtrl) <= 0) {
      return '고급유 주유량을 입력했다면 고급유 옥탄가도 입력해 주세요.';
    }
    if (regularLiter > 0 && _parseDouble(regularOctaneCtrl) <= 0) {
      return '일반유 주유량을 입력했다면 일반유 옥탄가도 입력해 주세요.';
    }
    return null;
  }

  double _calcMixedOctane() {
    if (_validateTankInputs() != null) return 0;
    final beforeL = _parseDouble(beforeLiterCtrl);
    final beforeO = _parseDouble(beforeOctaneCtrl);
    final addL = _tankRefuelLiter();
    final addO = _tankRefuelRon();
    final total = beforeL + addL;
    if (total <= 0) return 0;
    return ((beforeL * beforeO) + (addL * addO)) / total;
  }

  double _mixedTotalLiter() {
    return _parseDouble(beforeLiterCtrl) + _tankRefuelLiter();
  }

  TargetOctaneCalculation _calculateTarget() =>
      TargetOctaneCalculator.calculate(
        target: double.tryParse(targetOctaneCtrl.text.trim()),
        currentLiter: double.tryParse(targetCurrentLiterCtrl.text.trim()),
        currentOctane: double.tryParse(targetCurrentOctaneCtrl.text.trim()),
        fuelOctane: double.tryParse(targetFuelOctaneCtrl.text.trim()),
      );

  CarProfile? _mainCar() {
    return Hive.box<CarProfile>('car_profile').get('main');
  }

  Future<bool> _saveLog({
    required String type,
    required double result,
    required Map<String, dynamic> inputs,
    required String memo,
    required String? stationName,
    required double? odometer,
    required bool isFullTank,
  }) async {
    if (!await _confirmOdometerIfLower(odometer)) return false;
    final box = Hive.box<OctaneLog>('octane_logs');
    await box.add(
      OctaneLog(
        time: DateTime.now(),
        type: type,
        result: result,
        inputs: inputs,
        memo: memo,
        stationName: stationName,
        odometer: odometer,
        isFullTank: isFullTank,
      ),
    );
    AnalyticsService.log('save_record', parameters: {'type': type});
    AnalyticsService.log(
      'record_saved',
      parameters: {
        'calculation_type': _analyticsCalculationType(type),
        'has_cost': _hasCostData(inputs).toString(),
        'has_memo': memo.trim().isNotEmpty.toString(),
        'has_station': (stationName?.trim().isNotEmpty ?? false).toString(),
        'has_odometer': (odometer != null).toString(),
        'is_full_tank': isFullTank.toString(),
      },
    );
    return true;
  }

  Future<bool> _confirmOdometerIfLower(double? current) async {
    if (current == null || current < 0) return true;

    final previous =
        Hive.box<OctaneLog>(
            'octane_logs',
          ).values.where((log) => log.odometer != null).toList()
          ..sort((a, b) => b.time.compareTo(a.time));
    if (previous.isEmpty || current >= previous.first.odometer!) return true;
    if (!mounted) return false;

    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('주행거리 확인'),
                content: Text(
                  '최근 기록은 ${DisplayFormat.groupedInteger(previous.first.odometer!)} km인데 현재 입력은 ${DisplayFormat.groupedInteger(current)} km입니다.\n\n계기판 값을 다시 확인한 뒤에도 저장할까요?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('다시 확인'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('그래도 저장'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  String _analyticsCalculationType(String type) {
    return switch (type) {
      'average' => 'simple',
      'mixed' => 'tank',
      'target' => 'target',
      _ => type,
    };
  }

  bool _hasCostData(Map<String, dynamic> inputs) {
    const costKeys = {
      'unitPrice',
      'totalCost',
      'highUnitPrice',
      'highTotalCost',
      'regularUnitPrice',
      'regularTotalCost',
    };
    return costKeys.any((key) {
      final value = DisplayFormat.asDouble(inputs[key]);
      return value != null && value > 0;
    });
  }

  void _logCalculationCompleted(String calculationType) {
    AnalyticsService.log(
      'calculate_completed',
      parameters: {
        'calculation_type': calculationType,
        'has_vehicle': (_mainCar() != null).toString(),
        // Costs are now collected after calculation in the save sheet.
        'has_cost_input': 'false',
      },
    );
  }

  _Status _status(double v) {
    final car = _mainCar();
    if (car == null) {
      return const _Status(
        '차량 기준 미설정',
        '차량 정보를 저장하면 권장/경고 기준으로 결과를 판단합니다.',
        Icons.tune_rounded,
        Colors.blueGrey,
      );
    }

    final recommend = car.recommendedOctane;
    final warning = car.warningOctane;

    if (v >= recommend) {
      return const _Status(
        '권장 기준 충족',
        '차량 기준에서 권장 옥탄가를 충족했습니다.',
        Icons.verified_rounded,
        Colors.green,
      );
    } else if (v >= warning) {
      return const _Status(
        '보통',
        '일상 주행은 가능하지만 권장 옥탄가까지 여유가 크진 않습니다.',
        Icons.info_outline_rounded,
        Colors.orange,
      );
    } else {
      return const _Status(
        '주의',
        '고부하 주행은 피하고 다음 주유에서 옥탄가를 보강하는 편이 좋습니다.',
        Icons.warning_amber_rounded,
        Colors.red,
      );
    }
  }

  _TankInsight? _tankInsight() {
    final manualTank = _parseDouble(mixTankCtrl);
    final tankCapacity = manualTank > 0 ? manualTank : _mainCar()?.tankCapacity;
    if (tankCapacity == null || tankCapacity <= 0) {
      return null;
    }

    final total = _mixedTotalLiter();
    if (total <= 0) {
      return null;
    }

    final remaining = tankCapacity - total;
    if (remaining < 0) {
      return _TankInsight(
        title: '탱크 용량 초과',
        message:
            '총 ${total.toStringAsFixed(1)}L로 탱크 용량을 ${remaining.abs().toStringAsFixed(1)}L 초과합니다.',
      );
    }
    return null;
  }

  Future<void> _saveAverageLog() async {
    final value = _avgResult;
    if (value == null || value <= 0) return;

    await _showRecordSaveSheet(
      type: 'average',
      result: value,
      inputs: {
        'highLiter': highFuelCtrl.text.trim(),
        'regularLiter': regFuelCtrl.text.trim(),
        'highOctane': highOctaneCtrl.text.trim(),
        'regularOctane': regularOctaneCtrl.text.trim(),
      },
      fuelLiter: _parseDouble(highFuelCtrl) + _parseDouble(regFuelCtrl),
    );
  }

  Future<void> _saveMixedLog() async {
    final value = _mixResult;
    if (value == null || value <= 0) return;

    await _showRecordSaveSheet(
      type: 'mixed',
      result: value,
      inputs: {
        'beforeLiter': beforeLiterCtrl.text.trim(),
        'beforeOctane': beforeOctaneCtrl.text.trim(),
        if (_isTankMixedRefuel) ...{
          // Keep the established simple-mix keys so records, backups and
          // existing fuel-liter displays continue to work without migration.
          'highLiter': highFuelCtrl.text.trim(),
          'regularLiter': regFuelCtrl.text.trim(),
          'highOctane': highOctaneCtrl.text.trim(),
          'regularOctane': regularOctaneCtrl.text.trim(),
          'mixedFuelRon': _tankRefuelRon().toStringAsFixed(2),
        } else ...{
          'addLiter': addLiterCtrl.text.trim(),
          'addOctane': addOctaneCtrl.text.trim(),
        },
        if (mixTankCtrl.text.trim().isNotEmpty)
          'tankCapacity': mixTankCtrl.text.trim()
        else if (_mainCar()?.tankCapacity != null)
          'tankCapacity': _mainCar()!.tankCapacity!.toStringAsFixed(1),
      },
      fuelLiter: _tankRefuelLiter(),
    );
  }

  Future<void> _saveTargetLog() async {
    final value = _targetResultOctane;
    final requiredLiter = _targetRequiredLiter;
    if (value == null ||
        value <= 0 ||
        requiredLiter == null ||
        _targetImpossible) {
      return;
    }

    await _showRecordSaveSheet(
      type: 'target',
      result: value,
      inputs: {
        'targetOctane': targetOctaneCtrl.text.trim(),
        'currentLiter': targetCurrentLiterCtrl.text.trim(),
        'currentOctane': targetCurrentOctaneCtrl.text.trim(),
        'fuelOctane': targetFuelOctaneCtrl.text.trim(),
        'requiredLiter': requiredLiter.toStringAsFixed(1),
        if (_targetTotalLiter != null)
          'expectedTotalLiter': _targetTotalLiter!.toStringAsFixed(1),
        'expectedFinalOctane': value.toStringAsFixed(2),
      },
      fuelLiter: requiredLiter,
    );
  }

  Future<void> _showRecordSaveSheet({
    required String type,
    required double result,
    required Map<String, dynamic> inputs,
    required double fuelLiter,
  }) async {
    final stationController = TextEditingController();
    final odometerController = TextEditingController();
    final totalCostController = TextEditingController();
    final fuelLiterController = TextEditingController(
      text: fuelLiter > 0 ? fuelLiter.toStringAsFixed(1) : '',
    );
    final unitPriceController = TextEditingController();
    final memoController = TextEditingController();
    var isFullTank = false;
    var showCostDetails = false;
    var showMemo = false;
    var changingCost = false;

    void updateUnitPrice() {
      if (changingCost) return;
      final total = DisplayFormat.asDouble(totalCostController.text);
      final liter = DisplayFormat.asDouble(fuelLiterController.text);
      if (total == null || liter == null || total <= 0 || liter <= 0) return;
      changingCost = true;
      unitPriceController.text = (total / liter).toStringAsFixed(0);
      changingCost = false;
    }

    void updateTotalCost() {
      if (changingCost) return;
      final liter = DisplayFormat.asDouble(fuelLiterController.text);
      final unit = DisplayFormat.asDouble(unitPriceController.text);
      if (liter == null || unit == null || liter <= 0 || unit <= 0) return;
      changingCost = true;
      totalCostController.text = (liter * unit).toStringAsFixed(0);
      changingCost = false;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFFFF),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final stations = _recentStationNames();
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * .74,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      const Text(
                        '주유 기록 저장',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        '계산 결과와 함께 추가 주유 정보를 저장합니다.',
                        style: TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sheetSectionTitle(
                        '기본 주유 정보',
                        Icons.local_gas_station_rounded,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: stationController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '주유소 (선택)',
                          hintText: '예: SK 판교주유소',
                          prefixIcon: Icon(Icons.local_gas_station_outlined),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                      if (stations.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        const Text(
                          '최근 주유소',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children:
                              stations
                                  .map(
                                    (name) => ActionChip(
                                      label: Text(name),
                                      onPressed:
                                          () => setSheetState(
                                            () => stationController.text = name,
                                          ),
                                      backgroundColor: const Color(0xFFF8FAFC),
                                      labelStyle: const TextStyle(
                                        color: Color(0xFF334155),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: odometerController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: '현재 주행거리 (선택)',
                          hintText: '예: 172420',
                          suffixText: 'km',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                      SwitchTheme(
                        data: SwitchThemeData(
                          thumbColor: WidgetStateProperty.resolveWith(
                            (states) =>
                                states.contains(WidgetState.selected)
                                    ? const Color(0xFFD32F2F)
                                    : const Color(0xFF9AAABD),
                          ),
                          trackColor: WidgetStateProperty.resolveWith(
                            (states) =>
                                states.contains(WidgetState.selected)
                                    ? const Color(0xFFD32F2F)
                                    : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: isFullTank,
                          onChanged:
                              (value) =>
                                  setSheetState(() => isFullTank = value),
                          title: const Text(
                            '가득 주유',
                            style: TextStyle(
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          subtitle: const Text(
                            '추후 실연비 계산에 활용됩니다.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ExpansionTile(
                            onExpansionChanged:
                                (value) => setSheetState(
                                  () => showCostDetails = value,
                                ),
                            leading: const Icon(
                              Icons.receipt_long_outlined,
                              color: Color(0xFFD32F2F),
                            ),
                            title: const Text(
                              '추가 금액 정보 (선택)',
                              style: TextStyle(
                                color: Color(0xFF334155),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              showCostDetails
                                  ? '총액과 주유량으로 단가를 자동 계산합니다.'
                                  : '필요할 때만 입력해 주세요.',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              12,
                              0,
                              12,
                              12,
                            ),
                            children: [
                              _sheetNumberField(
                                totalCostController,
                                '총 주유 금액',
                                unit: '원',
                                onChanged: (_) {
                                  updateUnitPrice();
                                  setSheetState(() {});
                                },
                              ),
                              const SizedBox(height: 10),
                              _sheetNumberField(
                                fuelLiterController,
                                '주유량',
                                unit: 'L',
                                onChanged: (_) {
                                  updateUnitPrice();
                                  setSheetState(() {});
                                },
                              ),
                              const SizedBox(height: 10),
                              _sheetNumberField(
                                unitPriceController,
                                '리터당 단가',
                                unit: '원/L',
                                onChanged: (_) {
                                  updateTotalCost();
                                  setSheetState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 4),
                          onExpansionChanged:
                              (value) => setSheetState(() => showMemo = value),
                          title: const Text(
                            '메모 (선택)',
                            style: TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          subtitle: Text(
                            showMemo ? '간단한 내용을 남길 수 있어요.' : '필요할 때만 입력해 주세요.',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                          children: [
                            TextField(
                              controller: memoController,
                              minLines: 1,
                              maxLines: 2,
                              textInputAction: TextInputAction.newline,
                              decoration: const InputDecoration(
                                hintText: '메모를 입력하세요.',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                              ),
                              onPressed:
                                  () => Navigator.of(sheetContext).pop(false),
                              child: const Text('취소'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                              ),
                              onPressed: () async {
                                final recordInputs = Map<String, dynamic>.from(
                                  inputs,
                                );
                                final totalCost = DisplayFormat.asDouble(
                                  totalCostController.text,
                                );
                                final unitPrice = DisplayFormat.asDouble(
                                  unitPriceController.text,
                                );
                                if (totalCost != null && totalCost > 0) {
                                  recordInputs['totalCost'] = totalCost
                                      .toStringAsFixed(0);
                                }
                                if (unitPrice != null && unitPrice > 0) {
                                  recordInputs['unitPrice'] = unitPrice
                                      .toStringAsFixed(0);
                                }
                                final saved = await _saveLog(
                                  type: type,
                                  result: result,
                                  inputs: recordInputs,
                                  memo: memoController.text.trim(),
                                  stationName:
                                      stationController.text.trim().isEmpty
                                          ? null
                                          : stationController.text.trim(),
                                  odometer: double.tryParse(
                                    odometerController.text.trim(),
                                  ),
                                  isFullTank: isFullTank,
                                );
                                if (saved && context.mounted) {
                                  Navigator.pop(context, true);
                                }
                              },
                              child: const Text('저장하기'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // The route's pop future completes before its exit animation has fully
    // detached TextFields. Disposing synchronously can briefly surface a
    // debug error when the user cancels the sheet.
    await Future<void>.delayed(kThemeAnimationDuration);
    stationController.dispose();
    odometerController.dispose();
    totalCostController.dispose();
    fuelLiterController.dispose();
    unitPriceController.dispose();
    memoController.dispose();

    if (saved != true || !mounted) return;
    setState(() {
      if (type == 'average') {
        _avgResult = null;
      } else if (type == 'mixed') {
        _mixResult = null;
        _tankInputMessage = null;
      } else {
        _targetRequiredLiter = null;
        _targetResultOctane = null;
        _targetTotalLiter = null;
        _targetComment = null;
        _targetImpossible = false;
      }
    });
    _showSavedSnackBar();
  }

  Widget _sheetSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFD32F2F), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _sheetNumberField(
    TextEditingController controller,
    String label, {
    required String unit,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  void _showSavedSnackBar() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('✅ 기록이 저장되었습니다.')));
    _scheduleReviewPromptCheck();
  }

  void _scheduleReviewPromptCheck() {
    Future<void>.delayed(const Duration(milliseconds: 700), () async {
      if (mounted) await _maybeShowReviewPrompt();
    });
  }

  Future<void> _maybeShowReviewPrompt() async {
    if (_reviewPromptInProgress) return;

    final recordCount = Hive.box<OctaneLog>('octane_logs').length;
    final eligible = await ReviewPromptService.isEligible(
      recordCount: recordCount,
    );
    if (!eligible || !mounted) return;

    _reviewPromptInProgress = true;
    await ReviewPromptService.markShown(recordCount: recordCount);
    if (!mounted) {
      _reviewPromptInProgress = false;
      return;
    }
    AnalyticsService.log('review_prompt_shown');

    final action = await showDialog<_ReviewPromptAction>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('고급유 노트가 주유 관리에 도움이 되었나요?'),
            content: const Text('짧은 평가가 앱을 개선하는 데 큰 도움이 됩니다.'),
            actions: [
              TextButton(
                onPressed:
                    () =>
                        Navigator.pop(dialogContext, _ReviewPromptAction.later),
                child: const Text('나중에'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.pop(
                      dialogContext,
                      _ReviewPromptAction.accepted,
                    ),
                child: const Text('평가 남기기'),
              ),
            ],
          ),
    );

    if (action == _ReviewPromptAction.accepted) {
      AnalyticsService.log('review_prompt_accepted');
      await ReviewPromptService.markAccepted();
      try {
        await ReviewPromptService.requestReview();
      } catch (_) {}
    } else if (action == _ReviewPromptAction.later) {
      AnalyticsService.log('review_prompt_later');
    }

    _reviewPromptInProgress = false;
  }

  void _onCalcAverage() {
    final value = _calcAverageOctane();
    setState(() {
      _avgResult = value;
    });
    AnalyticsService.log('calculate_simple');
    if (value > 0) {
      _logCalculationCompleted('simple');
    }
  }

  void _onCalcMixed() {
    final validationMessage = _validateTankInputs();
    final value = _calcMixedOctane();
    setState(() {
      _mixResult = validationMessage == null ? value : null;
      _tankInputMessage = validationMessage;
    });
    AnalyticsService.log('calculate_tank');
    if (value > 0) {
      _logCalculationCompleted('tank');
    }
  }

  void _onCalcTarget() {
    final calculation = _calculateTarget();
    setState(() {
      _targetRequiredLiter = calculation.requiredLiter;
      _targetTotalLiter = calculation.totalLiter;
      _targetResultOctane = calculation.finalOctane;
      _targetImpossible = !calculation.isPossible;
      _targetComment = calculation.message;
    });
    AnalyticsService.log('calculate_target');
    if (calculation.isPossible && _targetResultOctane != null) {
      _logCalculationCompleted('target');
    }
  }

  Future<void> _saveCarProfile({
    required String name,
    required int year,
    required double recommend,
    required double warning,
    double? tank,
    Uint8List? photoBytes,
  }) async {
    final box = Hive.box<CarProfile>('car_profile');
    final isFirstVehicle = !box.containsKey('main');

    await box.put(
      'main',
      CarProfile(
        name: name,
        year: year,
        recommendedOctane: recommend,
        warningOctane: warning,
        photoBytes: photoBytes,
        tankCapacity: tank, // ?뵦 異붽?
      ),
    );
    AnalyticsService.log(
      'vehicle_saved',
      parameters: {
        'is_first_vehicle': isFirstVehicle.toString(),
        'has_photo': (photoBytes != null && photoBytes.isNotEmpty).toString(),
        'has_tank_capacity': (tank != null).toString(),
      },
    );
  }

  Future<Uint8List?> _pickCarPhoto() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (image == null) return null;
      final bytes = await image.readAsBytes();
      if (!mounted) return null;
      setState(() => _selectedCarPhoto = bytes);
      return bytes;
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러오지 못했습니다. 다시 선택해 주세요.')),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHome = _currentMainTab == 0;
    final isCalculator = _currentMainTab == 2;
    const dashboardBackground = Color(0xFFF7FAFC);

    return PopScope(
      canPop: !isCalculator,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isCalculator) _goToMainTab(0);
      },
      child: Scaffold(
        backgroundColor: dashboardBackground,
        appBar: AppBar(
          toolbarHeight: isHome ? 62 : 52,
          backgroundColor: dashboardBackground,
          foregroundColor: Color(0xFF0F172A),
          titleSpacing: 16,
          titleTextStyle: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
          iconTheme: const IconThemeData(color: Color(0xFFD32F2F)),
          leading:
              isCalculator
                  ? IconButton(
                    tooltip: '뒤로',
                    onPressed: () => _goToMainTab(0),
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                  : null,
          title:
              isHome
                  ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '고급유 노트',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '내 차의 주유 기록을 한눈에',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                  : Text(isCalculator ? '옥탄가 계산' : '고급유 노트'),
        ),
        bottomNavigationBar:
            isCalculator
                ? null
                : SafeArea(
                  top: false,
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      labelTextStyle: WidgetStateProperty.resolveWith((states) {
                        final selected = states.contains(WidgetState.selected);
                        return TextStyle(
                          color:
                              selected
                                  ? const Color(0xFFD32F2F)
                                  : const Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        );
                      }),
                      iconTheme: WidgetStateProperty.resolveWith((states) {
                        final selected = states.contains(WidgetState.selected);
                        return IconThemeData(
                          color:
                              selected
                                  ? const Color(0xFFD32F2F)
                                  : const Color(0xFF64748B),
                        );
                      }),
                    ),
                    child: NavigationBar(
                      selectedIndex: switch (_currentMainTab) {
                        0 => 0,
                        1 => 1,
                        3 => 2,
                        4 => 3,
                        5 => 4,
                        _ => 0,
                      },
                      height: 64,
                      backgroundColor: dashboardBackground,
                      indicatorColor: const Color(0xFFFDECEC),
                      surfaceTintColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      onDestinationSelected: (index) {
                        const tabIndexes = [0, 1, 3, 4, 5];
                        _goToMainTab(tabIndexes[index]);
                      },
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home_rounded),
                          label: '홈',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.assignment_outlined),
                          selectedIcon: Icon(Icons.assignment_rounded),
                          label: '기록',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.bar_chart_outlined),
                          selectedIcon: Icon(Icons.bar_chart_rounded),
                          label: '통계',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.directions_car_outlined),
                          selectedIcon: Icon(Icons.directions_car_rounded),
                          label: '차량',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.more_horiz_outlined),
                          selectedIcon: Icon(Icons.more_horiz_rounded),
                          label: '더보기',
                        ),
                      ],
                    ),
                  ),
                ),
        body: SafeArea(
          child: ColoredBox(
            color: dashboardBackground,
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildHomeTab(),
                _buildRecordTab(),
                _buildCalculatorTab(),
                _buildHistoryTab(),
                _buildVehicleDashboardTab(),
                _buildMoreTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  EdgeInsets _listPadding(BuildContext context) => EdgeInsets.fromLTRB(
    16,
    16,
    16,
    MediaQuery.of(context).padding.bottom + 96,
  );

  int _calcMode = 0;

  bool get _isAverageMode => _calcMode == 0;
  bool get _isMixedMode => _calcMode == 1;
  bool get _isTargetMode => _calcMode == 2;

  bool get _hasPendingResult {
    return (_isAverageMode && _avgResult != null) ||
        (_isMixedMode && _mixResult != null) ||
        (_isTargetMode &&
            (_targetRequiredLiter != null || _targetComment != null));
  }

  Widget _buildHomeTab() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<CarProfile>('car_profile').listenable(),
      builder: (context, Box<CarProfile> carBox, _) {
        return ValueListenableBuilder(
          valueListenable: Hive.box<OctaneLog>('octane_logs').listenable(),
          builder: (context, Box<OctaneLog> logBox, _) {
            final car = carBox.get('main');
            final logs = logBox.values.toList();
            final latest = logs.isEmpty ? null : logs.last;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                12,
                16,
                12,
                MediaQuery.of(context).padding.bottom + 18,
              ),
              children: [
                if (car == null) ...[
                  _firstRunHomeCard(),
                  if (latest != null) ...[
                    const SizedBox(height: 14),
                    _dashboardRecentFuelCard(latest),
                    const SizedBox(height: 14),
                    _dashboardSevenDayCard(logs),
                  ],
                ] else ...[
                  _homeSummaryCard(car, latest),
                  const SizedBox(height: 14),
                  _dashboardRecentFuelCard(latest),
                  const SizedBox(height: 14),
                  _dashboardSevenDayCard(logs),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _firstRunHomeCard() {
    return _darkDashboardCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  '내 차량을 등록해 주세요',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                Icons.directions_car_rounded,
                color: Color(0xFFD32F2F),
                size: 38,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '차량 정보를 설정하면\n내 차량 권장 기준에 맞춰 옥탄가 상태를 확인할 수 있어요.',
            style: TextStyle(
              color: Color(0xFF334155),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          _darkActionButton(
            '차량 설정하기',
            Icons.directions_car_outlined,
            () => _goToMainTab(4),
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: () => _goToMainTab(2),
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('계산 먼저 하기'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeSummaryCard(CarProfile? car, OctaneLog? latest) {
    final meetsRecommended =
        car != null && latest != null && latest.result >= car.recommendedOctane;
    final statusText =
        latest == null
            ? '저장된 주유 기록이 없습니다.'
            : car == null
            ? '차량 기준을 설정하면 결과를 비교할 수 있어요.'
            : meetsRecommended
            ? '권장 기준을 충족했습니다.'
            : latest.result >= car.warningOctane
            ? '권장 기준보다 낮습니다.'
            : '주의 기준보다 낮습니다.';
    final statusColor =
        latest == null || car == null
            ? const Color(0xFF334155)
            : meetsRecommended
            ? const Color(0xFFD32F2F)
            : const Color(0xFFFFB45E);

    return _darkDashboardCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (car?.photoBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                car!.photoBytes!,
                width: double.infinity,
                height: 158,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  car == null ? '차량을 설정해 주세요' : '${car.year} ${car.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (car?.photoBytes == null)
                const Icon(
                  Icons.directions_car_rounded,
                  color: Color(0xFF64748B),
                  size: 34,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '최근 옥탄가',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            latest == null ? '--' : _formatRon(latest.result),
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 31,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            car == null
                ? '권장 기준 미설정'
                : '권장 기준 ${car.recommendedOctane.toStringAsFixed(1)} RON 이상',
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          _darkActionButton(
            latest == null ? '첫 옥탄가 계산하기' : '옥탄가 계산하기',
            Icons.calculate_rounded,
            () => _goToMainTab(2),
          ),
        ],
      ),
    );
  }

  Widget _dashboardRecentFuelCard(OctaneLog? latest) {
    final liter = latest == null ? null : _logFuelLiter(latest);
    final cost = latest == null ? null : _logCost(latest);
    final unitPrice = latest == null ? null : _logUnitPriceText(latest);

    return _darkDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최근 주유',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          if (latest == null)
            const Text(
              '저장된 주유 기록이 없습니다.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            )
          else ...[
            _homeFuelRow('날짜', _recordDateTime(latest.time)),
            _homeFuelRow('계산 방식', _typeTitle(latest.type)),
            _homeFuelRow('최종 옥탄가', _formatRon(latest.result)),
            _homeFuelRow(
              '총 주유량',
              liter == null ? '입력 안 됨' : _formatLiter(liter),
            ),
            if (unitPrice != null) _homeFuelRow('단가', unitPrice),
            _homeFuelRow(
              '총 주유 금액',
              cost == null || cost <= 0 ? '입력 안 됨' : _formatWon(cost),
            ),
          ],
        ],
      ),
    );
  }

  Widget _homeFuelRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardSevenDayCard(List<OctaneLog> logs) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent = logs.where((log) => log.time.isAfter(cutoff)).toList();
    final totalCost = recent.fold<double>(
      0,
      (sum, log) => sum + (_logCost(log) ?? 0),
    );
    final totalLiter = recent.fold<double>(
      0,
      (sum, log) => sum + (_logFuelLiter(log) ?? 0),
    );

    return _darkDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '7일 리포트 요약',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          if (recent.isEmpty) ...[
            const Text(
              '최근 7일간 저장된 주유 기록이 없습니다.',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '기록을 저장하면 주유량과 지출 요약을 확인할 수 있어요.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: _dashboardReportItem('주유', '${recent.length}회'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dashboardReportItem(
                    '주유량',
                    totalLiter <= 0 ? '입력 안 됨' : _formatLiter(totalLiter),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dashboardReportItem(
                    '총 금액',
                    totalCost <= 0 ? '입력 안 됨' : _formatWon(totalCost),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _dashboardReportItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _darkDashboardCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF1F5F9).withValues(alpha: 0.38),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }

  double? _logFuelLiter(OctaneLog log) {
    final inputs = log.inputs;
    final high = _asDouble(inputs['highLiter']);
    final regular = _asDouble(inputs['regularLiter']);
    if (high != null || regular != null) {
      return (high ?? 0) + (regular ?? 0);
    }

    final addLiter = _asDouble(inputs['addLiter']);
    if (addLiter != null) return addLiter;

    final requiredLiter = _asDouble(inputs['requiredLiter']);
    return requiredLiter;
  }

  double? _logCost(OctaneLog log) {
    return _asDouble(log.inputs['totalCost']);
  }

  String? _logUnitPriceText(OctaneLog log) {
    final unitPrice = _asDouble(log.inputs['unitPrice']);
    if (unitPrice != null && unitPrice > 0) {
      return '${_formatWon(unitPrice)}/L';
    }

    final high = _asDouble(log.inputs['highUnitPrice']);
    final regular = _asDouble(log.inputs['regularUnitPrice']);
    if ((high == null || high <= 0) && (regular == null || regular <= 0)) {
      return null;
    }
    return [
      if (high != null && high > 0) '고급유 ${_formatWon(high)}/L',
      if (regular != null && regular > 0) '일반유 ${_formatWon(regular)}/L',
    ].join(' · ');
  }

  double? _asDouble(Object? value) {
    return DisplayFormat.asDouble(value);
  }

  String _formatWon(double value) => DisplayFormat.won(value);

  String _formatRon(double value, {bool detail = false}) {
    return DisplayFormat.ron(value, detail: detail);
  }

  String _formatLiter(double value) => DisplayFormat.liter(value);

  void _runCurrentCalculation() {
    FocusScope.of(context).unfocus();
    if (_isAverageMode) {
      _onCalcAverage();
    } else if (_isMixedMode) {
      _onCalcMixed();
    } else {
      _onCalcTarget();
    }
  }

  Widget _inlineCalculationResult() {
    if (_isTargetMode && _targetImpossible) {
      return _targetErrorStateCard(_targetComment ?? '입력 값을 다시 확인해 주세요.');
    }

    final value =
        _isAverageMode
            ? _avgResult
            : _isMixedMode
            ? _mixResult
            : _targetResultOctane;
    if (value == null || value <= 0) {
      return _calculationStateCard(
        color: const Color(0xFF1976D2),
        icon: Icons.info_outline_rounded,
        title: '입력 값을 다시 확인해 주세요.',
        message: '모든 값은 0보다 커야 합니다. 옥탄가는 일반적으로 80~110 범위에서 입력합니다.',
      );
    }

    final save =
        _isAverageMode
            ? _saveAverageLog
            : _isMixedMode
            ? _saveMixedLog
            : _saveTargetLog;
    final resultLabel = _isTargetMode ? '필요 주유량' : '최종 예상 옥탄가';
    final resultValue =
        _isTargetMode
            ? _formatLiter(_targetRequiredLiter ?? 0)
            : _formatRon(value, detail: true);

    return Column(
      children: [
        _calculationResultCard(
          resultLabel: resultLabel,
          resultValue: resultValue,
          targetResult: _isTargetMode,
          finalOctane: value,
        ),
        const SizedBox(height: 10),
        _calculationGroupCard(
          title: '계산 조건 요약',
          icon: Icons.fact_check_outlined,
          children: _calculationSummaryRows(),
        ),
        const SizedBox(height: 10),
        _unsavedNotice(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _clearCurrentResult,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('다시 계산'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('기록 저장'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _targetErrorStateCard(String message) {
    final isLowerFuel = message.contains('현재 연료보다 높아야');
    final isInvalid = message.contains('0보다 큰 숫자');
    final color =
        isInvalid
            ? const Color(0xFF1976D2)
            : isLowerFuel
            ? const Color(0xFFFFB547)
            : const Color(0xFFFF5B64);
    final title =
        isInvalid
            ? '입력 값을 다시 확인해 주세요.'
            : isLowerFuel
            ? '현재 연료보다 낮거나 같은 옥탄가입니다.'
            : '목표 달성이 불가능한 조건입니다.';
    final detail =
        isInvalid
            ? '모든 값은 0보다 커야 합니다. 옥탄가는 일반적으로 80~110 범위입니다.'
            : isLowerFuel
            ? '$message\n\n주입할 연료의 옥탄가가 현재 연료와 같거나 낮으면 목표 옥탄가를 높일 수 없습니다.'
            : '$message\n\n더 높은 옥탄가의 연료를 선택하거나 목표 값을 조정해 주세요.';
    return _calculationStateCard(
      color: color,
      icon:
          isInvalid ? Icons.info_outline_rounded : Icons.warning_amber_rounded,
      title: title,
      message: detail,
    );
  }

  Widget _calculationStateCard({
    required Color color,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultMetric(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _calculationSummaryRows() {
    if (_isTargetMode) {
      return [
        _targetSummaryRow('목표 옥탄가', '${targetOctaneCtrl.text.trim()} RON'),
        const SizedBox(height: 8),
        _targetSummaryRow(
          '현재 잔여 연료',
          '${targetCurrentLiterCtrl.text.trim()} L (${targetCurrentOctaneCtrl.text.trim()} RON)',
        ),
        const SizedBox(height: 8),
        _targetSummaryRow(
          '주입 연료 옥탄가',
          '${targetFuelOctaneCtrl.text.trim()} RON',
        ),
      ];
    }
    if (_isMixedMode) {
      if (_isTankMixedRefuel) {
        return [
          _targetSummaryRow(
            '현재 탱크 상태',
            '${beforeLiterCtrl.text.trim()} L · ${beforeOctaneCtrl.text.trim()} RON',
          ),
          const SizedBox(height: 8),
          _targetSummaryRow(
            '고급유',
            '${highFuelCtrl.text.trim()} L · ${highOctaneCtrl.text.trim()} RON',
          ),
          const SizedBox(height: 8),
          _targetSummaryRow(
            '일반유',
            '${regFuelCtrl.text.trim()} L · ${regularOctaneCtrl.text.trim()} RON',
          ),
          const SizedBox(height: 8),
          _targetSummaryRow(
            '이번 주유 평균',
            _formatRon(_tankRefuelRon(), detail: true),
          ),
        ];
      }
      return [
        _targetSummaryRow(
          '현재 탱크 상태',
          '${beforeLiterCtrl.text.trim()} L · ${beforeOctaneCtrl.text.trim()} RON',
        ),
        const SizedBox(height: 8),
        _targetSummaryRow(
          '이번 주유',
          '${addLiterCtrl.text.trim()} L · ${addOctaneCtrl.text.trim()} RON',
        ),
      ];
    }
    return [
      _targetSummaryRow(
        '고급유',
        '${highFuelCtrl.text.trim()} L · ${highOctaneCtrl.text.trim()} RON',
      ),
      const SizedBox(height: 8),
      _targetSummaryRow(
        '일반유',
        '${regFuelCtrl.text.trim()} L · ${regularOctaneCtrl.text.trim()} RON',
      ),
    ];
  }

  void _clearCurrentResult() {
    setState(() {
      if (_isAverageMode) {
        _avgResult = null;
      } else if (_isMixedMode) {
        _mixResult = null;
        _tankInputMessage = null;
      } else {
        _targetRequiredLiter = null;
        _targetTotalLiter = null;
        _targetResultOctane = null;
        _targetComment = null;
        _targetImpossible = false;
      }
    });
  }

  Widget _inputInfoCard() {
    return Column(
      children: [
        _modeSelector(),
        const SizedBox(height: 12),
        _modeDescriptionCard(),
        const SizedBox(height: 12),
        ..._calculationFields(),
        const SizedBox(height: 14),
        _calcButton(_calcButtonText(), onPressed: _runCurrentCalculation),
        if (_hasPendingResult) ...[
          const SizedBox(height: 16),
          _inlineCalculationResult(),
        ],
      ],
    );
  }

  String _inputHelpTitle() {
    if (_isAverageMode) return '단순 혼합 사용법';
    if (_isMixedMode) return '탱크 기준 사용법';
    return '목표 맞추기 사용법';
  }

  String _inputHelpMessage() {
    if (_isAverageMode) {
      return '고급유와 일반유를 함께 넣었을 때 평균 옥탄가를 계산합니다.\n\n예: 고급유 20L, 일반유 25L를 입력하면 두 연료가 섞인 평균값을 볼 수 있습니다.';
    }

    if (_isMixedMode) {
      return '이미 탱크에 남아 있는 연료와 이번에 넣을 연료가 섞였을 때 최종 옥탄가를 계산합니다.\n\n현재 남은 연료량, 현재 추정 옥탄가, 이번 주유량, 이번 연료 옥탄가를 입력해 주세요.';
    }

    return '원하는 목표 옥탄가에 도달하려면 새 연료를 몇 L 넣어야 하는지 계산합니다.\n\n목표 옥탄가, 현재 남은 연료량, 현재 추정 옥탄가, 넣을 연료 옥탄가를 입력해 주세요.';
  }

  void _showInputHelp() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_inputHelpTitle()),
          content: Text(_inputHelpMessage()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Widget _modeSelector() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _modeButton('단순 혼합', 0),
          _modeButton('탱크 기준', 1),
          _modeButton('목표 맞추기', 2),
        ],
      ),
    );
  }

  Widget _modeDescriptionCard() {
    final icon = switch (_calcMode) {
      0 => Icons.blender_outlined,
      1 => Icons.local_gas_station_outlined,
      _ => Icons.flag_outlined,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFD32F2F), size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _modeDescription(),
              style: TextStyle(
                color: const Color(0xFF475569),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _modeDescription() {
    if (_isAverageMode) return '고급유와 일반유를 함께 넣었을 때 평균 옥탄가를 계산합니다.';
    if (_isMixedMode) return '현재 탱크에 남은 연료 상태를 반영해 최종 옥탄가를 계산합니다.';
    return '목표 옥탄가를 맞추기 위해 필요한 주유량을 계산합니다.';
  }

  List<Widget> _calculationFields() {
    if (_isAverageMode) {
      return [
        _calculationGroupCard(
          title: '고급유',
          icon: Icons.local_gas_station_rounded,
          subtitle: '고급유 주유량과 옥탄가를 입력하세요.',
          children: [
            _calculationInputRow(
              highFuelCtrl,
              '고급유 주유량 (L)',
              unit: 'L',
              hint: '20',
            ),
            const SizedBox(height: 10),
            _calculationInputRow(
              highOctaneCtrl,
              '고급유 옥탄가 (RON)',
              unit: 'RON',
              hint: '100',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _calculationGroupCard(
          title: '일반유',
          icon: Icons.local_gas_station_outlined,
          subtitle: '일반유 주유량과 옥탄가를 입력하세요.',
          children: [
            _calculationInputRow(
              regFuelCtrl,
              '일반유 주유량 (L)',
              unit: 'L',
              hint: '10',
            ),
            const SizedBox(height: 10),
            _calculationInputRow(
              regularOctaneCtrl,
              '일반유 옥탄가 (RON)',
              unit: 'RON',
              hint: '91',
            ),
          ],
        ),
      ];
    }

    if (_isMixedMode) {
      return [
        _calculationGroupCard(
          title: '현재 탱크 상태',
          icon: Icons.propane_tank_outlined,
          subtitle: '현재 탱크에 남은 연료 정보를 입력하세요.',
          children: [
            _calculationInputRow(
              beforeLiterCtrl,
              '현재 남은 연료량 (L)',
              unit: 'L',
              hint: '15',
            ),
            const SizedBox(height: 10),
            _calculationInputRow(
              beforeOctaneCtrl,
              '현재 추정 옥탄가 (RON)',
              unit: 'RON',
              hint: '95.3',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _calculationGroupCard(
          title: '이번 주유',
          icon: Icons.local_gas_station_rounded,
          subtitle: '이번에 주입할 연료 방식을 선택하세요.',
          children: [
            _tankRefuelSelector(),
            const SizedBox(height: 10),
            if (_isTankMixedRefuel) ...[
              _compactFuelInputs(
                title: '고급유',
                literController: highFuelCtrl,
                ronController: highOctaneCtrl,
                literHint: '20',
                ronHint: '100',
              ),
              const SizedBox(height: 10),
              _compactFuelInputs(
                title: '일반유',
                literController: regFuelCtrl,
                ronController: regularOctaneCtrl,
                literHint: '10',
                ronHint: '91',
              ),
              const SizedBox(height: 10),
              _mixedRefuelAverageTile(),
            ] else ...[
              _calculationInputRow(
                addLiterCtrl,
                '이번에 넣을 주유량 (L)',
                unit: 'L',
                hint: '30',
              ),
              const SizedBox(height: 10),
              _calculationInputRow(
                addOctaneCtrl,
                '이번에 넣을 연료 옥탄가 (RON)',
                unit: 'RON',
                hint: '100',
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        _optionalTankCapacityCard(),
        if (_tankInputMessage != null) ...[
          const SizedBox(height: 10),
          _calculationStateCard(
            color: const Color(0xFF1976D2),
            icon: Icons.info_outline_rounded,
            title: '입력 값을 확인해 주세요.',
            message: _tankInputMessage!,
          ),
        ] else if (_mixResult != null && _tankInsight() != null) ...[
          const SizedBox(height: 10),
          _tankCapacityExceededNotice(_tankInsight()!),
        ],
      ];
    }

    return [
      _calculationGroupCard(
        title: '목표 옥탄가',
        icon: Icons.flag_outlined,
        subtitle: '달성하고 싶은 목표 옥탄가를 입력하세요.',
        children: [
          _calculationInputRow(
            targetOctaneCtrl,
            '목표 옥탄가 (RON)',
            unit: 'RON',
            hint: '98',
          ),
        ],
      ),
      const SizedBox(height: 10),
      _calculationGroupCard(
        title: '현재 탱크 상태',
        icon: Icons.propane_tank_outlined,
        subtitle: '현재 탱크의 연료 정보를 입력하세요.',
        children: [
          _calculationInputRow(
            targetCurrentLiterCtrl,
            '현재 남은 연료량 (L)',
            unit: 'L',
            hint: '15',
          ),
          const SizedBox(height: 10),
          _calculationInputRow(
            targetCurrentOctaneCtrl,
            '현재 연료 옥탄가 (RON)',
            unit: 'RON',
            hint: '95.3',
          ),
        ],
      ),
      const SizedBox(height: 10),
      _calculationGroupCard(
        title: '주입할 연료',
        icon: Icons.water_drop_rounded,
        subtitle: '주입할 연료의 옥탄가를 입력하세요.',
        children: [
          _calculationInputRow(
            targetFuelOctaneCtrl,
            '주입할 연료 옥탄가 (RON)',
            unit: 'RON',
            hint: '100',
          ),
        ],
      ),
    ];
  }

  Widget _calculationGroupCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required List<Widget> children,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFD32F2F), size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _calculationInputRow(
    TextEditingController controller,
    String label, {
    required String unit,
    required String hint,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD7E2EC),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 5,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
            decoration: InputDecoration(
              hintText: hint,
              suffixText: unit,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _calculationResultCard({
    required String resultLabel,
    required String resultValue,
    required bool targetResult,
    required double finalOctane,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFFD32F2F),
                  size: 19,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '계산 결과',
                    style: TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(
                  Icons.check_rounded,
                  color: Color(0xFFD32F2F),
                  size: 17,
                ),
                const SizedBox(width: 3),
                const Text(
                  '계산 완료',
                  style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              resultLabel,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                resultValue,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (targetResult) ...[
              const Divider(color: Color(0xFFE2E8F0), height: 24),
              _resultMetric('주유 후 총 연료량', _formatLiter(_targetTotalLiter ?? 0)),
              const SizedBox(height: 9),
              _resultMetric('최종 예상 옥탄가', _formatRon(finalOctane, detail: true)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tankRefuelSelector() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _tankRefuelModeButton('단일 연료', false),
          _tankRefuelModeButton('혼합 주유', true),
        ],
      ),
    );
  }

  Widget _tankRefuelModeButton(String label, bool mixed) {
    final selected = _isTankMixedRefuel == mixed;
    return Expanded(
      child: GestureDetector(
        onTap:
            () => setState(() {
              _isTankMixedRefuel = mixed;
              _mixResult = null;
              _tankInputMessage = null;
            }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFB71C1C) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Color(0xFF0F172A) : const Color(0xFF334155),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactFuelInputs({
    required String title,
    required TextEditingController literController,
    required TextEditingController ronController,
    required String literHint,
    required String ronHint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFD7E2EC),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _compactNumberInput(
                controller: literController,
                label: '주유량',
                hint: literHint,
                unit: 'L',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _compactNumberInput(
                controller: ronController,
                label: '옥탄가',
                hint: ronHint,
                unit: 'RON',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _compactNumberInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String unit,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged:
          (_) => setState(() {
            _mixResult = null;
            _tankInputMessage = null;
          }),
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: unit,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 11,
        ),
      ),
    );
  }

  Widget _mixedRefuelAverageTile() {
    final total = _tankRefuelLiter();
    final ron = _tankRefuelRon();
    final value =
        total > 0 && ron > 0 ? _formatRon(ron, detail: true) : '-- RON';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF3B3B3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.functions_rounded,
            color: Color(0xFFD32F2F),
            size: 19,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '이번 주유 평균',
              style: TextStyle(
                color: Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionalTankCapacityCard() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap:
                () => setState(
                  () => _isTankCapacityExpanded = !_isTankCapacityExpanded,
                ),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  const Icon(
                    Icons.water_drop_outlined,
                    color: Color(0xFFD32F2F),
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '탱크 용량 (선택)',
                      style: TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(
                    _isTankCapacityExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF334155),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState:
                _isTankCapacityExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 9),
                      child: Text(
                        '입력하면 탱크 용량 초과 여부를 함께 확인합니다.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  _calculationInputRow(
                    mixTankCtrl,
                    '탱크 용량 (선택)',
                    unit: 'L',
                    hint: '50',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tankCapacityExceededNotice(_TankInsight insight) {
    return _calculationStateCard(
      color: const Color(0xFFFFB547),
      icon: Icons.warning_amber_rounded,
      title: insight.title,
      message: insight.message,
    );
  }

  String _calcButtonText() {
    if (_isAverageMode) return '평균 옥탄가 계산';
    if (_isMixedMode) return '최종 옥탄가 계산';
    return '필요 주유량 계산';
  }

  Widget _modeButton(String text, int mode) {
    final selected = _calcMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (mode == 1) {
            _prefillTankOctaneFromLatestRecord();
          }
          setState(() {
            _calcMode = mode;
            _tankInputMessage = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFB71C1C) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: selected ? Color(0xFF0F172A) : const Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<String> _recentStationNames() {
    final names = <String>[];
    final seen = <String>{};
    final logs =
        Hive.box<OctaneLog>('octane_logs').values.toList()
          ..sort((a, b) => b.time.compareTo(a.time));
    for (final log in logs) {
      final name = log.stationName?.trim();
      if (name == null || name.isEmpty || !seen.add(name.toLowerCase())) {
        continue;
      }
      names.add(name);
      if (names.length == 5) break;
    }
    return names;
  }

  Widget _unsavedNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF1976D2),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '계산 결과는 아직 저장되지 않았습니다.\n기록 저장 시 통계와 그래프에 반영됩니다.',
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _targetSummaryRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(_Status st) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: st.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: st.color.withValues(alpha: 0.34), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(st.icon, size: 16, color: st.color),
          const SizedBox(width: 7),
          Text(
            st.label,
            style: TextStyle(
              color: st.color,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(List<OctaneLog> logs) {
    final values = logs.map((e) => e.result).toList();

    final avg = values.reduce((a, b) => a + b) / values.length;
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '통계',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 22),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: _statItem('평균', avg, Color(0xFF0F172A))),
                  const VerticalDivider(color: Color(0xFFE2E8F0), width: 1),
                  Expanded(
                    child: _statItem('최고', max, const Color(0xFFD32F2F)),
                  ),
                  const VerticalDivider(color: Color(0xFFE2E8F0), width: 1),
                  Expanded(
                    child: _statItem('최저', min, const Color(0xFF2C83C8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '총 기록 ${logs.length}개',
              style: TextStyle(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String title, double value, Color valueColor) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value.toStringAsFixed(1),
          style: TextStyle(
            color: valueColor,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordTab() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<OctaneLog>('octane_logs').listenable(),
      builder: (context, Box<OctaneLog> box, _) {
        final query = recordSearchCtrl.text.trim().toLowerCase();
        final logs =
            box.values.where((log) {
                final matchesFilter =
                    _recordFilter == 0 ||
                    (_recordFilter == 1 && log.type == 'average') ||
                    (_recordFilter == 2 && log.type == 'mixed') ||
                    (_recordFilter == 3 && log.type == 'target');
                if (!matchesFilter) return false;
                if (query.isEmpty) return true;
                return _typeTitle(log.type).toLowerCase().contains(query) ||
                    log.memo.toLowerCase().contains(query) ||
                    (log.stationName?.toLowerCase().contains(query) ?? false) ||
                    _dateOnly(log.time).contains(query) ||
                    log.result.toStringAsFixed(1).contains(query);
              }).toList()
              ..sort((a, b) => b.time.compareTo(a.time));

        final groupedRows = <Widget>[];
        String? currentMonth;
        for (final log in logs) {
          final month = '${log.time.year}년 ${log.time.month}월';
          if (month != currentMonth) {
            if (groupedRows.isNotEmpty) {
              groupedRows.add(const SizedBox(height: 8));
            }
            groupedRows.add(_recordMonthHeader(month));
            currentMonth = month;
          }
          groupedRows.add(_simplifiedRecordRow(box, log));
        }

        return Stack(
          children: [
            ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(context).padding.bottom + 110,
              ),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '주유 기록',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '기록 검색',
                      onPressed: () {
                        setState(() {
                          _recordSearchVisible = !_recordSearchVisible;
                          if (!_recordSearchVisible) recordSearchCtrl.clear();
                        });
                      },
                      icon: Icon(
                        _recordSearchVisible
                            ? Icons.close_rounded
                            : Icons.search_rounded,
                        color: const Color(0xFF334155),
                        size: 27,
                      ),
                    ),
                  ],
                ),
                if (_recordSearchVisible) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: recordSearchCtrl,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: '날짜, 방식, 주유소, 메모, 옥탄가 검색',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ],
                const SizedBox(height: 13),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _recordFilterChip('전체', 0),
                      _recordFilterChip('단순 혼합', 1),
                      _recordFilterChip('탱크 기준', 2),
                      _recordFilterChip('목표 맞추기', 3),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                if (logs.isEmpty)
                  _recordEmptyState(box.isEmpty)
                else
                  ...groupedRows,
              ],
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: FloatingActionButton.extended(
                heroTag: 'new_calculation',
                onPressed: () => _goToMainTab(2),
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Color(0xFFFFFFFF),
                icon: const Icon(Icons.add_rounded, size: 28),
                label: const Text(
                  '새 계산',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _recordFilterChip(String label, int index) {
    final selected = _recordFilter == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _recordFilter = index),
        selectedColor: const Color(0xFFD32F2F),
        backgroundColor: const Color(0xFFF1F5F9),
        side: BorderSide(
          color: selected ? const Color(0xFFD32F2F) : const Color(0xFFE2E8F0),
        ),
        labelStyle: TextStyle(
          color: selected ? const Color(0xFFF7FAFC) : const Color(0xFF334155),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _recordMonthHeader(String month) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 9),
      child: Text(
        month,
        style: const TextStyle(
          color: Color(0xFF334155),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _recordEmptyState(bool hasNoSavedLogs) {
    return _darkDashboardCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Column(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              color: Color(0xFFD32F2F),
              size: 46,
            ),
            const SizedBox(height: 14),
            Text(
              hasNoSavedLogs ? '아직 저장된 주유 기록이 없습니다.' : '검색 결과가 없습니다.',
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              hasNoSavedLogs
                  ? '계산 결과를 저장하면 여기에 기록이 표시됩니다.'
                  : '검색어나 필터를 변경해 보세요.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (hasNoSavedLogs) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => _goToMainTab(2),
                icon: const Icon(Icons.calculate_rounded),
                label: const Text('첫 계산 시작'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalculatorTab() {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: _listPadding(context),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '뒤로가기',
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  _goToMainTab(0);
                }
              },
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '옥탄가 계산',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: '계산 도움말',
              onPressed: _showInputHelp,
              icon: const Icon(
                Icons.help_outline_rounded,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _darkDashboardCard(
          padding: const EdgeInsets.all(12),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFD32F2F),
                size: 19,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  '계산 결과는 자동으로 저장되지 않습니다. 결과 확인 후 기록 저장을 선택해 주세요.',
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _inputInfoCard(),
      ],
    );
  }

  Widget _simplifiedRecordRow(Box<OctaneLog> box, OctaneLog log) {
    final liter = _logFuelLiter(log);
    final cost = _logCost(log);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          final index = box.values.toList().indexOf(log);
          if (index < 0) return;
          final key = box.keyAt(index);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HistoryDetailPage(log: log, logKey: key),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(15, 14, 9, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _recordDateTime(log.time),
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_gas_station_rounded,
                          color: Color(0xFFD32F2F),
                          size: 17,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _typeTitle(log.type),
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    if (liter != null || cost != null) ...[
                      const SizedBox(height: 9),
                      Text(
                        [
                          if (liter != null) _formatLiter(liter),
                          if (cost != null && cost > 0) _formatWon(cost),
                        ].join(' · '),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    log.result.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'RON',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF334155),
                size: 25,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _recordDateTime(DateTime time) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '${time.month}월 ${time.day}일 (${weekdays[time.weekday - 1]}) $hour:$minute';
  }

  Future<void> _exportBackup() async {
    if (_dataOperationInProgress) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('백업 파일 내보내기'),
                content: const Text(
                  '백업 파일에는 차량 정보와 주유 기록, 메모가 포함될 수 있습니다.\n\n'
                  '차량 사진은 포함되지 않습니다. 안전한 위치에 보관해 주세요.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('취소'),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('내보내기'),
                  ),
                ],
              ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _dataOperationInProgress = true);
    try {
      final document = await BackupService.captureCurrentData();
      AnalyticsService.log(
        'backup_export_started',
        parameters: _backupAnalyticsParameters(document),
      );
      final result = await BackupService.export(document);
      if (!mounted) return;

      if (result == BackupExportResult.cancelled) {
        _showDataSnackBar('백업 파일 공유를 취소했습니다.');
        return;
      }
      AnalyticsService.log(
        'backup_export_completed',
        parameters: _backupAnalyticsParameters(document),
      );
      _showDataSnackBar('백업 파일을 생성했습니다. 안전한 위치에 보관해 주세요.');
    } on BackupOperationException catch (error) {
      AnalyticsService.log(
        'backup_export_failed',
        parameters: {'failure_stage': error.failureStage},
      );
      if (mounted) {
        _showDataSnackBar('백업 파일을 생성하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } catch (_) {
      AnalyticsService.log(
        'backup_export_failed',
        parameters: const {'failure_stage': 'write'},
      );
      if (mounted) {
        _showDataSnackBar('백업 파일을 생성하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _dataOperationInProgress = false);
    }
  }

  Future<void> _saveBackupFile() async {
    if (_dataOperationInProgress) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('백업 파일 저장'),
                content: const Text(
                  '차량 정보와 주유 기록, 메모가 JSON 백업 파일에 저장됩니다.\n\n'
                  '차량 사진은 포함되지 않습니다. 파일앱의 Download/고급유노트 폴더에서 확인할 수 있습니다.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('취소'),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('저장'),
                  ),
                ],
              ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _dataOperationInProgress = true);
    try {
      final document = await BackupService.captureCurrentData();
      AnalyticsService.log(
        'backup_file_save_started',
        parameters: _backupAnalyticsParameters(document),
      );
      final result = await BackupService.saveToDownloads(document);
      if (!mounted) return;
      AnalyticsService.log(
        'backup_file_save_completed',
        parameters: _backupAnalyticsParameters(document),
      );
      _showDataSnackBar('백업 파일을 ${result.displayLocation}에 저장했습니다.');
    } on BackupOperationException catch (error) {
      AnalyticsService.log(
        'backup_file_save_failed',
        parameters: {'failure_stage': error.failureStage},
      );
      if (!mounted) return;
      final message =
          error.failureStage == 'unsupported_android_version'
              ? 'Android 10 이상에서 백업 파일 저장을 지원합니다.'
              : '백업 파일을 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.';
      _showDataSnackBar(message);
    } catch (_) {
      AnalyticsService.log(
        'backup_file_save_failed',
        parameters: const {'failure_stage': 'external_storage'},
      );
      if (mounted) {
        _showDataSnackBar('백업 파일을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _dataOperationInProgress = false);
    }
  }

  Future<void> _restoreBackup() async {
    if (_dataOperationInProgress) return;
    AnalyticsService.log('restore_started');
    setState(() => _dataOperationInProgress = true);
    try {
      final document = await BackupService.pickAndValidate();
      if (document == null || !mounted) return;

      AnalyticsService.log(
        'restore_validated',
        parameters: _backupAnalyticsParameters(document),
      );
      final confirmed = await _showRestorePreview(document);
      if (!confirmed || !mounted) return;

      await BackupService.restore(document);
      if (!mounted) return;
      _resetAfterDataChange();
      AnalyticsService.log(
        'restore_completed',
        parameters: _backupAnalyticsParameters(document),
      );
      _showDataSnackBar('데이터 복구가 완료되었습니다.');
    } on BackupValidationException catch (error) {
      AnalyticsService.log(
        'restore_failed',
        parameters: const {'failure_stage': 'validation'},
      );
      if (!mounted) return;
      final message =
          error.error == BackupValidationError.unsupportedVersion
              ? '지원하지 않는 버전의 백업 파일입니다. 앱을 최신 버전으로 업데이트한 후 다시 시도해 주세요.'
              : '고급유 노트에서 생성한 올바른 백업 파일이 아닙니다.';
      _showDataSnackBar(message);
    } on BackupOperationException catch (error) {
      AnalyticsService.log(
        'restore_failed',
        parameters: {'failure_stage': error.failureStage},
      );
      if (mounted) {
        _showDataSnackBar('데이터를 복구하지 못했습니다. 기존 데이터는 유지됩니다.');
      }
    } catch (_) {
      AnalyticsService.log(
        'restore_failed',
        parameters: const {'failure_stage': 'write'},
      );
      if (mounted) {
        _showDataSnackBar('데이터를 복구하지 못했습니다. 기존 데이터는 유지됩니다.');
      }
    } finally {
      if (mounted) setState(() => _dataOperationInProgress = false);
    }
  }

  Future<bool> _showRestorePreview(BackupDocument document) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('복구 미리보기'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _restorePreviewRow(
                    '백업 일시',
                    _backupDateTime(document.exportedAt),
                  ),
                  _restorePreviewRow('앱 버전', document.appVersion),
                  _restorePreviewRow('차량', '${document.vehicleCount}대'),
                  _restorePreviewRow('주유 기록', '${document.recordCount}개'),
                  _restorePreviewRow(
                    '설정 데이터',
                    document.includesSettings ? '포함' : '없음',
                  ),
                  const Divider(height: 28),
                  const Text(
                    '차량 사진은 포함되지 않은 백업입니다.',
                    style: TextStyle(
                      color: Color(0xFFFFC857),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '현재 데이터를 백업 파일의 데이터로 교체합니다.\n\n'
                    '기존 차량 정보와 주유 기록은 삭제되며, 복구 후 되돌릴 수 없습니다.',
                    style: TextStyle(height: 1.45),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD94F4F),
                  foregroundColor: Color(0xFFFFFFFF),
                ),
                child: const Text('복구하기'),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  Widget _restorePreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Future<void> _deleteAllData() async {
    if (_dataOperationInProgress) return;
    final continueDelete =
        await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('전체 데이터 삭제'),
                content: const Text(
                  '모든 차량 정보와 주유 기록을 삭제할까요?\n\n'
                  '차량 사진과 앱 설정도 함께 삭제되며 복구할 수 없습니다.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('취소'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD94F4F),
                      foregroundColor: Color(0xFFFFFFFF),
                    ),
                    child: const Text('계속'),
                  ),
                ],
              ),
        ) ??
        false;
    if (!continueDelete || !mounted) return;

    var confirmationText = '';
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => StatefulBuilder(
                builder:
                    (context, setDialogState) => AlertDialog(
                      title: const Text('삭제 확인'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('삭제하려면 아래에 "삭제"를 입력해 주세요.'),
                          const SizedBox(height: 14),
                          TextField(
                            autofocus: true,
                            onChanged:
                                (value) => setDialogState(
                                  () => confirmationText = value.trim(),
                                ),
                            decoration: const InputDecoration(hintText: '삭제'),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('취소'),
                        ),
                        FilledButton(
                          onPressed:
                              confirmationText == '삭제'
                                  ? () => Navigator.pop(dialogContext, true)
                                  : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD94F4F),
                            foregroundColor: Color(0xFFFFFFFF),
                          ),
                          child: const Text('모두 삭제'),
                        ),
                      ],
                    ),
              ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _dataOperationInProgress = true);
    try {
      await BackupService.deleteAllData();
      if (!mounted) return;
      _resetAfterDataChange();
      AnalyticsService.log('all_data_deleted');
      _showDataSnackBar('모든 데이터를 삭제했습니다.');
      await _showOnboardingIfNeeded();
    } on BackupOperationException {
      if (mounted) {
        _showDataSnackBar('데이터를 삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _dataOperationInProgress = false);
    }
  }

  void _resetAfterDataChange() {
    for (final controller in [
      highFuelCtrl,
      regFuelCtrl,
      highOctaneCtrl,
      regularOctaneCtrl,
      beforeLiterCtrl,
      beforeOctaneCtrl,
      addLiterCtrl,
      addOctaneCtrl,
      mixTankCtrl,
      targetOctaneCtrl,
      targetCurrentLiterCtrl,
      targetCurrentOctaneCtrl,
      targetFuelOctaneCtrl,
      carNameCtrl,
      carYearCtrl,
      carRecCtrl,
      carWarnCtrl,
      carTankCtrl,
      recordSearchCtrl,
    ]) {
      controller.clear();
    }

    final car = _mainCar();
    if (car != null) _fillCarForm(car);
    setState(() {
      _selectedCarPhoto = car?.photoBytes;
      _avgResult = null;
      _mixResult = null;
      _targetRequiredLiter = null;
      _targetComment = null;
      _targetImpossible = false;
      _targetResultOctane = null;
      _targetTotalLiter = null;
      _recordFilter = 0;
      _recordSearchVisible = false;
      _touchedValue = null;
      _selectedSpotIndex = null;
      _currentMainTab = 0;
    });
    _tabController.animateTo(0);
  }

  Map<String, Object> _backupAnalyticsParameters(BackupDocument document) {
    return {
      'vehicle_count': document.vehicleCount,
      'record_count': document.recordCount,
      'backup_format_version': BackupService.currentBackupFormatVersion,
      'includes_images': 'false',
    };
  }

  String _backupDateTime(DateTime time) {
    return '${time.year}.${time.month.toString().padLeft(2, '0')}.${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showDataSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildMoreTab() {
    return ListView(
      padding: _listPadding(context),
      children: [
        _darkScreenHeader(
          '더보기',
          '주유 생활에 필요한 관리 기능을 모아두었어요',
          Icons.more_horiz_rounded,
        ),
        const SizedBox(height: 16),
        _moreGroupLabel('데이터 관리'),
        _moreFeatureTile(
          '백업 파일 저장',
          'Download/고급유노트에 JSON 파일로 저장합니다.',
          Icons.save_alt_rounded,
          _saveBackupFile,
        ),
        _moreFeatureTile(
          '백업 파일 공유하기',
          '백업 JSON 파일을 다른 앱으로 공유합니다.',
          Icons.upload_file_outlined,
          _exportBackup,
        ),
        _moreFeatureTile(
          '백업 파일 불러오기',
          '이전에 저장한 백업 파일로 데이터를 복원합니다.',
          Icons.restore_outlined,
          _restoreBackup,
        ),
        _moreFeatureTile(
          '전체 데이터 삭제',
          '이 기기의 모든 차량 정보와 기록을 삭제합니다.',
          Icons.delete_forever_outlined,
          _deleteAllData,
          accentColor: const Color(0xFFFF6B6B),
        ),
        const SizedBox(height: 8),
        _moreGroupLabel('관리 도구'),
        _moreFeatureTile(
          '주유비 관리',
          '기간별 주유 지출과 항목을 확인해요',
          Icons.payments_outlined,
          () => _showFeatureSheet('주유비 관리', _expenseFeature()),
        ),
        _moreFeatureTile(
          '주유소 찾기',
          '주유 기록과 연동되는 위치 관리 기능을 준비하고 있어요.',
          Icons.location_on_outlined,
          () => _showFeatureSheet('주유소 찾기', _stationFinderComingSoon()),
          badge: '준비 중',
        ),
        const SizedBox(height: 8),
        _moreGroupLabel('분석'),
        _moreFeatureTile(
          '월간 리포트',
          '한 달의 실제 주유 기록을 요약해요',
          Icons.calendar_month_outlined,
          () => _showFeatureSheet('월간 리포트', _monthlyFeature()),
        ),
        const SizedBox(height: 8),
        _moreGroupLabel('도움말'),
        _moreFeatureTile(
          '사용 방법',
          '사용 방법과 기록 기준을 확인해요',
          Icons.help_outline_rounded,
          () => _showFeatureSheet('도움말', _usageGuideCard()),
        ),
        const SizedBox(height: 8),
        _moreGroupLabel('정보'),
        _moreFeatureTile(
          '업데이트 내역',
          '버전과 업데이트 내역을 확인해요',
          Icons.info_outline_rounded,
          () => _showFeatureSheet('업데이트 내역', _updateHistoryCard()),
        ),
        _moreFeatureTile(
          '피드백 보내기',
          '서비스 개선에 참여해 주세요',
          Icons.feedback_outlined,
          () => _showFeatureSheet('피드백 보내기', _contactCard()),
        ),
        _moreFeatureTile(
          '앱 정보',
          '앱 버전과 기본 정보를 확인해요',
          Icons.apps_rounded,
          () => _showFeatureSheet('앱 정보', _appInfoFeature()),
        ),
      ],
    );
  }

  Widget _moreGroupLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 9),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _darkScreenHeader(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFDECEC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFD32F2F)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _darkActionButton(String text, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Color(0xFFFFFFFF),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _moreFeatureTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    String? badge,
    Color accentColor = const Color(0xFFD32F2F),
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _darkDashboardCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 5,
          ),
          leading: Icon(icon, color: accentColor, size: 26),
          title: Text(
            title,
            style: TextStyle(
              color:
                  accentColor == const Color(0xFFFF6B6B)
                      ? accentColor
                      : Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Color(0xFFD32F2F),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
              ],
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeatureSheet(String title, Widget child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF7FAFC),
      builder: (sheetContext) {
        final keyboardInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  child,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _featureMetric(String label, String value, {String? unit}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7F8D9C),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (unit != null)
              Text(
                unit,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  Widget _appInfoFeature() {
    return _darkDashboardCard(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '고급유 노트',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '버전 1.0.3',
            style: TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '옥탄가 계산 결과와 주유 기록은 기기 내부에 저장됩니다.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stationFinderComingSoon() {
    return _darkDashboardCard(
      child: Builder(
        builder:
            (sheetContext) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFFD32F2F),
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    '더 편리한 주유 기록 관리를 위해 준비 중입니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '주유 기록과 연동되는 주유소 위치 관리 기능을 준비하고 있습니다.\n\n앞으로 주변 고급유 주유소 검색과 주유 기록 위치 관리 기능을 제공할 예정입니다.',
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('확인'),
                ),
              ],
            ),
      ),
    );
  }

  Widget _expenseFeature() {
    final now = DateTime.now();
    final logs = Hive.box<OctaneLog>('octane_logs').values.toList();
    final currentLogs =
        logs
            .where(
              (log) => log.time.year == now.year && log.time.month == now.month,
            )
            .toList();
    final previousDate = DateTime(now.year, now.month - 1);
    final previousLogs =
        logs
            .where(
              (log) =>
                  log.time.year == previousDate.year &&
                  log.time.month == previousDate.month,
            )
            .toList();
    final currentCosts = currentLogs
        .map(_logCost)
        .whereType<double>()
        .where((cost) => cost > 0);
    final previousCosts = previousLogs
        .map(_logCost)
        .whereType<double>()
        .where((cost) => cost > 0);
    final currentTotal = currentCosts.fold<double>(
      0,
      (sum, cost) => sum + cost,
    );
    final previousTotal = previousCosts.fold<double>(
      0,
      (sum, cost) => sum + cost,
    );
    final costCount = currentCosts.length;
    final averageCost = costCount == 0 ? 0.0 : currentTotal / costCount;
    final comparison =
        previousTotal <= 0
            ? '--'
            : '${((currentTotal - previousTotal) / previousTotal * 100) >= 0 ? '+' : ''}'
                '${((currentTotal - previousTotal) / previousTotal * 100).toStringAsFixed(1)}%';

    return _darkDashboardCard(
      child: Column(
        children: [
          Row(
            children: [
              _featureMetric(
                '이번 달',
                currentTotal > 0 ? _formatWon(currentTotal) : '--',
              ),
              const SizedBox(width: 8),
              _featureMetric('저장 기록', '${currentLogs.length}', unit: '회'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _featureMetric(
                '평균 1회',
                averageCost > 0 ? _formatWon(averageCost) : '--',
              ),
              const SizedBox(width: 8),
              _featureMetric('지난달 대비', comparison),
            ],
          ),
          if (costCount == 0) ...[
            const SizedBox(height: 12),
            const Text(
              '이번 달 기록에 주유 금액을 입력하면 실제 지출 통계가 표시됩니다.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _monthlyFeature() {
    final now = DateTime.now();
    final logs =
        Hive.box<OctaneLog>('octane_logs').values
            .where(
              (log) => log.time.year == now.year && log.time.month == now.month,
            )
            .toList();
    final average =
        logs.isEmpty
            ? null
            : logs.map((log) => log.result).reduce((a, b) => a + b) /
                logs.length;
    final totalLiter = logs
        .map(_logFuelLiter)
        .whereType<double>()
        .fold<double>(0, (sum, liter) => sum + liter);
    final totalCost = logs
        .map(_logCost)
        .whereType<double>()
        .fold<double>(0, (sum, cost) => sum + cost);

    return _darkDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              '${now.year}년 ${now.month}월 리포트',
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _featureMetric('저장 기록', '${logs.length}', unit: '회'),
              const SizedBox(width: 8),
              _featureMetric(
                '평균 옥탄가',
                average?.toStringAsFixed(1) ?? '--',
                unit: average == null ? null : 'RON',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _featureMetric(
                '주유량',
                totalLiter > 0 ? totalLiter.toStringAsFixed(1) : '--',
                unit: totalLiter > 0 ? 'L' : null,
              ),
              const SizedBox(width: 8),
              _featureMetric(
                '주유비',
                totalCost > 0 ? _formatWon(totalCost) : '--',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            logs.isEmpty
                ? '이번 달에 저장된 기록이 없습니다.'
                : '이번 달에 저장한 ${logs.length}개의 실제 주유 기록을 기준으로 계산했습니다.',
            style: const TextStyle(color: Color(0xFF334155), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<OctaneLog>('octane_logs').listenable(),
      builder: (context, Box<OctaneLog> box, _) {
        if (box.isEmpty) {
          return ListView(
            padding: _listPadding(context),
            children: [
              _darkDashboardCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.bar_chart_rounded,
                        color: Color(0xFFD32F2F),
                        size: 44,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '저장된 기록이 없습니다.',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        '계산 결과를 저장하면\n옥탄가 통계를 확인할 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: () => _goToMainTab(2),
                        icon: const Icon(Icons.calculate_rounded),
                        label: const Text('옥탄가 계산하기'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final logs = box.values.toList();
        if (logs.length == 1) {
          return ListView(
            padding: _listPadding(context),
            children: [
              _singleRecordStats(logs.single),
              const SizedBox(height: 14),
              _targetMatchCard(logs.single),
              const SizedBox(height: 14),
              _historyListCard(logs),
            ],
          );
        }

        return ListView(
          padding: _listPadding(context),
          children: [
            _buildStatsCard(logs),
            const SizedBox(height: 14),
            _buildOctaneChart(logs),
            const SizedBox(height: 14),
            _targetMatchCard(logs.last),
            const SizedBox(height: 14),
            _historyListCard(logs),
          ],
        );
      },
    );
  }

  Widget _singleRecordStats(OctaneLog log) {
    return _darkDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '옥탄가 통계',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '현재 기록 1개',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _formatRon(log.result),
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          const Text(
            '추세를 확인하려면\n기록이 2개 이상 필요합니다.',
            style: TextStyle(
              color: Color(0xFF334155),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOctaneChart(List<OctaneLog> logs) {
    if (logs.isEmpty) return const SizedBox.shrink();
    final car = Hive.box<CarProfile>('car_profile').get('main');
    final target = car?.recommendedOctane;
    final chartLogs = logs.length > 5 ? logs.sublist(logs.length - 5) : logs;

    final spots = List.generate(
      chartLogs.length,
      (i) => FlSpot(i.toDouble(), chartLogs[i].result),
    );
    final chartValues = [
      ...chartLogs.map((log) => log.result),
      if (target != null) target,
    ];
    final lowestValue = chartValues.reduce(
      (current, value) => current < value ? current : value,
    );
    final highestValue = chartValues.reduce(
      (current, value) => current > value ? current : value,
    );
    final minY = (lowestValue - 0.5).floorToDouble();
    var maxY = (highestValue + 0.5).ceilToDouble();
    if (maxY - minY < 4) maxY = minY + 4;
    final horizontalInterval = maxY - minY <= 6 ? 1.0 : 2.0;

    final latest = chartLogs.last.result;
    final prev =
        chartLogs.length > 1 ? chartLogs[chartLogs.length - 2].result : latest;
    final diff = latest - prev;
    final displayValue = _touchedValue ?? latest;
    final selectedLabel =
        _selectedSpotIndex != null
            ? '${_selectedSpotIndex! + 1}번째 기록'
            : '최신 기록';
    final status = _status(displayValue);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '기록 추세',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: (diff >= 0
                          ? const Color(0xFF2C83C8)
                          : const Color(0xFFC3363B))
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      diff >= 0
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 17,
                      color:
                          diff >= 0
                              ? const Color(0xFF2C83C8)
                              : const Color(0xFFC3363B),
                    ),
                    const SizedBox(width: 3),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${diff >= 0 ? '+' : '-'}${DisplayFormat.decimal(diff.abs(), 1)}',
                          style: TextStyle(
                            color:
                                diff >= 0
                                    ? const Color(0xFF2C83C8)
                                    : const Color(0xFFC3363B),
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '최근 변화',
                          style: TextStyle(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              displayValue.toStringAsFixed(1),
              key: ValueKey(
                '${displayValue.toStringAsFixed(1)}_${_selectedSpotIndex ?? -1}',
              ),
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _softStatusChip(status),
          const SizedBox(height: 12),
          Text(
            _touchedValue != null ? '선택한 기록  $selectedLabel' : '현재 위치: 최신 기록',
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 218,
            child: LineChart(
              LineChartData(
                minX: spots.length == 1 ? -0.5 : 0,
                maxX: spots.length == 1 ? 0.5 : (spots.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                clipData: const FlClipData.all(),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: horizontalInterval,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= chartLogs.length) {
                          return const SizedBox.shrink();
                        }
                        final isFirst = index == 0;
                        final isLast = index == chartLogs.length - 1;
                        final sameAsPrevious =
                            index > 0 &&
                            _dateOnly(chartLogs[index].time) ==
                                _dateOnly(chartLogs[index - 1].time);
                        if (!isFirst && !isLast && sameAsPrevious) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${chartLogs[index].time.month}/${chartLogs[index].time.day}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: horizontalInterval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withValues(alpha: 0.16),
                      strokeWidth: 1,
                    );
                  },
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (target != null)
                      HorizontalLine(
                        y: target,
                        color: const Color(0xFFD32F2F).withValues(alpha: 0.42),
                        strokeWidth: 1,
                        dashArray: [4, 3],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.centerRight,
                          labelResolver:
                              (_) => '${target.toStringAsFixed(0)} (목표)',
                          style: const TextStyle(
                            color: Color(0xFFD32F2F),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                  verticalLines:
                      _selectedSpotIndex != null
                          ? [
                            VerticalLine(
                              x: _selectedSpotIndex!.toDouble(),
                              color: const Color(
                                0xFF1976D2,
                              ).withValues(alpha: 0.32),
                              strokeWidth: 1.2,
                              dashArray: [6, 4],
                            ),
                          ]
                          : [],
                ),
                showingTooltipIndicators:
                    _selectedSpotIndex != null
                        ? [
                          ShowingTooltipIndicators([
                            LineBarSpot(
                              LineChartBarData(spots: spots),
                              0,
                              spots[_selectedSpotIndex!],
                            ),
                          ]),
                        ]
                        : [],
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchSpotThreshold: 22,
                  touchCallback: (event, response) {
                    if (event is FlTapUpEvent ||
                        event is FlPanEndEvent ||
                        event is FlLongPressEnd) {
                      return;
                    }

                    final lineSpots = response?.lineBarSpots;
                    if (lineSpots != null && lineSpots.isNotEmpty) {
                      final spot = lineSpots.first;
                      setState(() {
                        _touchedValue = spot.y;
                        _selectedSpotIndex = spot.x.toInt();
                      });
                    }
                  },
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.black87,
                    tooltipRoundedRadius: 12,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          spot.y.toStringAsFixed(2),
                          const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.20,
                    preventCurveOverShooting: true,
                    color: const Color(0xFF1976D2),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final isSelected = _selectedSpotIndex == index;
                        final isLatest = index == spots.length - 1;

                        if (isSelected) {
                          return FlDotCirclePainter(
                            radius: 7.5,
                            color: const Color(0xFF1976D2),
                            strokeWidth: 4,
                            strokeColor: Color(0xFFFFFFFF),
                          );
                        }

                        if (isLatest) {
                          return FlDotCirclePainter(
                            radius: 5.5,
                            color: const Color(0xFF1976D2),
                            strokeWidth: 2,
                            strokeColor: Color(0xFFFFFFFF),
                          );
                        }

                        return FlDotCirclePainter(
                          radius: 4.5,
                          color: Color(0xFF0F172A),
                          strokeWidth: 2.6,
                          strokeColor: const Color(0xFF1976D2),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF1976D2).withValues(alpha: 0.12),
                      applyCutOffY: true,
                      cutOffY: minY,
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _targetMatchCard(OctaneLog latest) {
    final status = _status(latest.result);
    final brand = Theme.of(context).colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '목표 맞추기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: brand.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.flag_rounded, color: brand, size: 30),
                ),
                const SizedBox(width: 16),
                Flexible(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dateOnly(latest.time),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _statusChip(status),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      _formatRon(latest.result),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _softStatusChip(_Status st) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: st.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        st.label,
        style: TextStyle(
          color: st.color,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _historyListCard(List<OctaneLog> logs) {
    final recent = logs.reversed.take(3).toList();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '기록 목록',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 14),
            ...List.generate(recent.length, (index) {
              return _compactHistoryItem(
                recent[index],
                previous: _previousForRecent(logs, index),
                indexFromTop: index,
              );
            }),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _showAllHistory(logs),
              icon: const Icon(Icons.list_rounded),
              label: const Text('전체 기록 보기'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: const Color(0xFFD32F2F),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactHistoryItem(
    OctaneLog log, {
    required double? previous,
    required int indexFromTop,
  }) {
    final double diff = previous == null ? 0.0 : log.result - previous;
    final isUp = diff >= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onLongPress: () => _confirmDeleteLog(indexFromTop),
          onTap: () {
            final box = Hive.box<OctaneLog>('octane_logs');
            final logKey = box.keyAt(box.length - 1 - indexFromTop);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HistoryDetailPage(log: log, logKey: logKey),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _dateTimeShort(log.time),
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  DisplayFormat.decimal(log.result, 1),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (previous != null) ...[
                  const SizedBox(width: 10),
                  _diffPill(diff, isUp),
                ],
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _diffPill(double diff, bool isUp) {
    final color = isUp ? const Color(0xFF2C83C8) : const Color(0xFFC3363B);
    final icon =
        isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 2),
          Text(
            '${isUp ? '+' : '-'}${DisplayFormat.decimal(diff.abs(), 1)}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  void _showAllHistory(List<OctaneLog> logs) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final recent = logs.reversed.toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: List.generate(recent.length, (index) {
            return _compactHistoryItem(
              recent[index],
              previous: _previousForRecent(logs, index),
              indexFromTop: index,
            );
          }),
        );
      },
    );
  }

  double? _previousForRecent(List<OctaneLog> logs, int indexFromTop) {
    final originalIndex = logs.length - 1 - indexFromTop;
    if (originalIndex <= 0) return null;
    return logs[originalIndex - 1].result;
  }

  String _dateOnly(DateTime time) {
    return '${time.year}.${time.month.toString().padLeft(2, '0')}.${time.day.toString().padLeft(2, '0')}';
  }

  String _dateTimeShort(DateTime time) {
    return '${_dateOnly(time)} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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

  Widget _calcButton(String text, {required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.calculate_rounded, size: 26),
      label: Text(text),
      onPressed: onPressed,
    );
  }

  Widget _numberField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    String? unit,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: unit,
      ),
    );
  }

  void _fillCarForm(CarProfile car) {
    carNameCtrl.text = car.name;
    carYearCtrl.text = car.year.toString();
    carRecCtrl.text = car.recommendedOctane.toString();
    carWarnCtrl.text = car.warningOctane.toString();
    carTankCtrl.text = car.tankCapacity?.toString() ?? '';
    _selectedCarPhoto ??= car.photoBytes;
  }

  Widget _buildVehicleDashboardTab() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<CarProfile>('car_profile').listenable(),
      builder: (context, Box<CarProfile> box, _) {
        final car = box.get('main');
        final logs = Hive.box<OctaneLog>('octane_logs').values.toList();
        final latest = logs.isEmpty ? null : logs.last;

        return ListView(
          padding: _listPadding(context),
          children: [
            _darkScreenHeader(
              '내 차량',
              '차량 기준과 주유 정보를 한눈에 확인해요',
              Icons.directions_car_rounded,
            ),
            const SizedBox(height: 14),
            _darkDashboardCard(
              padding: const EdgeInsets.fromLTRB(17, 17, 14, 17),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          car == null
                              ? '등록된 차량이 없습니다'
                              : '${car.year} ${car.name}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          car == null
                              ? '차량을 등록하면 권장 옥탄가를 확인할 수 있어요'
                              : '차량 기준 / 연료 관리',
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          car == null
                              ? '차량 정보 미설정'
                              : '최근 옥탄가 ${latest?.result.toStringAsFixed(1) ?? '--'} RON',
                          style: const TextStyle(
                            color: Color(0xFFD32F2F),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (car?.photoBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        car!.photoBytes!,
                        width: 128,
                        height: 86,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(
                        Icons.directions_car_rounded,
                        color: Color(0xFF64748B),
                        size: 44,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _vehicleMetric(
                  '권장 기준',
                  car == null ? '--' : car.recommendedOctane.toStringAsFixed(1),
                  'RON 이상',
                ),
                const SizedBox(width: 9),
                _vehicleMetric(
                  '주의 기준',
                  car == null ? '--' : car.warningOctane.toStringAsFixed(1),
                  'RON 미만',
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                _vehicleMetric(
                  '탱크 용량',
                  car?.tankCapacity?.toStringAsFixed(0) ?? '--',
                  'L',
                ),
                const SizedBox(width: 9),
                _vehicleMetric('누적 기록', '${logs.length}', '회'),
              ],
            ),
            const SizedBox(height: 14),
            _darkActionButton(
              car == null ? '차량 등록하기' : '차량 정보 편집',
              Icons.edit_rounded,
              () {
                if (car != null) {
                  _fillCarForm(car);
                } else {
                  _selectedCarPhoto = null;
                }
                _showFeatureSheet(
                  car == null ? '차량 등록' : '차량 정보 편집',
                  _vehicleSettingsCard(box, car, closeOnSave: true),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _vehicleMetric(String title, String value, String unit) {
    return Expanded(
      child: _darkDashboardCard(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Text(
                      unit,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
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

  Widget _vehicleSettingsCard(
    Box<CarProfile> box,
    CarProfile? car, {
    bool closeOnSave = false,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: const Color(0xFFFFFFFF),
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: car == null,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: const Icon(
            Icons.directions_car_outlined,
            color: Color(0xFFD32F2F),
          ),
          title: const Text(
            '차량 설정',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            car == null
                ? '권장 옥탄가와 경고 기준을 저장해 주세요'
                : '${car.name} (${car.year})  권장 ${car.recommendedOctane} / 경고 ${car.warningOctane}',
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          children: [
            if (car == null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '아직 저장된 차량 정보가 없습니다.',
                  style: TextStyle(
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (car != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '${car.name} (${car.year})  권장 ${car.recommendedOctane} / 경고 ${car.warningOctane}'
                  '${car.tankCapacity != null ? '  탱크 ${car.tankCapacity}L' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder:
                  (context, setPhotoState) => InkWell(
                    onTap: () async {
                      final photo = await _pickCarPhoto();
                      if (photo != null) setPhotoState(() {});
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child:
                          _selectedCarPhoto != null
                              ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: Image.memory(
                                      _selectedCarPhoto!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const Align(
                                    alignment: Alignment.bottomRight,
                                    child: Padding(
                                      padding: EdgeInsets.all(10),
                                      child: CircleAvatar(
                                        backgroundColor: Color(0xCCF8FAFC),
                                        foregroundColor: Color(0xFFD32F2F),
                                        child: Icon(Icons.edit_rounded),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                              : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: Color(0xFFD32F2F),
                                    size: 36,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '차량 사진 등록',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: carNameCtrl,
                    decoration: const InputDecoration(
                      labelText: '차량명',
                      hintText: '예: 아반떼 N',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _numberField(carYearCtrl, '연식', hint: '예: 2023'),
                  const SizedBox(height: 14),
                  _numberField(carRecCtrl, '권장 옥탄가', hint: '예: 95'),
                  const SizedBox(height: 14),
                  _numberField(carWarnCtrl, '경고 기준 옥탄가', hint: '예: 91'),
                  const SizedBox(height: 14),
                  _numberField(carTankCtrl, '탱크 용량 (L)', hint: '예: 50'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () async {
                final name = carNameCtrl.text.trim();
                final year = int.tryParse(carYearCtrl.text.trim());
                final recommend = double.tryParse(carRecCtrl.text.trim());
                final warning = double.tryParse(carWarnCtrl.text.trim());
                final tankText = carTankCtrl.text.trim();
                final tank =
                    tankText.isEmpty ? null : double.tryParse(tankText);

                String? error;
                final currentYear = DateTime.now().year;
                if (name.isEmpty) {
                  error = '차량명을 입력해 주세요.';
                } else if (year == null ||
                    year < 1980 ||
                    year > currentYear + 1) {
                  error = '연식은 1980~${currentYear + 1} 사이로 입력해 주세요.';
                } else if (recommend == null || warning == null) {
                  error = '권장 옥탄가와 경고 기준을 모두 입력해 주세요.';
                } else if (tank != null && tank <= 0) {
                  error = '탱크 용량은 0보다 커야 합니다.';
                }

                if (error != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error)));
                  return;
                }

                await _saveCarProfile(
                  name: name,
                  year: year!,
                  recommend: recommend!,
                  warning: warning!,
                  tank: tank,
                  photoBytes: _selectedCarPhoto,
                );
                if (!mounted || !context.mounted) return;

                FocusScope.of(context).unfocus();
                if (closeOnSave && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('차량 정보를 저장했습니다.')));
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('차량 정보 저장'),
            ),
            if (car != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _confirmDeleteCar(box),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('저장된 차량 삭제'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openContactEmail() async {
    AnalyticsService.log('send_email_inquiry');
    final uri = Uri(
      scheme: 'mailto',
      path: 'bgpoilkj@naver.com',
      queryParameters: {'subject': '고급유노트 문의'},
    );

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (_) {
      // Fall back to copying the address below.
    }

    await Clipboard.setData(const ClipboardData(text: 'bgpoilkj@naver.com'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('메일 앱을 열 수 없어 이메일 주소를 복사했습니다.')),
    );
  }

  Widget _usageGuideCard() {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: const Icon(Icons.help_outline_rounded),
          title: const Text(
            '사용 방법',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            '계산과 기록 흐름 안내',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
          children: [
            _usageStep(
              icon: Icons.directions_car_outlined,
              title: '차량 기준 설정',
              message: '권장 옥탄가와 경고 기준을 저장하면 계산 결과를 내 차량 기준으로 판단합니다.',
            ),
            const SizedBox(height: 10),
            _usageStep(
              icon: Icons.calculate_outlined,
              title: '계산하기',
              message: '단순 혼합, 탱크 기준, 목표 맞추기 중 상황에 맞는 방식을 선택하고 값을 입력합니다.',
            ),
            const SizedBox(height: 10),
            _usageStep(
              icon: Icons.save_outlined,
              title: '필요할 때 기록 저장',
              message: '계산만으로는 기록이 저장되지 않습니다. 결과를 남기고 싶을 때 기록 저장을 눌러주세요.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _usageStep({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFD32F2F), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactCard() {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: const Icon(Icons.mail_outline_rounded),
          title: const Text(
            '문의',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            'bgpoilkj@naver.com',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                '오류 제보, 개선 의견, 차량 기준 관련 문의를 보내주세요.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _openContactEmail,
              icon: const Icon(Icons.mail_rounded),
              label: const Text('메일 보내기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _updateHistoryCard() {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: const Icon(Icons.new_releases_outlined),
          title: const Text(
            '업데이트 내역',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            '최근 개선 사항',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
          children: const [
            _ReleaseNote(
              version: 'v1.0.3',
              items: [
                '라이트 테마와 브랜드 포인트 색상을 적용했어요',
                '단순 혼합·탱크 기준·목표 맞추기 계산 화면을 개선했어요',
                '주유소명, 누적 주행거리, 가득 주유 기록을 추가했어요',
                '백업 파일을 Download/고급유노트 폴더에 직접 저장할 수 있어요',
                '그래프와 화면 안전 영역 표시 문제를 개선했어요',
              ],
            ),
            SizedBox(height: 12),
            _ReleaseNote(
              version: 'v1.0.2',
              items: [
                '계산 결과와 추천 전략을 화면 상단에 배치',
                '계산 결과가 자동으로 기록되지 않도록 변경',
                '저장 전 상태와 최근 기록 대비 변화량 표시',
                '첫 실행 시 차량 설정 가이드 추가',
                '설정, 문의, 사용 방법 메뉴 정리',
              ],
            ),
            SizedBox(height: 12),
            _ReleaseNote(
              version: 'v1.0.1',
              items: ['차량별 권장/경고 옥탄가 설정 추가', '최근 기록 통계와 그래프 화면 개선'],
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;

  const _OnboardingStep({
    required this.number,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEC),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFFD32F2F),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Icon(icon, color: const Color(0xFF64748B), size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseNote extends StatelessWidget {
  final String version;
  final List<String> items;

  const _ReleaseNote({required this.version, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            version,
            style: const TextStyle(
              color: Color(0xFFD32F2F),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '- ',
                    style: TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Status {
  final String label;
  final String message;
  final IconData icon;
  final Color color;

  const _Status(this.label, this.message, this.icon, this.color);
}

enum _ReviewPromptAction { accepted, later }

class _TankInsight {
  final String title;
  final String message;

  const _TankInsight({required this.title, required this.message});
}
