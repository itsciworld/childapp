import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../models/battery_info.dart';
import '../models/connectivity_info.dart';
import '../models/live_status_request.dart';
import '../models/live_status_response.dart';
import '../models/wifi_info.dart';

/// Owns all live-status data access: reading the current battery + connectivity
/// snapshot from the device and pushing it to the backend. The UI / background
/// loop never touches the platform plugins or Dio directly — it goes through
/// this repository.
class LiveStatusRepository {
  LiveStatusRepository(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  final NetworkInfo _networkInfo = NetworkInfo();

  // TEMPORARY: live status points at a separate backend for now. Passing an
  // absolute URL makes Dio ignore the shared `baseUrl` for just this call —
  // remove this once live status moves to the main API. // TODO(live-status-url)
  static const String _tempBaseUrl = 'http://160.153.179.249:3000';

  /// Reads the device's *current* battery and connectivity state into an
  /// upload-ready [LiveStatusRequest]. Unlike SMS / call logs this is a live
  /// snapshot — there is no incremental watermark; each pass sends "now".
  Future<LiveStatusRequest> readDeviceStatus() async {
    final battery = await _readBattery();
    final connectivity = await _readConnectivity();
    return LiveStatusRequest(
      isOnline: connectivity.isConnected,
      batteryInfo: battery,
      connectivity: connectivity,
    );
  }

  Future<BatteryInfo> _readBattery() async {
    // Each getter can throw on platforms that don't support it; fall back to
    // safe defaults so a single unsupported field never fails the whole push.
    int level;
    try {
      level = await _battery.batteryLevel;
    } catch (_) {
      level = -1;
    }

    String state;
    try {
      state = (await _battery.batteryState).name;
    } catch (_) {
      state = 'unknown';
    }

    bool saveMode;
    try {
      saveMode = await _battery.isInBatterySaveMode;
    } catch (_) {
      saveMode = false;
    }

    // temperature / voltage are not exposed by battery_plus on either platform,
    // so they stay null unless a native channel is added later.
    return BatteryInfo(
      level: level,
      state: state,
      isInBatterySaveMode: saveMode,
    );
  }

  Future<ConnectivityInfo> _readConnectivity() async {
    List<ConnectivityResult> results;
    try {
      results = await _connectivity.checkConnectivity();
    } catch (_) {
      results = const [ConnectivityResult.none];
    }

    bool has(ConnectivityResult r) => results.contains(r);
    final hasWifi = has(ConnectivityResult.wifi);
    final isConnected = results.any((r) => r != ConnectivityResult.none);

    // Only the active transports, as labels — drop the `none` sentinel.
    final connectionType = results
        .where((r) => r != ConnectivityResult.none)
        .map((r) => r.name)
        .toList();

    return ConnectivityInfo(
      connectionType: connectionType,
      isConnected: isConnected,
      hasWifi: hasWifi,
      hasMobile: has(ConnectivityResult.mobile),
      hasEthernet: has(ConnectivityResult.ethernet),
      hasBluetooth: has(ConnectivityResult.bluetooth),
      hasVpn: has(ConnectivityResult.vpn),
      wifiInfo: hasWifi ? await _readWifiInfo() : null,
    );
  }

  Future<WifiInfo> _readWifiInfo() async {
    // SSID / BSSID need location permission + location services ON on Android;
    // any of these may legitimately return null. linkSpeed isn't exposed by the
    // plugin, so it stays null.
    String? ssid;
    String? bssid;
    String? ip;
    try {
      ssid = _cleanSsid(await _networkInfo.getWifiName());
    } catch (_) {/* ignore */}
    try {
      bssid = await _networkInfo.getWifiBSSID();
    } catch (_) {/* ignore */}
    try {
      ip = await _networkInfo.getWifiIP();
    } catch (_) {/* ignore */}

    return WifiInfo(ssid: ssid, bssid: bssid, ipAddress: ip);
  }

  /// Android wraps the SSID in quotes (`"Home_Wifi"`) — strip them.
  String? _cleanSsid(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
      return raw.substring(1, raw.length - 1);
    }
    return raw;
  }

  /// Pushes [request] to `PUT /api/children/$childId/live-status`.
  ///
  /// The child auth token is sent in the `x-auth-token` header (the device key
  /// is also attached automatically by the Dio interceptor).
  ///
  /// Throws [ApiException] on any network / server failure.
  Future<LiveStatusResponse> pushLiveStatus({
    required String childId,
    required LiveStatusRequest request,
  }) async {
    try {
      final token = await _tokenStorage.getToken();
      final response = await _dio.put<dynamic>(
        // Absolute URL → overrides the shared baseUrl for live status only.
        '$_tempBaseUrl/api/children/$childId/live-status',
        data: request.toJson(),
        options: Options(
          headers: {
            if (token != null && token.isNotEmpty) 'x-auth-token': token,
          },
        ),
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        // The endpoint may legitimately return an empty/non-JSON 200 body.
        return const LiveStatusResponse(status: 200);
      }
      return LiveStatusResponse.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }
}

final liveStatusRepositoryProvider = Provider<LiveStatusRepository>((ref) {
  return LiveStatusRepository(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
});
