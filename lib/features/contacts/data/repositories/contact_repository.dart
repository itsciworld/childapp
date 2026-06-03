import 'package:dio/dio.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/device_storage.dart';
import '../models/contact_item.dart';
import '../models/store_contacts_response.dart';

/// Owns all contact data access: reading contacts from the device address book
/// and uploading them to the backend. The UI / background loop never talks to
/// the `flutter_contacts` plugin or Dio directly — it goes through this
/// repository.
class ContactRepository {
  ContactRepository(this._dio, this._deviceStorage);

  final Dio _dio;
  final DeviceStorage _deviceStorage;

  /// Reads device contacts and maps them into upload-ready [ContactItem]s
  /// tagged with [childId] / [parentId], one per phone number.
  ///
  /// Contacts have no reliable timestamp, so incremental sync is keyed on the
  /// phone number instead of a time watermark: any number already in
  /// [alreadySynced] is skipped, so only newly-added numbers are returned.
  /// Returns an empty list when there is nothing new. Assumes the
  /// `READ_CONTACTS` permission has already been granted.
  Future<List<ContactItem>> readDeviceContacts({
    required String childId,
    required String parentId,
    required Set<String> alreadySynced,
  }) async {
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );

    final items = <ContactItem>[];
    final seenThisPass = <String>{};
    for (final contact in contacts) {
      for (final phone in contact.phones) {
        final number = phone.number.trim();
        if (number.isEmpty) continue;
        // Skip numbers already uploaded, and de-dupe within this pass.
        if (alreadySynced.contains(number)) continue;
        if (!seenThisPass.add(number)) continue;
        items.add(
          ContactItem(
            name: contact.displayName ?? '',
            phone: number,
            childId: childId,
            parentId: parentId,
          ),
        );
      }
    }
    return items;
  }

  /// Uploads [contacts] to `POST /api/contacts/store_contacts`.
  ///
  /// The backend-issued device key (stored at pairing) is sent in the
  /// `x-device-key` header so the server can authorise this paired device.
  ///
  /// Throws [ApiException] on any network / server failure.
  Future<StoreContactsResponse> storeContacts(List<ContactItem> contacts) async {
    try {
      final deviceKey = await _deviceStorage.getDeviceKey();
      final response = await _dio.post<dynamic>(
        '/api/contacts/store_contacts',
        data: {'contacts': contacts.map((e) => e.toJson()).toList()},
        options: Options(
          // This endpoint is slow (server dedupes each contact), so override the
          // default 35s receive timeout for just this request.
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout: const Duration(seconds: 90),
          headers: {
            if (deviceKey != null && deviceKey.isNotEmpty)
              'x-device-key': deviceKey,
          },
        ),
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Unexpected response from the server.');
      }
      return StoreContactsResponse.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }
}

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository(
    ref.watch(dioProvider),
    ref.watch(deviceStorageProvider),
  );
});
