// lib/screens/attach_file_to_record_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/models/patient_model.dart';
import '../data/models/medical_record_model.dart';
import '../providers/patient_providers.dart';
import '../providers/medical_record_providers.dart';
import '../core/utils/result.dart';
import '../widgets/loading_widget.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'patient_detail_screen.dart';
import 'medical_record_detail_screen.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_providers.dart';

enum AttachFileStep {
  selectPatient,
  selectRecord,
  uploadFiles,
}

class _SelectedFile {
  final File? file;
  final Uint8List? fileBytes;
  final String fileName;
  final int fileSize;

  _SelectedFile({
    this.file,
    this.fileBytes,
    required this.fileName,
    required this.fileSize,
  });
}

class AttachFileToRecordScreen extends ConsumerStatefulWidget {
  const AttachFileToRecordScreen({super.key});

  @override
  ConsumerState<AttachFileToRecordScreen> createState() =>
      _AttachFileToRecordScreenState();
}

class _AttachFileToRecordScreenState
    extends ConsumerState<AttachFileToRecordScreen> {
  AttachFileStep _currentStep = AttachFileStep.selectPatient;

  // Step 1: Patient selection
  final _patientSearchController = TextEditingController();
  PatientModel? _selectedPatient;
  String _patientSearchQuery = '';

  // Step 2: Medical record selection
  MedicalRecordModel? _selectedRecord;
  int? _selectedPatientId;

  // Step 3: File upload
  List<_SelectedFile> _selectedFiles = [];
  bool _isUploading = false;

  @override
  void dispose() {
    _patientSearchController.dispose();
    super.dispose();
  }

  void _handlePatientSearch(String query) {
    setState(() {
      _patientSearchQuery = query;
    });
  }

  void _handlePatientSelect(PatientModel patient) {
    if (patient.id == null) return;

    setState(() {
      _selectedPatient = patient;
      _patientSearchController.clear();
      _patientSearchQuery = '';
      _selectedRecord = null;
      _selectedFiles = [];
    });

    _loadMedicalRecords(patient.id!);
  }

  Widget _buildPatientSearchResults(BuildContext context, bool isDark) {
    // Only search if query is at least 2 characters
    if (_patientSearchQuery.length < 2) {
      return const SizedBox.shrink();
    }

    final searchAsync = ref.watch(findPatientsProvider(_patientSearchQuery));

    return searchAsync.when(
      data: (result) {
        if (result is Success<List<PatientModel>>) {
          final patients = result.data;
          if (patients.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations?.noPatientsFound ?? 'No patients found',
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                      ),
                    );
                  },
                ),
              ),
            );
          }
          return SizedBox(
            height: 300,
            child: ListView.builder(
              itemCount: patients.length,
              itemBuilder: (context, index) {
                final patient = patients[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Icon(Icons.person, color: Colors.blue.shade600),
                    ),
                    title: Text(
                      patient.user?.name ?? 'Patient #${patient.id}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: patient.cniNumber != null
                        ? Text('CNI: ${patient.cniNumber}')
                        : null,
                    onTap: () => _handlePatientSelect(patient),
                  ),
                );
              },
            ),
          );
        } else if (result is Failure<List<PatientModel>>) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'Erreur: ${result.message}',
                style: GoogleFonts.poppins(
                  color: Colors.red.shade600,
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'Erreur: $error',
            style: GoogleFonts.poppins(
              color: Colors.red.shade600,
            ),
          ),
        ),
      ),
    );
  }

  void _loadMedicalRecords(int patientId) {
    setState(() {
      _selectedPatientId = patientId;
      _currentStep = AttachFileStep.selectRecord;
    });
  }

  Widget _buildMedicalRecordsList(BuildContext context, bool isDark) {
    if (_selectedPatientId == null) {
      return const SizedBox.shrink();
    }

    final recordsAsync =
        ref.watch(patientMedicalRecordsProvider(_selectedPatientId!));

    return recordsAsync.when(
      data: (result) {
        if (result is Success<List<MedicalRecordModel>>) {
          final records = result.data;
          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations?.noMedicalRecordsFound ??
                          'No medical records found',
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                      ),
                    );
                  },
                ),
              ),
            );
          }
          return SizedBox(
            height: 400,
            child: ListView.builder(
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                final isSelected = _selectedRecord?.id == record.id;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isSelected
                      ? Colors.blue.shade50
                      : (isDark ? Colors.grey.shade800 : Colors.white),
                  child: ListTile(
                    leading: Icon(
                      Icons.description,
                      color: isSelected
                          ? Colors.blue.shade600
                          : Colors.grey.shade600,
                    ),
                    title: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          '${localizations?.recordId ?? 'Record ID'}: ${record.id}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (record.diagnosis != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.medical_services,
                                    size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    record.diagnosis!,
                                    style: GoogleFonts.poppins(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (record.createdAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                    ref.watch(localeProvider).locale.toString(),
                                  ).format(record.createdAt!),
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: Colors.blue.shade600)
                        : null,
                    onTap: () => _handleRecordSelect(record),
                  ),
                );
              },
            ),
          );
        } else if (result is Failure<List<MedicalRecordModel>>) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'Erreur: ${result.message}',
                style: GoogleFonts.poppins(
                  color: Colors.red.shade600,
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: LoadingWidget(),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'Erreur: $error',
            style: GoogleFonts.poppins(
              color: Colors.red.shade600,
            ),
          ),
        ),
      ),
    );
  }

  void _handleRecordSelect(MedicalRecordModel record) {
    setState(() {
      _selectedRecord = record;
      _currentStep = AttachFileStep.uploadFiles;
    });
  }

  Future<void> _pickFiles() async {
    final source = await _showUploadOptionsBottomSheet();
    if (source == null) return;

    try {
      File? pickedFile;
      Uint8List? fileBytes;
      String fileName = '';

      if (source == 'camera') {
        final ImagePicker picker = ImagePicker();
        final XFile? photo = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );

        if (photo == null) return;

        if (photo.name.isEmpty || !photo.name.contains('.')) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          fileName = 'camera_$timestamp.jpg';
        } else {
          fileName = photo.name;
        }

        if (kIsWeb) {
          fileBytes = await photo.readAsBytes();
        } else {
          pickedFile = File(photo.path);
          if (!fileName.toLowerCase().endsWith('.jpg') &&
              !fileName.toLowerCase().endsWith('.jpeg')) {
            fileName = fileName.replaceAll(RegExp(r'\.[^.]+$'), '') + '.jpg';
          }
        }
      } else if (source == 'gallery') {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );

        if (image == null) return;

        if (image.name.isEmpty || !image.name.contains('.')) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final pathExtension = image.path.split('.').last.toLowerCase();
          if (pathExtension == 'jpg' ||
              pathExtension == 'jpeg' ||
              pathExtension == 'png') {
            fileName = 'image_$timestamp.$pathExtension';
          } else {
            fileName = 'image_$timestamp.jpg';
          }
        } else {
          fileName = image.name;
        }

        if (kIsWeb) {
          fileBytes = await image.readAsBytes();
        } else {
          pickedFile = File(image.path);
        }
      } else if (source == 'file') {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
        );

        if (result == null || result.files.isEmpty) return;

        final file = result.files.single;
        fileName = file.name;

        if (kIsWeb) {
          if (file.bytes == null) {
            if (mounted) {
              final localizations = AppLocalizations.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    localizations?.cannotReadFile ??
                        'Cannot read file. Please try again.',
                  ),
                ),
              );
            }
            return;
          }
          fileBytes = file.bytes;
        } else {
          if (file.path == null || file.path!.isEmpty) {
            if (mounted) {
              final localizations = AppLocalizations.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    localizations?.filePathNotAvailable ??
                        'File path not available. Please try again.',
                  ),
                ),
              );
            }
            return;
          }

          pickedFile = File(file.path!);

          if (!await pickedFile.exists()) {
            if (mounted) {
              final localizations = AppLocalizations.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${localizations?.fileDoesNotExist ?? 'File does not exist'}: ${file.path}',
                  ),
                ),
              );
            }
            return;
          }

          if (fileName.isEmpty) {
            fileName = file.path!.split('/').last;
            if (fileName.isEmpty) {
              fileName = 'file_${DateTime.now().millisecondsSinceEpoch}';
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _selectedFiles.add(_SelectedFile(
            file: pickedFile,
            fileBytes: fileBytes,
            fileName: fileName,
            fileSize: fileBytes?.length ??
                (pickedFile != null ? pickedFile.lengthSync() : 0),
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  '${localizations?.errorSelectingFiles ?? 'Error selecting files'}: $e',
                );
              },
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<String?> _showUploadOptionsBottomSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Column(
                      children: [
                        Text(
                          localizations?.addAttachment ?? 'Add Attachment',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localizations?.chooseOption ??
                              'Choose an option to add a file',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color:
                                isDark ? Colors.white70 : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildUploadOption(
                            icon: Icons.camera_alt_rounded,
                            title: localizations?.camera ?? 'Camera',
                            subtitle:
                                localizations?.takePhoto ?? 'Take a photo',
                            color: Colors.blue,
                            onTap: () => Navigator.pop(context, 'camera'),
                            isDark: isDark,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildUploadOption(
                            icon: Icons.photo_library_rounded,
                            title: localizations?.gallery ?? 'Gallery',
                            subtitle:
                                localizations?.chooseImage ?? 'Choose an image',
                            color: Colors.green,
                            onTap: () => Navigator.pop(context, 'gallery'),
                            isDark: isDark,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildUploadOption(
                            icon: Icons.insert_drive_file_rounded,
                            title: localizations?.file ?? 'File',
                            subtitle:
                                localizations?.chooseFile ?? 'Choose a file',
                            color: Colors.orange,
                            onTap: () => Navigator.pop(context, 'file'),
                            isDark: isDark,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          localizations?.cancel ?? 'Cancel',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFileCard(
      _SelectedFile selectedFile, int index, bool isDark) {
    final fileName = selectedFile.fileName;
    final fileExtension = fileName.split('.').last.toLowerCase();
    final isImage =
        ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileExtension);
    final isPdf = fileExtension == 'pdf';

    Color getFileColor() {
      if (isImage) return Colors.blue;
      if (isPdf) return Colors.red;
      return Colors.orange;
    }

    IconData getFileIcon() {
      if (isImage) return Icons.image_rounded;
      if (isPdf) return Icons.picture_as_pdf_rounded;
      return Icons.insert_drive_file_rounded;
    }

    final fileColor = getFileColor();
    final fileIcon = getFileIcon();
    final fileSizeKB = (selectedFile.fileSize / 1024).toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: fileColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                fileIcon,
                color: fileColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey.shade900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$fileSizeKB KB',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return IconButton(
                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                  tooltip: localizations?.delete ?? 'Delete',
                  onPressed: () => _removeFile(index),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadFiles() async {
    if (_selectedRecord == null || _selectedFiles.isEmpty) {
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.pleaseSelectRecordAndFiles ??
                'Please select a record and files',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final service = ref.read(medicalRecordServiceProvider);
    int successCount = 0;
    int errorCount = 0;
    List<String> errors = [];

    for (var selectedFile in _selectedFiles) {
      try {
        Result<MedicalRecordAttachment> uploadResult;

        if (kIsWeb) {
          if (selectedFile.fileBytes == null) {
            errorCount++;
            errors
                .add('${selectedFile.fileName}: Impossible de lire le fichier');
            continue;
          }
          uploadResult = await service.uploadAttachment(
            medicalRecordId: _selectedRecord!.id!,
            fileBytes: selectedFile.fileBytes,
            fileName: selectedFile.fileName,
          );
        } else {
          if (selectedFile.file == null) {
            errorCount++;
            errors.add(
                '${selectedFile.fileName}: Chemin du fichier non disponible');
            continue;
          }
          if (!await selectedFile.file!.exists()) {
            errorCount++;
            errors.add('${selectedFile.fileName}: Le fichier n\'existe pas');
            continue;
          }
          uploadResult = await service.uploadAttachment(
            medicalRecordId: _selectedRecord!.id!,
            file: selectedFile.file,
            fileName:
                selectedFile.fileName.isNotEmpty ? selectedFile.fileName : null,
          );
        }

        uploadResult.when(
          success: (_) => successCount++,
          failure: (message) {
            errorCount++;
            errors.add('${selectedFile.fileName}: $message');
          },
        );
      } catch (e) {
        errorCount++;
        errors.add('${selectedFile.fileName}: $e');
      }
    }

    setState(() {
      _isUploading = false;
    });

    if (mounted) {
      if (successCount > 0) {
        final locale = ref.watch(localeProvider).locale;
        final dateFormat =
            DateFormat('dd MMMM yyyy \'à\' HH:mm', locale.toString());
        final uploadDate = dateFormat.format(DateTime.now());

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations?.filesAttachedSuccessfully ??
                            'Files attached successfully',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      '${successCount} ${localizations?.filesUploadedSuccessfully ?? 'file(s) uploaded successfully'}${errorCount > 0 ? '\n\n$errorCount ${localizations?.filesFailed ?? 'file(s) failed'}' : ''}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(
                                Icons.person,
                                localizations?.patient ?? 'Patient',
                                _selectedPatient?.user?.name ??
                                    '${localizations?.patient ?? 'Patient'} #${_selectedPatient?.id}',
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                Icons.description,
                                localizations?.recordId ?? 'Record ID',
                                '${_selectedRecord!.id}',
                              ),
                              if (_selectedRecord!.diagnosis != null) ...[
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  Icons.medical_services,
                                  localizations?.diagnosis ?? 'Diagnosis',
                                  _selectedRecord!.diagnosis!,
                                ),
                              ],
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                Icons.calendar_today,
                                localizations?.date ?? 'Date',
                                uploadDate,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context, true); // Close attach file screen
                },
                child: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations?.close ?? 'Close',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    );
                  },
                ),
              ),
              if (_selectedRecord?.id != null)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close attach file screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MedicalRecordDetailScreen(
                          recordId: _selectedRecord!.id!,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.description, size: 18),
                  label: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(localizations?.viewRecord ?? 'View Record');
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              if (_selectedPatient?.id != null)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close attach file screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientDetailScreen(
                          patientId: _selectedPatient!.id!,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person, size: 18),
                  label: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(localizations?.viewProfile ?? 'View Profile');
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        );
      } else {
        final localizations = AppLocalizations.of(context);
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.scale,
          title: localizations?.error ?? 'Error',
          desc:
              '${localizations?.fileUploadFailed ?? 'File upload failed'}.\n\n${errors.join('\n')}',
          btnOkText: 'Close',
          btnOkColor: Colors.red,
        ).show();
      }
    }
  }

  void _handleBack() {
    if (_currentStep == AttachFileStep.uploadFiles) {
      setState(() {
        _currentStep = AttachFileStep.selectRecord;
        _selectedFiles = [];
      });
    } else if (_currentStep == AttachFileStep.selectRecord) {
      setState(() {
        _currentStep = AttachFileStep.selectPatient;
        _selectedRecord = null;
        _selectedPatientId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(
              localizations?.attachFiles ?? 'Attach Files',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            );
          },
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.shade600,
                Colors.green.shade700,
              ],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF0F0F23),
                    const Color(0xFF1A1A2E),
                  ]
                : [
                    const Color(0xFFF0F2F5),
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Indicator
                _buildStepIndicator(context, isDark, primaryColor),
                const SizedBox(height: 32),

                // Step Content
                if (_currentStep == AttachFileStep.selectPatient)
                  _buildSelectPatientStep(context, isDark)
                else if (_currentStep == AttachFileStep.selectRecord)
                  _buildSelectRecordStep(context, isDark)
                else if (_currentStep == AttachFileStep.uploadFiles)
                  _buildUploadFilesStep(context, isDark),

                const SizedBox(height: 32),

                // Navigation Buttons
                _buildNavigationButtons(context, isDark, primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(
      BuildContext context, bool isDark, Color primaryColor) {
    final localizations = AppLocalizations.of(context);
    return Row(
      children: [
        _buildStepCircle(
          context,
          step: 1,
          isActive: _currentStep.index >= 0,
          isCompleted: _currentStep.index > 0,
          label: '${localizations?.selectPatient ?? 'Select Patient'}',
          isDark: isDark,
          primaryColor: primaryColor,
        ),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: _currentStep.index >= 1
                  ? primaryColor
                  : Colors.grey.withOpacity(0.3),
            ),
          ),
        ),
        _buildStepCircle(
          context,
          step: 2,
          isActive: _currentStep.index >= 1,
          isCompleted: _currentStep.index > 1,
          label: '${localizations?.selectRecord ?? 'Select Record'}',
          isDark: isDark,
          primaryColor: primaryColor,
        ),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: _currentStep.index >= 2
                  ? primaryColor
                  : Colors.grey.withOpacity(0.3),
            ),
          ),
        ),
        _buildStepCircle(
          context,
          step: 3,
          isActive: _currentStep.index >= 2,
          isCompleted: false,
          label: '${localizations?.uploadFiles ?? 'Upload Files'}',
          isDark: isDark,
          primaryColor: primaryColor,
        ),
      ],
    );
  }

  Widget _buildStepCircle(
    BuildContext context, {
    required int step,
    required bool isActive,
    required bool isCompleted,
    required String label,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? primaryColor : Colors.grey.withOpacity(0.3),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 24)
                : Text(
                    '$step',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive
                ? primaryColor
                : (isDark ? Colors.white70 : Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectPatientStep(BuildContext context, bool isDark) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue.shade600, size: 24),
                const SizedBox(width: 12),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations?.selectPatient ?? 'Select Patient',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey.shade900,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return TextField(
                  controller: _patientSearchController,
                  decoration: InputDecoration(
                    hintText: localizations?.searchForPatient ??
                        'Search for a patient...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor:
                        isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  ),
                  onChanged: _handlePatientSearch,
                );
              },
            ),
            const SizedBox(height: 16),
            _buildPatientSearchResults(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectRecordStep(BuildContext context, bool isDark) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description,
                    color: Colors.purple.shade600, size: 24),
                const SizedBox(width: 12),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations?.selectMedicalRecord ??
                          'Select Medical Record',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey.shade900,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedPatient != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue.shade600),
                    const SizedBox(width: 12),
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          '${localizations?.patient ?? 'Patient'}: ${_selectedPatient!.user?.name ?? '${localizations?.patient ?? 'Patient'} #${_selectedPatient!.id}'}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade900,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            _buildMedicalRecordsList(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadFilesStep(BuildContext context, bool isDark) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file, color: Colors.green.shade600, size: 24),
                const SizedBox(width: 12),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations?.uploadFiles ?? 'Upload Files',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey.shade900,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedRecord != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, color: Colors.purple.shade600),
                        const SizedBox(width: 12),
                        Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Text(
                              '${localizations?.recordId ?? 'Record ID'}: ${_selectedRecord!.id}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.purple.shade900,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    if (_selectedRecord!.diagnosis != null) ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            '${localizations?.diagnosis ?? 'Diagnosis'}: ${_selectedRecord!.diagnosis}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.purple.shade700,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.add),
                    label: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(localizations?.addFiles ?? 'Add Files');
                      },
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_selectedFiles.isNotEmpty) ...[
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    '${localizations?.selectedFiles ?? 'Selected Files'} (${_selectedFiles.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedFiles.isNotEmpty && !_isUploading
                      ? _uploadFiles
                      : null,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(_isUploading
                          ? (localizations?.uploading ?? 'Uploading...')
                          : (localizations?.uploadFiles ?? 'Upload Files'));
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: _selectedFiles.length,
                  itemBuilder: (context, index) {
                    return _buildSelectedFileCard(
                        _selectedFiles[index], index, isDark);
                  },
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.cloud_upload,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            localizations?.noFilesSelected ??
                                'No files selected',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                            ),
                          );
                        },
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

  Widget _buildNavigationButtons(
      BuildContext context, bool isDark, Color primaryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton(
          onPressed: _currentStep == AttachFileStep.selectPatient
              ? () => Navigator.pop(context)
              : _handleBack,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.grey.shade800,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Text(
                _currentStep == AttachFileStep.selectPatient
                    ? (localizations?.cancel ?? 'Cancel')
                    : (localizations?.back ?? 'Back'),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
        if (_currentStep == AttachFileStep.selectPatient)
          ElevatedButton(
            onPressed: _selectedPatient != null
                ? () {
                    if (_selectedPatientId != null) {
                      setState(() {
                        _currentStep = AttachFileStep.selectRecord;
                      });
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  'Next',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                );
              },
            ),
          )
        else if (_currentStep == AttachFileStep.selectRecord)
          ElevatedButton(
            onPressed: _selectedRecord != null
                ? () {
                    setState(() {
                      _currentStep = AttachFileStep.uploadFiles;
                    });
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  'Next',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                );
              },
            ),
          )
        else
          ElevatedButton(
            onPressed: (_selectedFiles.isNotEmpty && !_isUploading)
                ? _uploadFiles
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.upload),
                      const SizedBox(width: 8),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            localizations?.upload ?? 'Upload',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600),
                          );
                        },
                      ),
                    ],
                  ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.blue.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
