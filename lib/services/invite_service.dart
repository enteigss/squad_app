import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/colors.dart';

class InviteService {
  static const String _functionsBaseUrl =
      'https://us-central1-squad-7bc7e.cloudfunctions.net';

  // Track loading dialog state
  static bool _isLoadingDialogShowing = false;

  // Request contacts permission
  static Future<bool> requestContactsPermission() async {
    print(
      'DEBUG: InviteService.requestContactsPermission() - Starting permission request',
    );
    try {
      // Check current permission status using permission_handler
      final permissionHandlerStatus = await Permission.contacts.status;
      print(
        'DEBUG: InviteService.requestContactsPermission() - permission_handler status: $permissionHandlerStatus',
      );

      // Check current permission status using flutter_contacts
      final flutterContactsStatus = await FlutterContacts.requestPermission(
        readonly: true,
      );
      print(
        'DEBUG: InviteService.requestContactsPermission() - flutter_contacts readonly status: $flutterContactsStatus',
      );

      // If permission_handler shows granted, try flutter_contacts directly
      if (permissionHandlerStatus.isGranted) {
        print(
          'DEBUG: InviteService.requestContactsPermission() - permission_handler shows granted, testing flutter_contacts',
        );
        return true;
      }

      // If permission is permanently denied, try using permission_handler to request
      if (permissionHandlerStatus.isPermanentlyDenied) {
        print(
          'DEBUG: InviteService.requestContactsPermission() - Permission permanently denied, trying permission_handler request',
        );
        final permissionHandlerResult = await Permission.contacts.request();
        print(
          'DEBUG: InviteService.requestContactsPermission() - permission_handler request result: $permissionHandlerResult',
        );
        return permissionHandlerResult.isGranted;
      }

      // If permission is denied, try using permission_handler first
      if (permissionHandlerStatus.isDenied) {
        print(
          'DEBUG: InviteService.requestContactsPermission() - Permission denied, trying permission_handler request first',
        );
        final permissionHandlerResult = await Permission.contacts.request();
        print(
          'DEBUG: InviteService.requestContactsPermission() - permission_handler request result: $permissionHandlerResult',
        );
        if (permissionHandlerResult.isGranted) {
          return true;
        }
      }

      // Try flutter_contacts permission request
      print(
        'DEBUG: InviteService.requestContactsPermission() - Requesting permission via flutter_contacts',
      );
      final result = await FlutterContacts.requestPermission().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print(
            'DEBUG: InviteService.requestContactsPermission() - Permission request timed out after 15 seconds',
          );
          throw Exception('Permission request timed out after 15 seconds');
        },
      );
      print(
        'DEBUG: InviteService.requestContactsPermission() - flutter_contacts permission request completed: $result',
      );

      // Double-check with permission_handler after flutter_contacts request
      final finalPermissionHandlerStatus = await Permission.contacts.status;
      print(
        'DEBUG: InviteService.requestContactsPermission() - Final permission_handler status: $finalPermissionHandlerStatus',
      );

      return result;
    } catch (e) {
      print('DEBUG: InviteService.requestContactsPermission() - Exception: $e');
      rethrow;
    }
  }

  // Get contacts from device
  static Future<List<Contact>> getContacts() async {
    print('DEBUG: InviteService.getContacts() - Starting contact loading');
    try {
      print(
        'DEBUG: InviteService.getContacts() - Requesting contacts permission',
      );
      final hasPermission = await requestContactsPermission();
      print(
        'DEBUG: InviteService.getContacts() - Permission result: $hasPermission',
      );

      if (!hasPermission) {
        print(
          'DEBUG: InviteService.getContacts() - Permission denied, throwing exception',
        );
        throw Exception('Contacts permission denied');
      }

      print(
        'DEBUG: InviteService.getContacts() - Starting FlutterContacts.getContacts()',
      );

      // Simple contact loading - no batching complexity
      final contacts =
          await FlutterContacts.getContacts(
            withProperties: true,
            withPhoto: false,
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print(
                'DEBUG: InviteService.getContacts() - Contact loading timed out after 30 seconds',
              );
              throw Exception('Contact loading timed out after 30 seconds');
            },
          );

      print(
        'DEBUG: InviteService.getContacts() - Raw contacts loaded: ${contacts.length}',
      );

      // Filter contacts that have phone numbers
      final filteredContacts = contacts
          .where(
            (contact) =>
                contact.phones.isNotEmpty && contact.displayName.isNotEmpty,
          )
          .toList();

      print(
        'DEBUG: InviteService.getContacts() - Filtered contacts: ${filteredContacts.length}',
      );
      print(
        'DEBUG: InviteService.getContacts() - Contact loading completed successfully',
      );

      return filteredContacts;
    } catch (e) {
      print('DEBUG: InviteService.getContacts() - Exception caught: $e');
      throw Exception('Failed to load contacts: $e');
    }
  }

  // Send SMS invites via Cloud Function
  static Future<SMSInviteResult> sendSMSInvites({
    required String hangoutId,
    required List<String> phoneNumbers,
    required String inviterName,
  }) async {
    print('🚀 DEBUG: sendSMSInvites() - Starting SMS invite process');
    print('📋 DEBUG: sendSMSInvites() - hangoutId: $hangoutId');
    print('📋 DEBUG: sendSMSInvites() - phoneNumbers: $phoneNumbers');
    print('📋 DEBUG: sendSMSInvites() - inviterName: $inviterName');

    try {
      final user = FirebaseAuth.instance.currentUser;
      print('👤 DEBUG: sendSMSInvites() - Checking user authentication');

      if (user == null) {
        print('❌ DEBUG: sendSMSInvites() - User not authenticated');
        throw Exception('User not authenticated');
      }

      print('✅ DEBUG: sendSMSInvites() - User authenticated: ${user.uid}');

      // Get ID token for authentication
      print('🔐 DEBUG: sendSMSInvites() - Getting ID token');
      final idToken = await user.getIdToken();
      print('✅ DEBUG: sendSMSInvites() - ID token obtained');

      final requestBody = {
        'data': {
          'hangoutId': hangoutId,
          'phoneNumbers': phoneNumbers,
          'inviterName': inviterName,
          'inviterId': user.uid,
        },
      };

      print('📤 DEBUG: sendSMSInvites() - Preparing HTTP request');
      print(
        '🌐 DEBUG: sendSMSInvites() - URL: $_functionsBaseUrl/sendSMSInvite',
      );
      print(
        '📋 DEBUG: sendSMSInvites() - Request body: ${jsonEncode(requestBody)}',
      );

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/sendSMSInvite'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(requestBody),
      );

      print('📥 DEBUG: sendSMSInvites() - HTTP response received');
      print('📊 DEBUG: sendSMSInvites() - Status code: ${response.statusCode}');
      print('📋 DEBUG: sendSMSInvites() - Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ DEBUG: sendSMSInvites() - Success response, parsing data');
        final data = jsonDecode(response.body);
        print('📋 DEBUG: sendSMSInvites() - Parsed response data: $data');

        final result = SMSInviteResult.fromJson(data['result']);
        print(
          '✅ DEBUG: sendSMSInvites() - SMS invite process completed successfully',
        );
        print(
          '📊 DEBUG: sendSMSInvites() - Result: ${result.success ? "SUCCESS" : "FAILED"}',
        );
        print(
          '📊 DEBUG: sendSMSInvites() - Successful: ${result.successfulInvites}, Failed: ${result.failedInvites}',
        );

        return result;
      } else {
        print('❌ DEBUG: sendSMSInvites() - HTTP error: ${response.statusCode}');
        print(
          '📋 DEBUG: sendSMSInvites() - Error response body: ${response.body}',
        );
        throw Exception(
          'Failed to send invites: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('💥 DEBUG: sendSMSInvites() - Exception caught: $e');
      print('📍 DEBUG: sendSMSInvites() - Exception type: ${e.runtimeType}');
      throw Exception('Error sending SMS invites: $e');
    }
  }

  // Show loading dialog using root navigator
  static void _showLoadingDialog(BuildContext context) {
    if (_isLoadingDialogShowing) {
      print(
        'DEBUG: InviteService._showLoadingDialog() - Loading dialog already showing, skipping',
      );
      return;
    }

    print(
      'DEBUG: InviteService._showLoadingDialog() - Showing loading dialog with root navigator',
    );
    _isLoadingDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true, // Key change: use root navigator
      builder: (context) => PopScope(
        canPop: false,
        child: const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('Loading contacts...'),
            ],
          ),
        ),
      ),
    );
  }

  // Dismiss loading dialog using root navigator
  static void _dismissLoadingDialog(BuildContext context) {
    if (!_isLoadingDialogShowing) {
      print(
        'DEBUG: InviteService._dismissLoadingDialog() - No loading dialog to dismiss',
      );
      return;
    }

    try {
      print(
        'DEBUG: InviteService._dismissLoadingDialog() - Attempting to dismiss loading dialog with root navigator',
      );
      Navigator.of(context, rootNavigator: true).pop();
      print(
        'DEBUG: InviteService._dismissLoadingDialog() - Loading dialog dismissed successfully',
      );
      _isLoadingDialogShowing = false;
    } catch (e) {
      print(
        'DEBUG: InviteService._dismissLoadingDialog() - Error dismissing loading dialog: $e',
      );
      _isLoadingDialogShowing = false; // Reset state even on error
    }
  }

  // Show contact picker dialog - simplified without loading dialog
  static Future<List<Contact>?> showContactPicker(BuildContext context) async {
    print(
      'DEBUG: InviteService.showContactPicker() - Starting contact picker (no loading dialog)',
    );

    try {
      print('DEBUG: InviteService.showContactPicker() - Calling getContacts()');
      final contacts = await getContacts().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print(
            'DEBUG: InviteService.showContactPicker() - Contact loading timed out',
          );
          throw Exception('Contact loading timed out after 30 seconds');
        },
      );
      print(
        'DEBUG: InviteService.showContactPicker() - getContacts() completed with ${contacts.length} contacts',
      );

      print(
        'DEBUG: InviteService.showContactPicker() - Attempting to show contact picker dialog',
      );

      // Try to show the dialog with the original context first
      try {
        return await showDialog<List<Contact>>(
          context: context,
          builder: (context) => ContactPickerDialog(contacts: contacts),
        );
      } catch (e) {
        print(
          'DEBUG: InviteService.showContactPicker() - Failed with original context: $e',
        );

        // If that fails, try to get the current navigator context
        try {
          print(
            'DEBUG: InviteService.showContactPicker() - Trying with current navigator context',
          );
          final navigatorContext = Navigator.of(
            context,
            rootNavigator: true,
          ).context;
          return await showDialog<List<Contact>>(
            context: navigatorContext,
            builder: (context) => ContactPickerDialog(contacts: contacts),
          );
        } catch (e2) {
          print(
            'DEBUG: InviteService.showContactPicker() - Failed with navigator context: $e2',
          );

          // Last resort: try to find any valid context in the app
          try {
            print(
              'DEBUG: InviteService.showContactPicker() - Trying with any available context',
            );
            // This will attempt to use any available context
            return await showDialog<List<Contact>>(
              context: context,
              useRootNavigator: true,
              builder: (context) => ContactPickerDialog(contacts: contacts),
            );
          } catch (e3) {
            print(
              'DEBUG: InviteService.showContactPicker() - All context methods failed: $e3',
            );
            // Only now do we give up and show an error
            throw Exception(
              'Could not show contact picker - all context methods failed',
            );
          }
        }
      }
    } catch (e) {
      print('DEBUG: InviteService.showContactPicker() - Exception caught: $e');

      if (context.mounted) {
        print(
          'DEBUG: InviteService.showContactPicker() - Showing error snackbar',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading contacts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        print(
          'DEBUG: InviteService.showContactPicker() - Context not mounted, cannot show snackbar',
        );
      }

      return null;
    }
  }
}

class SMSInviteResult {
  final bool success;
  final int successfulInvites;
  final int failedInvites;
  final List<String> errors;

  SMSInviteResult({
    required this.success,
    required this.successfulInvites,
    required this.failedInvites,
    required this.errors,
  });

  factory SMSInviteResult.fromJson(Map<String, dynamic> json) {
    return SMSInviteResult(
      success: json['success'] ?? false,
      successfulInvites: json['successfulInvites'] ?? 0,
      failedInvites: json['failedInvites'] ?? 0,
      errors: List<String>.from(json['errors'] ?? []),
    );
  }
}

class ContactPickerDialog extends StatefulWidget {
  final List<Contact> contacts;

  const ContactPickerDialog({super.key, required this.contacts});

  @override
  State<ContactPickerDialog> createState() => _ContactPickerDialogState();
}

class _ContactPickerDialogState extends State<ContactPickerDialog> {
  final Set<Contact> selectedContacts = {};
  String searchQuery = '';

  List<Contact> get filteredContacts {
    if (searchQuery.isEmpty) return widget.contacts;

    return widget.contacts.where((contact) {
      final name = contact.displayName.toLowerCase();
      final phone = contact.phones.isNotEmpty
          ? contact.phones.first.number
          : '';
      final query = searchQuery.toLowerCase();

      return name.contains(query) || phone.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Select Contacts',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  TextButton(
                    onPressed: selectedContacts.isEmpty
                        ? null
                        : () => Navigator.of(
                            context,
                          ).pop(selectedContacts.toList()),
                    child: Text(
                      'Send (${selectedContacts.length})',
                      style: TextStyle(
                        color: selectedContacts.isEmpty
                            ? Colors.white54
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) => setState(() => searchQuery = value),
              ),
            ),

            // Contacts list
            Expanded(
              child: ListView.builder(
                itemCount: filteredContacts.length,
                itemBuilder: (context, index) {
                  final contact = filteredContacts[index];
                  final isSelected = selectedContacts.contains(contact);
                  final phoneNumber = contact.phones.isNotEmpty
                      ? contact.phones.first.number
                      : '';

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        contact.displayName.isNotEmpty
                            ? contact.displayName[0].toUpperCase()
                            : '?',
                      ),
                    ),
                    title: Text(
                      contact.displayName.isNotEmpty
                          ? contact.displayName
                          : 'Unknown',
                    ),
                    subtitle: Text(phoneNumber),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            selectedContacts.add(contact);
                          } else {
                            selectedContacts.remove(contact);
                          }
                        });
                      },
                    ),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedContacts.remove(contact);
                        } else {
                          selectedContacts.add(contact);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
