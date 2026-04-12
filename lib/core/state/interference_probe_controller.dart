import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_app_api_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_snapshot_store.dart';
import 'package:sleep_dorm_app/core/data/backend_contract.dart';
import 'package:sleep_dorm_app/core/data/model_serializers.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class InterferenceProbeController extends ChangeNotifier {
  InterferenceProbeController({
    required AuthRepository authRepository,
    required DormRepository dormRepository,
    required AppEnvironment environment,
    CloudBaseAppApiClient? appApiClient,
    CloudBaseSnapshotStore? snapshotStore,
    AndroidUsageStatsGateway? usageStatsGateway,
  }) : _authRepository = authRepository,
       _dormRepository = dormRepository,
       _environment = environment,
       _appApiClient = appApiClient,
       _snapshotStore = snapshotStore,
       _usageStatsGateway = usageStatsGateway ?? const AndroidUsageStatsGateway(),
       _state = _buildFallbackState(dormRepository.currentDorm) {
    _dormRepository.addListener(_syncDormFallbacks);
    _snapshotStore?.addListener(_hydrateFromSnapshot);
    _hydrateFromSnapshot();
  }

  final AuthRepository _authRepository;
  final DormRepository _dormRepository;
  final AppEnvironment _environment;
  final CloudBaseAppApiClient? _appApiClient;
  final CloudBaseSnapshotStore? _snapshotStore;
  final AndroidUsageStatsGateway _usageStatsGateway;

  TonightInterferenceState _state;
  final Set<InterferenceFactorType> _activeProbes = <InterferenceFactorType>{};

  TonightInterferenceState get currentState => _state;

  bool get usesCloudBasePersistence =>
      _environment.usesCloudBase && (_appApiClient?.isConfigured ?? false);

  Future<void> ensureFreshForDetailPage() async {
    _primeEmotionSnapshot();
    for (final InterferenceFactorType factor in <InterferenceFactorType>[
      InterferenceFactorType.noise,
      InterferenceFactorType.light,
      InterferenceFactorType.phoneUsage,
    ]) {
      if (_shouldAutoRefresh(_state.factorOf(factor))) {
        await detectFactor(factor, allowPermissionPrompt: true);
      }
    }
  }

  Future<void> detectFactor(
    InterferenceFactorType type, {
    bool allowPermissionPrompt = true,
  }) {
    return switch (type) {
      InterferenceFactorType.noise => _detectNoise(
        allowPermissionPrompt: allowPermissionPrompt,
      ),
      InterferenceFactorType.light => _detectLight(
        allowPermissionPrompt: allowPermissionPrompt,
      ),
      InterferenceFactorType.phoneUsage => _detectPhoneUsage(
        allowPermissionPrompt: allowPermissionPrompt,
      ),
      InterferenceFactorType.emotion => _detectEmotion(),
    };
  }

  void _hydrateFromSnapshot() {
    final Map<String, dynamic> payload =
        _snapshotStore?.payload ?? <String, dynamic>{};
    final Map<String, dynamic> root = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : payload;
    final Map<String, dynamic> userState = root['userState'] is Map
        ? Map<String, dynamic>.from(root['userState'] as Map)
        : <String, dynamic>{};
    final dynamic rawInterferenceValue = userState['tonightInterference'];
    final Map<String, dynamic> rawInterference = rawInterferenceValue is Map
        ? Map<String, dynamic>.from(rawInterferenceValue)
        : <String, dynamic>{};
    if (rawInterference.isEmpty) {
      _syncDormFallbacks();
      return;
    }
    _state = ModelSerializers.tonightInterferenceStateFromMap(
      rawInterference,
      fallback: _buildFallbackState(_dormRepository.currentDorm),
    );
    notifyListeners();
  }

  void _syncDormFallbacks() {
    final Dorm dorm = _dormRepository.currentDorm;

    InterferenceFactorSnapshot keepMeasuredOrFallback(
      InterferenceFactorSnapshot current,
      InterferenceFactorSnapshot fallback,
    ) {
      final bool shouldReplace =
          current.source == 'dorm_state' || current.measuredAt == null;
      return shouldReplace ? fallback : current;
    }

    _state = _state.copyWith(
      noise: keepMeasuredOrFallback(_state.noise, _defaultNoiseSnapshot(dorm)),
      light: keepMeasuredOrFallback(_state.light, _defaultLightSnapshot(dorm)),
      emotion: _state.emotion.status == InterferenceFactorStatus.idle
          ? _defaultEmotionSnapshot()
          : _state.emotion,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  bool _shouldAutoRefresh(InterferenceFactorSnapshot snapshot) {
    if (snapshot.status == InterferenceFactorStatus.denied ||
        snapshot.status == InterferenceFactorStatus.unsupported) {
      return false;
    }
    if (snapshot.measuredAt == null) {
      return true;
    }
    return DateTime.now().difference(snapshot.measuredAt!) >
        const Duration(minutes: 15);
  }

  Future<void> _detectNoise({
    required bool allowPermissionPrompt,
  }) async {
    if (!Platform.isAndroid) {
      _commitLocalFactor(
        InterferenceFactorSnapshot(
          type: InterferenceFactorType.noise,
          title: '宿舍噪声',
          value: '暂不支持',
          gradeLabel: '暂不支持',
          status: InterferenceFactorStatus.unsupported,
          detail: '当前这项能力仅在 Android 设备上开放。',
          source: 'unsupported',
          measuredAt: DateTime.now(),
        ),
      );
      return;
    }

    final PermissionStatus permission = allowPermissionPrompt
        ? await Permission.microphone.request()
        : await Permission.microphone.status;
    if (!permission.isGranted) {
      _commitLocalFactor(
        InterferenceFactorSnapshot(
          type: InterferenceFactorType.noise,
          title: '宿舍噪声',
          value: '未授权',
          gradeLabel: '未授权',
          status: InterferenceFactorStatus.denied,
          detail: '先打开麦克风权限，我才能帮你听听现在的宿舍环境。',
          source: 'microphone_permission',
          measuredAt: DateTime.now(),
        ),
      );
      return;
    }

    if (_activeProbes.contains(InterferenceFactorType.noise)) {
      return;
    }
    _activeProbes.add(InterferenceFactorType.noise);
    _commitLocalFactor(
      _state.noise.copyWith(
        status: InterferenceFactorStatus.measuring,
        value: '检测中...',
        gradeLabel: '检测中',
        detail: '小眠正在听一听此刻宿舍里的声音。',
        measuredAt: DateTime.now(),
      ),
    );

    final NoiseMeter noiseMeter = NoiseMeter();
    final List<double> samples = <double>[];
    StreamSubscription<NoiseReading>? subscription;
    try {
      subscription = noiseMeter.noise.listen((NoiseReading reading) {
        if (reading.meanDecibel.isFinite && reading.meanDecibel > 0) {
          samples.add(reading.meanDecibel);
        }
      });
      await Future<void>.delayed(const Duration(seconds: 3));
      await subscription.cancel();

      if (samples.isEmpty) {
        throw StateError('No microphone readings captured.');
      }

      final double average =
          samples.reduce((double a, double b) => a + b) / samples.length;
      final _ProbeGrade grade = _noiseGrade(average);
      final InterferenceFactorSnapshot factor = InterferenceFactorSnapshot(
        type: InterferenceFactorType.noise,
        title: '宿舍噪声',
        value: '${average.round()} dB',
        gradeLabel: grade.label,
        status: InterferenceFactorStatus.ready,
        detail: grade.detail,
        source: 'microphone',
        measuredAt: DateTime.now(),
        numericValue: average,
        score: grade.score,
      );
      _commitLocalFactor(factor);
      await _persistFactor(factor);
      await _dormRepository.updateDormEnvironment(noiseDb: average.round());
    } catch (_) {
      await subscription?.cancel();
      _commitLocalFactor(
        InterferenceFactorSnapshot(
          type: InterferenceFactorType.noise,
          title: '宿舍噪声',
          value: '检测失败',
          gradeLabel: '检测失败',
          status: InterferenceFactorStatus.error,
          detail: '这次没有顺利读到噪声，稍后换个时机再试一次。',
          source: 'microphone',
          measuredAt: DateTime.now(),
        ),
      );
    } finally {
      _activeProbes.remove(InterferenceFactorType.noise);
    }
  }

  Future<void> _detectLight({
    required bool allowPermissionPrompt,
  }) async {
    if (!Platform.isAndroid) {
      _commitLocalFactor(
        InterferenceFactorSnapshot(
          type: InterferenceFactorType.light,
          title: '灯光环境',
          value: '暂不支持',
          gradeLabel: '暂不支持',
          status: InterferenceFactorStatus.unsupported,
          detail: '当前这项能力仅在 Android 设备上开放。',
          source: 'unsupported',
          measuredAt: DateTime.now(),
        ),
      );
      return;
    }

    final PermissionStatus permission = allowPermissionPrompt
        ? await Permission.camera.request()
        : await Permission.camera.status;
    if (!permission.isGranted) {
      _commitLocalFactor(
        InterferenceFactorSnapshot(
          type: InterferenceFactorType.light,
          title: '灯光环境',
          value: '未授权',
          gradeLabel: '未授权',
          status: InterferenceFactorStatus.denied,
          detail: '先打开相机权限，我才能帮你判断房间现在是偏暗还是偏亮。',
          source: 'camera_permission',
          measuredAt: DateTime.now(),
        ),
      );
      return;
    }

    if (_activeProbes.contains(InterferenceFactorType.light)) {
      return;
    }
    _activeProbes.add(InterferenceFactorType.light);
    _commitLocalFactor(
      _state.light.copyWith(
        status: InterferenceFactorStatus.measuring,
        value: '检测中...',
        gradeLabel: '检测中',
        detail: '小眠正在用前置摄像头看看房间亮度。',
        measuredAt: DateTime.now(),
      ),
    );

    CameraController? controller;
    try {
      final List<CameraDescription> cameras = await availableCameras();
      final CameraDescription? frontCamera = cameras.cast<CameraDescription?>()
          .firstWhere(
            (CameraDescription? item) =>
                item?.lensDirection == CameraLensDirection.front,
            orElse: () => null,
          );
      if (frontCamera == null) {
        _commitLocalFactor(
          InterferenceFactorSnapshot(
            type: InterferenceFactorType.light,
            title: '灯光环境',
            value: '没有前摄',
            gradeLabel: '不可检测',
            status: InterferenceFactorStatus.unavailable,
            detail: '没有找到可用的前置摄像头，这次先没法判断环境亮度。',
            source: 'camera',
            measuredAt: DateTime.now(),
          ),
        );
        return;
      }

      controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await controller.initialize();
      final XFile file = await controller.takePicture();
      final Uint8List bytes = await file.readAsBytes();
      final img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        throw StateError('Unable to decode image bytes.');
      }

      final double luminance = _averageLuminance(image);
      final _ProbeGrade grade = _lightGrade(luminance);
      final InterferenceFactorSnapshot factor = InterferenceFactorSnapshot(
        type: InterferenceFactorType.light,
        title: '灯光环境',
        value: grade.valueLabel,
        gradeLabel: grade.label,
        status: InterferenceFactorStatus.ready,
        detail: grade.detail,
        source: 'front_camera',
        measuredAt: DateTime.now(),
        numericValue: luminance,
        score: grade.score,
      );
      _commitLocalFactor(factor);
      await _persistFactor(factor);
      await _dormRepository.updateDormEnvironment(lightLabel: grade.valueLabel);
    } catch (_) {
      _commitLocalFactor(
        InterferenceFactorSnapshot(
          type: InterferenceFactorType.light,
          title: '灯光环境',
          value: '检测失败',
          gradeLabel: '检测失败',
          status: InterferenceFactorStatus.error,
          detail: '这次没有顺利读到亮度，稍后换个角度再试试。',
          source: 'front_camera',
          measuredAt: DateTime.now(),
        ),
      );
    } finally {
      await controller?.dispose();
      _activeProbes.remove(InterferenceFactorType.light);
    }
  }

  Future<void> _detectPhoneUsage({
    required bool allowPermissionPrompt,
  }) async {
    if (!Platform.isAndroid) {
      _commitLocalFactor(
        InterferenceFactorSnapshot(
          type: InterferenceFactorType.phoneUsage,
          title: '手机使用',
          value: '暂不支持',
          gradeLabel: '暂不支持',
          status: InterferenceFactorStatus.unsupported,
          detail: '当前这项能力仅在 Android 设备上开放。',
          source: 'unsupported',
          measuredAt: DateTime.now(),
        ),
      );
      return;
    }

    final bool granted = await _usageStatsGateway.hasPermission();
    if (!granted) {
      if (allowPermissionPrompt) {
        await _usageStatsGateway.openPermissionSettings();
      }
      _commitLocalFactor(
        InterferenceFactorSnapshot(
          type: InterferenceFactorType.phoneUsage,
          title: '手机使用',
          value: '未授权',
          gradeLabel: '未授权',
          status: InterferenceFactorStatus.denied,
          detail: '先打开“使用情况访问权限”，我才能读取最近 2 小时手机使用时长。',
          source: 'usage_stats_permission',
          measuredAt: DateTime.now(),
        ),
      );
      return;
    }

    if (_activeProbes.contains(InterferenceFactorType.phoneUsage)) {
      return;
    }
    _activeProbes.add(InterferenceFactorType.phoneUsage);
    _commitLocalFactor(
      _state.phoneUsage.copyWith(
        status: InterferenceFactorStatus.measuring,
        value: '检测中...',
        gradeLabel: '检测中',
        detail: '小眠正在读取最近 2 小时的手机使用情况。',
        measuredAt: DateTime.now(),
      ),
    );

    try {
      final int minutes = await _usageStatsGateway.readLastTwoHoursUsageMinutes();
      final _ProbeGrade grade = _phoneUsageGrade(minutes);
      final InterferenceFactorSnapshot factor = InterferenceFactorSnapshot(
        type: InterferenceFactorType.phoneUsage,
        title: '手机使用',
        value: '$minutes 分钟',
        gradeLabel: grade.label,
        status: InterferenceFactorStatus.ready,
        detail: grade.detail,
        source: 'android_usage_stats',
        measuredAt: DateTime.now(),
        numericValue: minutes.toDouble(),
        score: grade.score,
      );
      _commitLocalFactor(factor);
      await _persistFactor(factor);
    } on PlatformException {
      _commitLocalFactor(
        InterferenceFactorSnapshot(
          type: InterferenceFactorType.phoneUsage,
          title: '手机使用',
          value: '不可读取',
          gradeLabel: '不可读取',
          status: InterferenceFactorStatus.unavailable,
          detail: '系统这次没有返回可用数据，可以稍后再试一次。',
          source: 'android_usage_stats',
          measuredAt: DateTime.now(),
        ),
      );
    } catch (_) {
      _commitLocalFactor(
        InterferenceFactorSnapshot(
          type: InterferenceFactorType.phoneUsage,
          title: '手机使用',
          value: '检测失败',
          gradeLabel: '检测失败',
          status: InterferenceFactorStatus.error,
          detail: '这次没能读到最近 2 小时使用时长，稍后再试一次。',
          source: 'android_usage_stats',
          measuredAt: DateTime.now(),
        ),
      );
    } finally {
      _activeProbes.remove(InterferenceFactorType.phoneUsage);
    }
  }

  Future<void> _detectEmotion() async {
    _primeEmotionSnapshot(forceRefresh: true);
    await _persistFactor(_state.emotion);
  }

  void _primeEmotionSnapshot({bool forceRefresh = false}) {
    if (!forceRefresh &&
        _state.emotion.status != InterferenceFactorStatus.idle) {
      return;
    }
    _commitLocalFactor(_defaultEmotionSnapshot());
  }

  void _commitLocalFactor(InterferenceFactorSnapshot factor) {
    _state = _state.replaceFactor(factor).copyWith(updatedAt: DateTime.now());
    notifyListeners();
  }

  Future<void> _persistFactor(InterferenceFactorSnapshot factor) async {
    final CloudBaseAppApiClient? client = _appApiClient;
    if (!usesCloudBasePersistence || client == null) {
      return;
    }
    try {
      await _authRepository.ensureAuthenticated();
      await client.post(
        '/api/interference/tonight',
        body: <String, dynamic>{
          _factorKey(factor.type): ModelSerializers.interferenceFactorSnapshotToMap(
            factor,
          ),
        },
      );
      await client.post(
        '/api/cards/refresh',
        body: <String, dynamic>{
          'surfaces': <String>[BackendSurfaceIds.homePreSleep],
        },
      );
      await _snapshotStore?.refresh();
    } catch (_) {
      // Keep the local result even if remote sync fails.
    }
  }

  String _factorKey(InterferenceFactorType type) {
    return switch (type) {
      InterferenceFactorType.noise => 'noise',
      InterferenceFactorType.light => 'light',
      InterferenceFactorType.phoneUsage => 'phoneUsage',
      InterferenceFactorType.emotion => 'emotion',
    };
  }

  double _averageLuminance(img.Image image) {
    double total = 0;
    int count = 0;
    final int stepX = (image.width / 24).clamp(1, image.width).round();
    final int stepY = (image.height / 24).clamp(1, image.height).round();
    for (int y = 0; y < image.height; y += stepY) {
      for (int x = 0; x < image.width; x += stepX) {
        final img.Pixel pixel = image.getPixel(x, y);
        total +=
            (0.2126 * pixel.r) + (0.7152 * pixel.g) + (0.0722 * pixel.b);
        count += 1;
      }
    }
    return count == 0 ? 0 : total / count;
  }

  static TonightInterferenceState _buildFallbackState(Dorm dorm) {
    return TonightInterferenceState(
      noise: _defaultNoiseSnapshot(dorm),
      light: _defaultLightSnapshot(dorm),
      phoneUsage: const InterferenceFactorSnapshot(
        type: InterferenceFactorType.phoneUsage,
        title: '手机使用',
        value: '待检测',
        gradeLabel: '待检测',
        status: InterferenceFactorStatus.idle,
        detail: '授权后可读取最近 2 小时手机使用时长。',
        source: 'android_usage_stats',
      ),
      emotion: _defaultEmotionSnapshot(),
      updatedAt: DateTime.now(),
    );
  }

  static InterferenceFactorSnapshot _defaultNoiseSnapshot(Dorm dorm) {
    final _ProbeGrade grade = _noiseGrade(dorm.noiseDb.toDouble());
    return InterferenceFactorSnapshot(
      type: InterferenceFactorType.noise,
      title: '宿舍噪声',
      value: '${dorm.noiseDb} dB',
      gradeLabel: grade.label,
      status: InterferenceFactorStatus.ready,
      detail: grade.detail,
      source: 'dorm_state',
      numericValue: dorm.noiseDb.toDouble(),
      score: grade.score,
    );
  }

  static InterferenceFactorSnapshot _defaultLightSnapshot(Dorm dorm) {
    final _ProbeGrade grade = _lightGradeFromLabel(dorm.lightLabel);
    return InterferenceFactorSnapshot(
      type: InterferenceFactorType.light,
      title: '灯光环境',
      value: dorm.lightLabel,
      gradeLabel: grade.label,
      status: InterferenceFactorStatus.ready,
      detail: grade.detail,
      source: 'dorm_state',
      score: grade.score,
    );
  }

  static InterferenceFactorSnapshot _defaultEmotionSnapshot() {
    return const InterferenceFactorSnapshot(
      type: InterferenceFactorType.emotion,
      title: '情绪压力',
      value: '偏低',
      gradeLabel: '偏低',
      status: InterferenceFactorStatus.ready,
      detail: '今晚先按较低压力处理，先让身体慢下来；后续我们再补更完整的情绪判断逻辑。',
      source: 'static_v1',
      numericValue: 20,
      score: 20,
    );
  }

  static _ProbeGrade _noiseGrade(double value) {
    if (value <= 35) {
      return const _ProbeGrade(
        label: '安静',
        valueLabel: '安静',
        detail: '环境声比较轻，已经是适合慢慢放松和准备入睡的状态。',
        score: 18,
      );
    }
    if (value <= 50) {
      return const _ProbeGrade(
        label: '轻微',
        valueLabel: '轻微',
        detail: '有一点生活声，但整体还在可接受范围内。',
        score: 36,
      );
    }
    if (value <= 65) {
      return const _ProbeGrade(
        label: '偏吵',
        valueLabel: '偏吵',
        detail: '声音已经开始打断身体放松的节奏，可以先做一点降噪处理。',
        score: 68,
      );
    }
    return const _ProbeGrade(
      label: '较吵',
      valueLabel: '较吵',
      detail: '当前噪声偏高，容易让大脑持续保持警觉。',
      score: 88,
    );
  }

  static _ProbeGrade _lightGrade(double brightness) {
    if (brightness <= 45) {
      return const _ProbeGrade(
        label: '偏暗',
        valueLabel: '偏暗',
        detail: '环境亮度较低，更适合身体慢慢进入休息节奏。',
        score: 16,
      );
    }
    if (brightness <= 110) {
      return const _ProbeGrade(
        label: '适中',
        valueLabel: '适中',
        detail: '亮度还算平稳，继续保持会更舒服。',
        score: 28,
      );
    }
    if (brightness <= 180) {
      return const _ProbeGrade(
        label: '偏亮',
        valueLabel: '偏亮',
        detail: '光线有点亮，建议只保留局部照明或者再调暗一点。',
        score: 62,
      );
    }
    return const _ProbeGrade(
      label: '过亮',
      valueLabel: '过亮',
      detail: '环境光刺激偏强，可能会拖慢入睡速度。',
      score: 84,
    );
  }

  static _ProbeGrade _lightGradeFromLabel(String label) {
    return switch (label) {
      '偏暗' => const _ProbeGrade(
        label: '偏暗',
        valueLabel: '偏暗',
        detail: '当前光线比较柔和，适合慢慢进入休息状态。',
        score: 16,
      ),
      '适中' => const _ProbeGrade(
        label: '适中',
        valueLabel: '适中',
        detail: '当前亮度比较平稳，没有明显刺眼感。',
        score: 28,
      ),
      '偏亮' => const _ProbeGrade(
        label: '偏亮',
        valueLabel: '偏亮',
        detail: '环境略亮，建议尽量减少正对眼睛的光线。',
        score: 62,
      ),
      '过亮' => const _ProbeGrade(
        label: '过亮',
        valueLabel: '过亮',
        detail: '亮度偏高，可能会拖慢身体放松。',
        score: 84,
      ),
      _ => const _ProbeGrade(
        label: '待检测',
        valueLabel: '待检测',
        detail: '点一下就能用前摄检测当前环境亮度。',
        score: 28,
      ),
    };
  }

  static _ProbeGrade _phoneUsageGrade(int minutes) {
    if (minutes <= 20) {
      return const _ProbeGrade(
        label: '很少',
        valueLabel: '很少',
        detail: '最近 2 小时手机使用很少，屏幕刺激对今晚影响较低。',
        score: 14,
      );
    }
    if (minutes <= 50) {
      return const _ProbeGrade(
        label: '适中',
        valueLabel: '适中',
        detail: '最近 2 小时手机使用还算克制，再往下收一收会更稳一点。',
        score: 34,
      );
    }
    if (minutes <= 90) {
      return const _ProbeGrade(
        label: '偏多',
        valueLabel: '偏多',
        detail: '最近 2 小时手机使用有点久，可能会拖慢睡意。',
        score: 62,
      );
    }
    return const _ProbeGrade(
      label: '过长',
      valueLabel: '过长',
      detail: '屏幕使用时间偏长，先离开手机一会儿，会更容易慢下来。',
      score: 86,
    );
  }

  @override
  void dispose() {
    _dormRepository.removeListener(_syncDormFallbacks);
    _snapshotStore?.removeListener(_hydrateFromSnapshot);
    super.dispose();
  }
}

class AndroidUsageStatsGateway {
  const AndroidUsageStatsGateway();

  static const MethodChannel _channel = MethodChannel(
    'com.dormsleep.app/usage_stats',
  );

  Future<bool> hasPermission() async {
    final bool? granted = await _channel.invokeMethod<bool>('hasPermission');
    return granted ?? false;
  }

  Future<void> openPermissionSettings() async {
    await _channel.invokeMethod<void>('openPermissionSettings');
  }

  Future<int> readLastTwoHoursUsageMinutes() async {
    final int? minutes = await _channel.invokeMethod<int>(
      'getLastTwoHoursUsageMinutes',
    );
    return minutes ?? 0;
  }
}

class _ProbeGrade {
  const _ProbeGrade({
    required this.label,
    required this.valueLabel,
    required this.detail,
    required this.score,
  });

  final String label;
  final String valueLabel;
  final String detail;
  final int score;
}
