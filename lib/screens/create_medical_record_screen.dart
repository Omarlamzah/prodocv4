// lib/screens/create_medical_record_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/utils/result.dart';
import '../data/models/medical_record_model.dart';
import '../data/models/patient_model.dart';
import '../data/models/doctor_model.dart';
import '../data/models/appointment_model.dart';
import '../providers/medical_record_providers.dart';
import '../providers/patient_providers.dart';
import '../providers/doctor_providers.dart';
import '../widgets/loading_widget.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_providers.dart';

enum MedicalRecordStep {
  patientDoctor,
  vitalSigns,
  medicalDetails,
  review,
}

class CreateMedicalRecordScreen extends ConsumerStatefulWidget {
  final int? recordId;
  final int? patientId;

  const CreateMedicalRecordScreen({
    super.key,
    this.recordId,
    this.patientId,
  });

  @override
  ConsumerState<CreateMedicalRecordScreen> createState() =>
      _CreateMedicalRecordScreenState();
}

class _CreateMedicalRecordScreenState
    extends ConsumerState<CreateMedicalRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  MedicalRecordStep _currentStep = MedicalRecordStep.patientDoctor;

  // Step 1: Patient & Doctor
  final _patientSearchController = TextEditingController();
  PatientModel? _selectedPatient;
  DoctorModel? _selectedDoctor;
  AppointmentModel? _selectedAppointment;
  int? _selectedSpecialtyId;
  Specialty? _selectedSpecialty;
  List<PatientModel> _foundPatients = [];
  bool _isSearchingPatients = false;
  bool _isLoadingSpecialtyFields = false;

  // Step 2: Vital Signs & Allergies
  final _bloodPressureController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _respiratoryRateController = TextEditingController();
  final _bmiController = TextEditingController();
  bool? _hasAllergies;
  final _allergyDetailsController = TextEditingController();
  Map<String, dynamic> _specialtyData = {};

  // Step 3: Medical Details
  final _symptomsController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _notesController = TextEditingController();

  // Visibility
  String _visibility = 'private';

  bool _isSubmitting = false;
  bool _isLoadingRecord = false;

  @override
  void initState() {
    super.initState();
    if (widget.patientId != null) {
      _loadPatient(widget.patientId!);
    }
    if (widget.recordId != null) {
      _loadRecord(widget.recordId!);
    }
  }

  @override
  void dispose() {
    _patientSearchController.dispose();
    _bloodPressureController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _temperatureController.dispose();
    _heartRateController.dispose();
    _respiratoryRateController.dispose();
    _bmiController.dispose();
    _allergyDetailsController.dispose();
    _symptomsController.dispose();
    _diagnosisController.dispose();
    _treatmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPatient(int patientId) async {
    final patientAsync = ref.read(patientProvider(patientId));
    patientAsync.whenData((result) {
      if (result is Success<PatientModel>) {
        setState(() {
          _selectedPatient = result.data;
        });
      }
    });
  }

  Future<void> _loadRecord(int recordId) async {
    setState(() => _isLoadingRecord = true);
    final recordAsync = ref.read(medicalRecordProvider(recordId));
    recordAsync.whenData((result) {
      if (result is Success<MedicalRecordModel>) {
        final record = result.data;
        setState(() {
          _selectedPatient = record.patient;
          _selectedDoctor = record.doctor;
          _selectedAppointment = record.appointment;
          _selectedSpecialtyId = record.specialtyId;
          _selectedSpecialty = record.specialty;

          _bloodPressureController.text = record.bloodPressure ?? '';
          _weightController.text = record.weight?.toString() ?? '';
          _heightController.text = record.height?.toString() ?? '';
          _temperatureController.text = record.temperature?.toString() ?? '';
          _heartRateController.text = record.heartRate?.toString() ?? '';
          _respiratoryRateController.text =
              record.respiratoryRate?.toString() ?? '';
          _bmiController.text = record.bmi ?? '';
          _hasAllergies = record.hasAllergies;
          _allergyDetailsController.text = record.allergyDetails ?? '';
          _specialtyData = record.specialtyData ?? {};

          _symptomsController.text = record.symptoms ?? '';
          _diagnosisController.text = record.diagnosis ?? '';
          _treatmentController.text = record.treatment ?? '';
          _notesController.text = record.notes ?? '';
          _visibility = record.visibility ?? 'private';
        });
        if (_selectedSpecialtyId != null) {
          _loadSpecialtyFields(_selectedSpecialtyId!);
        }
      }
      setState(() => _isLoadingRecord = false);
    });
  }

  Future<void> _loadSpecialtyFields(int specialtyId) async {
    setState(() => _isLoadingSpecialtyFields = true);

    try {
      final result =
          await ref.read(specialtyFieldsProvider(specialtyId).future);

      if (mounted) {
        if (result is Success<Map<String, dynamic>>) {
          setState(() {
            _selectedSpecialty = Specialty.fromJson(result.data);
            _isLoadingSpecialtyFields = false;
            // Clear specialty data when changing specialty (unless editing existing record)
            if (widget.recordId == null) {
              _specialtyData = {};
            }
          });
        } else if (result is Failure<Map<String, dynamic>>) {
          setState(() => _isLoadingSpecialtyFields = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${result.message}')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSpecialtyFields = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading fields: $e')),
        );
      }
    }
  }

  void _searchPatients(String query) async {
    if (query.length < 2) {
      setState(() {
        _foundPatients = [];
        _isSearchingPatients = false;
      });
      return;
    }

    setState(() => _isSearchingPatients = true);

    try {
      final result = await ref.read(findPatientsProvider(query).future);

      if (mounted) {
        if (result is Success<List<PatientModel>>) {
          setState(() {
            _foundPatients = result.data;
            _isSearchingPatients = false;
          });
        } else if (result is Failure<List<PatientModel>>) {
          setState(() {
            _foundPatients = [];
            _isSearchingPatients = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${result.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _foundPatients = [];
          _isSearchingPatients = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e')),
        );
      }
    }
  }

  bool _validateStep(MedicalRecordStep step) {
    // Validate form fields first
    if (!(_formKey.currentState?.validate() ?? true)) {
      return false;
    }

    switch (step) {
      case MedicalRecordStep.patientDoctor:
        if (_selectedPatient == null ||
            _selectedDoctor == null ||
            _selectedSpecialtyId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please select patient, doctor and specialty')),
          );
          return false;
        }
        return true;
      case MedicalRecordStep.vitalSigns:
        return true; // Optional fields
      case MedicalRecordStep.medicalDetails:
        if (_symptomsController.text.trim().isEmpty ||
            _diagnosisController.text.trim().isEmpty ||
            _treatmentController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Please fill in symptoms, diagnosis and treatment')),
          );
          return false;
        }
        // Validate required specialty fields
        if (_selectedSpecialty != null && _selectedSpecialty!.fields != null) {
          for (final field in _selectedSpecialty!.fields!) {
            if (field.required == true) {
              final fieldValue = _specialtyData[field.fieldName];
              if (fieldValue == null ||
                  (fieldValue is String && fieldValue.trim().isEmpty)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Please fill required field: ${field.fieldLabel}'),
                  ),
                );
                return false;
              }
            }
          }
        }
        return true;
      case MedicalRecordStep.review:
        return true;
    }
  }

  void _nextStep() {
    if (_validateStep(_currentStep)) {
      setState(() {
        switch (_currentStep) {
          case MedicalRecordStep.patientDoctor:
            _currentStep = MedicalRecordStep.vitalSigns;
            break;
          case MedicalRecordStep.vitalSigns:
            _currentStep = MedicalRecordStep.medicalDetails;
            break;
          case MedicalRecordStep.medicalDetails:
            _currentStep = MedicalRecordStep.review;
            break;
          case MedicalRecordStep.review:
            break;
        }
      });
    }
  }

  void _previousStep() {
    setState(() {
      switch (_currentStep) {
        case MedicalRecordStep.patientDoctor:
          break;
        case MedicalRecordStep.vitalSigns:
          _currentStep = MedicalRecordStep.patientDoctor;
          break;
        case MedicalRecordStep.medicalDetails:
          _currentStep = MedicalRecordStep.vitalSigns;
          break;
        case MedicalRecordStep.review:
          _currentStep = MedicalRecordStep.medicalDetails;
          break;
      }
    });
  }

  Future<void> _submit() async {
    if (!_validateStep(_currentStep)) return;

    setState(() => _isSubmitting = true);

    final recordData = <String, dynamic>{
      'patient_id': _selectedPatient!.id,
      'doctor_id': _selectedDoctor!.id,
      'specialty_id': _selectedSpecialtyId,
      if (_selectedAppointment != null)
        'appointment_id': _selectedAppointment!.id,
      'symptoms': _symptomsController.text.trim(),
      'diagnosis': _diagnosisController.text.trim(),
      'treatment': _treatmentController.text.trim(),
      // Always include notes (backend expects it)
      'notes': _notesController.text.trim(),
      // Always include vital signs fields (backend expects them)
      // Send empty string for text fields
      'blood_pressure': _bloodPressureController.text.trim(),
      'bmi': _bmiController.text.trim(),
      // Always send numeric values - backend expects these keys to always be present
      // Send 0/0.0 for empty fields to avoid "Undefined array key" errors
      'weight': _weightController.text.trim().isNotEmpty
          ? (double.tryParse(_weightController.text) ?? 0.0)
          : 0.0,
      'height': _heightController.text.trim().isNotEmpty
          ? (double.tryParse(_heightController.text) ?? 0.0)
          : 0.0,
      'temperature': _temperatureController.text.trim().isNotEmpty
          ? (double.tryParse(_temperatureController.text) ?? 0.0)
          : 0.0,
      'heart_rate': _heartRateController.text.trim().isNotEmpty
          ? (int.tryParse(_heartRateController.text) ?? 0)
          : 0,
      'respiratory_rate': _respiratoryRateController.text.trim().isNotEmpty
          ? (int.tryParse(_respiratoryRateController.text) ?? 0)
          : 0,
      // Always include has_allergies (backend expects it)
      'has_allergies': _hasAllergies ?? false,
      // Always include allergy_details (backend might expect it)
      'allergy_details': _allergyDetailsController.text.trim(),
      if (_selectedSpecialtyId != null) 'specialty_data': _specialtyData,
      'visibility': _visibility,
    };

    final service = ref.read(medicalRecordServiceProvider);
    Result result;

    if (widget.recordId != null) {
      result = await service.updateMedicalRecord(
        recordId: widget.recordId!,
        recordData: recordData,
      );
    } else {
      result = await service.createMedicalRecord(recordData);
    }

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (result is Success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.recordId != null
                ? 'Medical record updated successfully'
                : 'Medical record created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else if (result is Failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRecord) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Loading...',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        body: const LoadingWidget(),
      );
    }

    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(
              widget.recordId != null
                  ? 'Edit Medical Record'
                  : 'New Medical Record',
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
                primaryColor,
                primaryColor.withOpacity(0.8),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                  ]
                : [
                    Colors.grey.shade50,
                    Colors.white,
                  ],
          ),
        ),
        child: Column(
          children: [
            _buildModernStepIndicator(),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildCurrentStep(),
                ),
              ),
            ),
            _buildModernNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernStepIndicator() {
    final steps = [
      {'title': 'Patient & Doctor', 'icon': Icons.person},
      {'title': 'Vital Signs', 'icon': Icons.favorite},
      {'title': 'Medical Details', 'icon': Icons.medical_services},
      {'title': 'Review', 'icon': Icons.check_circle},
    ];

    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final stepIndex = _currentStep.index;
          final isActive = index == stepIndex;
          final isCompleted = index < stepIndex;
          final step = entry.value;

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: isCompleted || isActive
                              ? primaryColor
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (index < steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? primaryColor
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? primaryColor
                            : isCompleted
                                ? Colors.green
                                : Colors.grey.shade300,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 18)
                            : Icon(
                                step['icon'] as IconData,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
                    ),
                    if (isActive && !isCompleted)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  step['title'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive
                        ? primaryColor
                        : isCompleted
                            ? Colors.green
                            : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case MedicalRecordStep.patientDoctor:
        return _buildPatientDoctorStep();
      case MedicalRecordStep.vitalSigns:
        return _buildVitalSignsStep();
      case MedicalRecordStep.medicalDetails:
        return _buildMedicalDetailsStep();
      case MedicalRecordStep.review:
        return _buildReviewStep();
    }
  }

  Widget _buildPatientDoctorStep() {
    final doctorsAsync = ref.watch(doctorsProvider);
    final specialtiesAsync = ref.watch(medicalRecordSpecialtiesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return const Text(
              'Select Patient, Doctor and Specialty',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            );
          },
        ),
        const SizedBox(height: 24),
        // Patient Selection
        TextFormField(
          controller: _patientSearchController,
          decoration: InputDecoration(
            labelText: 'Patient',
            hintText: 'Search for a patient...',
            prefixIcon: const Icon(Icons.person),
            suffixIcon: _selectedPatient != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _selectedPatient = null),
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: _searchPatients,
          readOnly: widget.patientId != null,
        ),
        if (_isSearchingPatients)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(),
          ),
        if (_foundPatients.isNotEmpty && _selectedPatient == null)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _foundPatients.length,
              itemBuilder: (context, index) {
                final patient = _foundPatients[index];
                return ListTile(
                  title: Text(patient.user?.name ?? 'Patient #${patient.id}'),
                  subtitle: Text(patient.user?.email ?? ''),
                  onTap: () {
                    setState(() {
                      _selectedPatient = patient;
                      _patientSearchController.text = patient.user?.name ?? '';
                      _foundPatients = [];
                    });
                  },
                );
              },
            ),
          ),
        if (_selectedPatient != null) ...[
          const SizedBox(height: 8),
          Chip(
            label: Text(_selectedPatient!.user?.name ?? 'Patient'),
            onDeleted: () => setState(() => _selectedPatient = null),
          ),
        ],
        const SizedBox(height: 16),
        // Doctor Selection
        doctorsAsync.when(
          data: (doctors) {
            if (doctors is Success<List<DoctorModel>>) {
              // Find the matching doctor from the list if we have a selected doctor
              // This ensures the dropdown can find the matching item by object reference
              DoctorModel? matchingDoctor;
              if (_selectedDoctor != null && _selectedDoctor!.id != null) {
                try {
                  matchingDoctor = doctors.data.firstWhere(
                    (doctor) => doctor.id == _selectedDoctor!.id,
                  );
                } catch (e) {
                  // Doctor not found in list, set to null
                  // The dropdown will show no selection, user can select again
                  matchingDoctor = null;
                }
              }

              return DropdownButtonFormField<DoctorModel>(
                decoration: const InputDecoration(
                  labelText: 'Doctor',
                  prefixIcon: Icon(Icons.medical_services),
                  border: OutlineInputBorder(),
                ),
                value: matchingDoctor,
                items: doctors.data.map((doctor) {
                  return DropdownMenuItem(
                    value: doctor,
                    child: Text(doctor.user?.name ?? 'Doctor #${doctor.id}'),
                  );
                }).toList(),
                onChanged: (doctor) => setState(() => _selectedDoctor = doctor),
              );
            }
            return const SizedBox.shrink();
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('Error loading doctors'),
        ),
        const SizedBox(height: 24),
        // Specialty Selection - Grid Layout
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(
              'Select a Specialty',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey.shade900,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        specialtiesAsync.when(
          data: (result) {
            if (result is Success<List<dynamic>>) {
              return _buildSpecialtyGrid(result.data);
            }
            return const SizedBox.shrink();
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Error loading specialties',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ),
        if (_isLoadingSpecialtyFields && _selectedSpecialtyId != null) ...[
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Chargement des champs de spécialité...'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSpecialtyGrid(List<dynamic> specialties) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Map specialty names to medical icons
    IconData getSpecialtyIcon(String name) {
      final lowerName = name.toLowerCase();
      if (lowerName.contains('cardio') || lowerName.contains('heart')) {
        return Icons.favorite;
      } else if (lowerName.contains('neuro')) {
        return Icons.psychology;
      } else if (lowerName.contains('ortho') || lowerName.contains('bone')) {
        return Icons.healing;
      } else if (lowerName.contains('derm') || lowerName.contains('skin')) {
        return Icons.face;
      } else if (lowerName.contains('pediat') || lowerName.contains('child')) {
        return Icons.child_care;
      } else if (lowerName.contains('gyneco') || lowerName.contains('women')) {
        return Icons.pregnant_woman;
      } else if (lowerName.contains('ophtalmo') || lowerName.contains('eye')) {
        return Icons.remove_red_eye;
      } else if (lowerName.contains('dent') || lowerName.contains('tooth')) {
        return Icons.medical_information;
      } else if (lowerName.contains('kinesi') || lowerName.contains('physio')) {
        return Icons.fitness_center;
      } else if (lowerName.contains('psych') || lowerName.contains('mental')) {
        return Icons.psychology;
      } else if (lowerName.contains('general') ||
          lowerName.contains('family')) {
        return Icons.local_hospital;
      } else {
        return Icons.medical_services;
      }
    }

    // Get color for specialty
    Color getSpecialtyColor(String name, int index) {
      final colors = [
        Colors.blue,
        Colors.green,
        Colors.orange,
        Colors.purple,
        Colors.red,
        Colors.teal,
        Colors.pink,
        Colors.indigo,
        Colors.cyan,
        Colors.amber,
      ];
      return colors[index % colors.length];
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: specialties.length,
      itemBuilder: (context, index) {
        final specialty = specialties[index];
        final id = specialty['id'] as int;
        final name = specialty['name'] as String;
        final isSelected = _selectedSpecialtyId == id;
        final icon = getSpecialtyIcon(name);
        final color = getSpecialtyColor(name, index);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedSpecialtyId = id;
                _selectedSpecialty = null;
                _specialtyData = {};
              });
              _loadSpecialtyFields(id);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.15)
                    : isDark
                        ? Colors.grey.shade800
                        : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? color
                      : isDark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.2)
                          : color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? color : color.withOpacity(0.7),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? color
                            : isDark
                                ? Colors.white
                                : Colors.grey.shade800,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.check_circle,
                        color: color,
                        size: 16,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVitalSignsStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vital Signs and History',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter patient vital signs',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _bloodPressureController,
                decoration: const InputDecoration(
                  labelText: 'Blood Pressure',
                  hintText: 'e.g: 120/80',
                  prefixIcon: Icon(Icons.favorite),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  prefixIcon: Icon(Icons.monitor_weight),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Height (cm)',
                  prefixIcon: Icon(Icons.height),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _temperatureController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Temperature (°C)',
                  prefixIcon: Icon(Icons.thermostat),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _heartRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Heart Rate (bpm)',
                  prefixIcon: Icon(Icons.favorite_border),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _respiratoryRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Respiratory Rate (/min)',
                  prefixIcon: Icon(Icons.air),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _bmiController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'BMI',
            prefixIcon: Icon(Icons.calculate),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return const Text(
              'Allergies',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            );
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<bool>(
          decoration: const InputDecoration(
            labelText: 'Does the patient have allergies?',
            border: OutlineInputBorder(),
          ),
          initialValue: _hasAllergies,
          items: const [
            DropdownMenuItem(value: true, child: const Text('Yes')),
            DropdownMenuItem(value: false, child: const Text('No')),
          ],
          onChanged: (value) => setState(() => _hasAllergies = value),
        ),
        if (_hasAllergies == true) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _allergyDetailsController,
            decoration: const InputDecoration(
              labelText: 'Allergy Details',
              hintText: 'Describe known allergies...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
        if (_isLoadingSpecialtyFields && _selectedSpecialtyId != null) ...[
          const SizedBox(height: 24),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading specialty fields...'),
                ],
              ),
            ),
          ),
        ] else if (_selectedSpecialty != null &&
            _selectedSpecialty!.fields != null &&
            _selectedSpecialty!.fields!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return const Text(
                'Specialty-Specific Fields',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              );
            },
          ),
          const SizedBox(height: 16),
          ...[
            ...List<SpecialtyField>.from(_selectedSpecialty!.fields!)
              ..sort((a, b) => (a.fieldOrder ?? 0).compareTo(b.fieldOrder ?? 0))
          ].map((field) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildSpecialtyField(field),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSpecialtyField(SpecialtyField field) {
    final currentValue = _specialtyData[field.fieldName];
    final isRequired = field.required == true;
    final labelText = isRequired ? '${field.fieldLabel} *' : field.fieldLabel;

    switch (field.fieldType) {
      case 'textarea':
        return TextFormField(
          initialValue: currentValue?.toString(),
          decoration: InputDecoration(
            labelText: labelText,
            border: const OutlineInputBorder(),
            helperText: isRequired ? 'Required field' : null,
          ),
          maxLines: 4,
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                }
              : null,
          onChanged: (value) {
            setState(() {
              if (value.isNotEmpty) {
                _specialtyData[field.fieldName!] = value;
              } else {
                _specialtyData.remove(field.fieldName!);
              }
            });
          },
        );
      case 'select':
        final options = field.options ?? [];
        if (options.isEmpty) {
          // If no options, show as text field
          return TextFormField(
            initialValue: currentValue?.toString(),
            decoration: InputDecoration(
              labelText: labelText,
              border: const OutlineInputBorder(),
              helperText: isRequired ? 'Required field' : null,
            ),
            validator: isRequired
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'This field is required';
                    }
                    return null;
                  }
                : null,
            onChanged: (value) {
              setState(() {
                if (value.isNotEmpty) {
                  _specialtyData[field.fieldName!] = value;
                } else {
                  _specialtyData.remove(field.fieldName!);
                }
              });
            },
          );
        }
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: labelText,
            border: const OutlineInputBorder(),
            helperText: isRequired ? 'Required field' : null,
          ),
          value: currentValue?.toString(),
          items: options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option),
            );
          }).toList(),
          validator: isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                }
              : null,
          onChanged: (value) {
            setState(() {
              if (value != null) {
                _specialtyData[field.fieldName!] = value;
              } else {
                _specialtyData.remove(field.fieldName!);
              }
            });
          },
        );
      case 'checkbox':
        return CheckboxListTile(
          title: Text(
              isRequired ? '${field.fieldLabel} *' : (field.fieldLabel ?? '')),
          value: currentValue == true,
          onChanged: (value) {
            setState(() {
              _specialtyData[field.fieldName!] = value ?? false;
            });
          },
        );
      case 'date':
        return TextFormField(
          initialValue: currentValue?.toString(),
          decoration: InputDecoration(
            labelText: labelText,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today),
            helperText: isRequired ? 'Required field' : null,
          ),
          readOnly: true,
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                }
              : null,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: currentValue != null
                  ? DateTime.tryParse(currentValue.toString()) ?? DateTime.now()
                  : DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() {
                final locale = ref.read(localeProvider).locale;
                _specialtyData[field.fieldName!] =
                    DateFormat('yyyy-MM-dd', locale.toString()).format(date);
              });
            }
          },
        );
      default:
        // Handle 'text' and 'number' field types
        return TextFormField(
          initialValue: currentValue?.toString(),
          decoration: InputDecoration(
            labelText: labelText,
            border: const OutlineInputBorder(),
            helperText: isRequired ? 'Required field' : null,
          ),
          keyboardType: field.fieldType == 'number'
              ? TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'This field is required';
                  }
                  if (field.fieldType == 'number') {
                    final numValue = double.tryParse(value);
                    if (numValue == null) {
                      return 'Please enter a valid number';
                    }
                  }
                  return null;
                }
              : null,
          onChanged: (value) {
            setState(() {
              if (field.fieldType == 'number') {
                final numValue = double.tryParse(value);
                if (numValue != null) {
                  _specialtyData[field.fieldName!] = numValue;
                } else if (value.isEmpty) {
                  _specialtyData.remove(field.fieldName!);
                }
              } else {
                if (value.isNotEmpty) {
                  _specialtyData[field.fieldName!] = value;
                } else {
                  _specialtyData.remove(field.fieldName!);
                }
              }
            });
          },
        );
    }
  }

  Widget _buildMedicalDetailsStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medical Information',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Describe symptoms, diagnosis and treatment',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _symptomsController,
          decoration: const InputDecoration(
            labelText: 'Symptoms *',
            hintText: 'Describe patient symptoms...',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Symptoms are required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _diagnosisController,
          decoration: const InputDecoration(
            labelText: 'Diagnosis *',
            hintText: 'Medical diagnosis...',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Diagnosis is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _treatmentController,
          decoration: const InputDecoration(
            labelText: 'Treatment *',
            hintText: 'Prescribed treatment plan...',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Treatment is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Additional Notes',
            hintText: 'Observations or additional notes...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return const Text(
              'Review and Submit',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            );
          },
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildReviewItem('Patient',
                            _selectedPatient?.user?.name ?? 'Not selected'),
                        _buildReviewItem('Doctor',
                            _selectedDoctor?.user?.name ?? 'Not selected'),
                        _buildReviewItem('Specialty',
                            _selectedSpecialty?.name ?? 'Not selected'),
                        _buildReviewItem(
                            'Symptoms',
                            _symptomsController.text.isEmpty
                                ? 'Not entered'
                                : _symptomsController.text),
                        _buildReviewItem(
                            'Diagnosis',
                            _diagnosisController.text.isEmpty
                                ? 'Not entered'
                                : _diagnosisController.text),
                        _buildReviewItem(
                            'Treatment',
                            _treatmentController.text.isEmpty
                                ? 'Not entered'
                                : _treatmentController.text),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Visibility',
                            prefixIcon: Icon(Icons.visibility),
                            border: OutlineInputBorder(),
                            helperText:
                                'Public: Visible to all authorized users. Private: Only visible to assigned doctor and admin.',
                          ),
                          value: _visibility,
                          items: const [
                            DropdownMenuItem(
                              value: 'public',
                              child: Row(
                                children: [
                                  Icon(Icons.public, size: 18),
                                  SizedBox(width: 8),
                                  Text('Public'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'private',
                              child: Row(
                                children: [
                                  Icon(Icons.lock, size: 18),
                                  SizedBox(width: 8),
                                  Text('Private'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _visibility = value);
                            }
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildModernNavigationButtons() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentStep != MedicalRecordStep.patientDoctor)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _previousStep,
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                  label: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        'Previous',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
              )
            else
              const SizedBox(),
            if (_currentStep != MedicalRecordStep.patientDoctor)
              const SizedBox(width: 12),
            Expanded(
              flex: _currentStep == MedicalRecordStep.patientDoctor ? 1 : 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor,
                      primaryColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _currentStep == MedicalRecordStep.review
                      ? (_isSubmitting ? null : _submit)
                      : _nextStep,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _currentStep == MedicalRecordStep.review
                              ? Icons.check_circle
                              : Icons.arrow_forward_ios,
                          size: 18,
                        ),
                  label: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        _isSubmitting
                            ? 'Processing...'
                            : _currentStep == MedicalRecordStep.review
                                ? (widget.recordId != null
                                    ? 'Update'
                                    : 'Create Record')
                                : 'Next',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      );
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
