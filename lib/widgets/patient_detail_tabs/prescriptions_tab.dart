import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../../data/models/patient_model.dart';
import '../../data/models/prescription_model.dart';
import '../../core/config/api_constants.dart';
import '../../providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrescriptionsTab extends ConsumerWidget {
  final PatientModel patient;

  const PrescriptionsTab({super.key, required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prescriptions = _parsePrescriptions();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF15151C) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.medication_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Ordonnances',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (prescriptions.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.medication_liquid_rounded,
                            size: 48,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune ordonnance trouvée',
                            style: TextStyle(
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...prescriptions.map((prescription) => _buildPrescriptionCard(
                        context,
                        ref,
                        prescription,
                        isDark,
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PrescriptionModel> _parsePrescriptions() {
    if (patient.medicalRecords == null) return [];
    final prescriptions = <PrescriptionModel>[];
    for (final record in patient.medicalRecords!) {
      if (record is Map<String, dynamic> &&
          record.containsKey('prescriptions')) {
        final prescList = record['prescriptions'] as List<dynamic>?;
        if (prescList != null) {
          for (final presc in prescList) {
            if (presc is Map<String, dynamic>) {
              prescriptions.add(PrescriptionModel.fromJson(presc));
            }
          }
        }
      }
    }
    return prescriptions;
  }

  Widget _buildPrescriptionCard(
    BuildContext context,
    WidgetRef ref,
    PrescriptionModel prescription,
    bool isDark,
  ) {
    final dateLabel = prescription.createdAt != null
        ? DateFormat('dd MMM yyyy', 'fr_FR').format(prescription.createdAt!)
        : 'Date inconnue';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F25) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ordonnance #${prescription.id ?? '—'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Émise le $dateLabel',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (prescription.pdfPath != null)
                IconButton(
                  icon: const Icon(Icons.download_rounded),
                  onPressed: () => _downloadPrescriptionPdf(
                      context, ref, prescription.pdfPath!, prescription.id),
                  tooltip: 'Télécharger le PDF',
                ),
            ],
          ),
          if (prescription.medications != null &&
              prescription.medications!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Médicaments:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
            const SizedBox(height: 8),
            ...prescription.medications!.map((med) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.medication_liquid_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              med.medicationName ?? 'Médicament',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.grey[900],
                              ),
                            ),
                            if (med.dosage != null || med.frequency != null)
                              Text(
                                '${med.dosage ?? ''} ${med.frequency ?? ''}'
                                    .trim(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          if (prescription.notes != null && prescription.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.3) : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note_rounded,
                    size: 16,
                    color: isDark ? Colors.grey[400] : Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      prescription.notes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[300] : Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _downloadPrescriptionPdf(BuildContext context, WidgetRef ref,
      String pdfPath, int? prescriptionId) async {
    String? url;

    // Check if pdfPath is already a full URL
    if (pdfPath.startsWith('http://') || pdfPath.startsWith('https://')) {
      url = pdfPath;
    } else {
      // Remove leading slash if present to avoid double slashes
      final cleanPath =
          pdfPath.startsWith('/') ? pdfPath.substring(1) : pdfPath;
      url = '${ApiConstants.storageBaseUrl}/storage/$cleanPath';
    }

    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL du PDF non disponible')),
      );
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );

      final uri = Uri.parse(url);

      // Get auth token if available
      final authState = ref.read(authProvider);
      final headers = <String, String>{};
      if (authState.token != null) {
        headers['Authorization'] = 'Bearer ${authState.token}';
      }

      // Download the file
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        // Get file name from URL or use prescription ID
        String fileName =
            'ordonnance_${prescriptionId ?? DateTime.now().millisecondsSinceEpoch}.pdf';
        final urlPath = uri.path;
        if (urlPath.isNotEmpty) {
          final urlFileName = urlPath.split('/').last;
          if (urlFileName.isNotEmpty && urlFileName.endsWith('.pdf')) {
            fileName = urlFileName;
          }
        }

        if (kIsWeb) {
          // For web, trigger browser download
          final blob = response.bodyBytes;
          final blobUrl = Uri.dataFromBytes(blob, mimeType: 'application/pdf');
          await launchUrl(blobUrl, mode: LaunchMode.platformDefault);

          if (context.mounted) {
            Navigator.of(context).pop(); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF téléchargé: $fileName'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          // For mobile, save to Downloads directory
          Directory? directory;
          try {
            if (Platform.isAndroid) {
              // For Android, use external storage downloads directory
              directory = Directory('/storage/emulated/0/Download');
              if (!await directory.exists()) {
                // Fallback to app documents directory
                directory = await getApplicationDocumentsDirectory();
              }
            } else if (Platform.isIOS) {
              // For iOS, use app documents directory
              directory = await getApplicationDocumentsDirectory();
            } else {
              // For other platforms
              directory = await getApplicationDocumentsDirectory();
            }
          } catch (e) {
            // Fallback to app documents directory
            directory = await getApplicationDocumentsDirectory();
          }

          final filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          if (context.mounted) {
            Navigator.of(context).pop(); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF téléchargé: $fileName'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Erreur lors du téléchargement: ${response.statusCode}'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du téléchargement: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
