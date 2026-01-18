// lib/widgets/app_drawer.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_providers.dart';
import '../screens/appointments_screen.dart';
import '../screens/create_appointment_screen.dart';
import '../screens/public_appointment_booking_screen.dart';
import '../screens/create_prescription_screen.dart';
import '../screens/create_medical_record_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/cabinet_info_screen.dart';
import '../screens/patients_screen.dart';
import '../screens/medical_records_screen.dart';
import '../screens/doctor_calendar_screen.dart';
import '../screens/invoices_screen_modern.dart';
import '../screens/create_invoice_screen.dart';
import '../screens/waiting_room_screen.dart';
import '../screens/appointment_requests_screen.dart';
import '../screens/medications_screen.dart';
import '../screens/reports_screen.dart';
import 'language_switcher.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../screens/subscription_management_screen.dart';
import '../screens/specialties_screen.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Note: Navigation after logout is handled by the dashboard screen's listener

    return Drawer(
      width: 280,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                    const Color(0xFF0F3460),
                  ]
                : [
                    Colors.white,
                    Colors.grey.shade50,
                  ],
          ),
        ),
        child: Column(
          children: [
            // Modern User Profile Header
            _buildModernHeader(context, user, isDark, primaryColor)
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: -0.1, end: 0),

            // Menu Items with Categories
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Main Section
                  _buildSectionHeader(
                          context, localizations?.main ?? 'Main', isDark)
                      .animate()
                      .fadeIn(delay: 100.ms),
                  _buildModernDrawerItem(
                    context,
                    icon: Icons.dashboard_rounded,
                    title: localizations?.dashboard ?? 'Dashboard',
                    subtitle: localizations?.overview ?? 'Overview',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const DashboardScreen(),
                        ),
                      );
                    },
                  ).animate().fadeIn(delay: 150.ms).slideX(begin: -0.1),

                  _buildModernDrawerItem(
                    context,
                    icon: Icons.storefront_rounded,
                    title: localizations?.clinicInfo ?? 'Clinic Info',
                    subtitle: localizations?.aboutUs ?? 'About us',
                    color: Colors.deepPurple,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CabinetInfoScreen(),
                        ),
                      );
                    },
                  ).animate().fadeIn(delay: 175.ms).slideX(begin: -0.1),

                  // Quick Actions Section
                  if (user?.isAdmin == 1 ||
                      user?.isReceptionist == 1 ||
                      user?.isPatient == 1 ||
                      user?.isDoctor == 1)
                    _buildSectionHeader(
                            context,
                            localizations?.quickActions ?? 'Quick Actions',
                            isDark)
                        .animate()
                        .fadeIn(delay: 200.ms),

                  if (user?.isAdmin == 1 ||
                      user?.isReceptionist == 1 ||
                      user?.isPatient == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.calendar_today_rounded,
                      title: user?.isPatient == 1
                          ? (localizations?.bookAppointment ??
                              'Book Appointment')
                          : (localizations?.createAppointment ??
                              'Create Appointment'),
                      subtitle: user?.isPatient == 1
                          ? (localizations?.onlineBooking ?? 'Online booking')
                          : (localizations?.newAppointment ??
                              'New appointment'),
                      color: Colors.green,
                      onTap: () {
                        Navigator.pop(context);
                        if (user?.isPatient == 1) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const PublicAppointmentBookingScreen(),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateAppointmentScreen(),
                            ),
                          );
                        }
                      },
                    ).animate().fadeIn(delay: 250.ms).slideX(begin: -0.1),

                  if (user?.isDoctor == 1 || user?.isAdmin == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.medication_rounded,
                      title: localizations?.createPrescription ??
                          'Create Prescription',
                      subtitle:
                          localizations?.newPrescription ?? 'New prescription',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreatePrescriptionScreen(),
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),

                  if (user?.isAdmin == 1 || user?.isAccountant == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.receipt_rounded,
                      title: localizations?.newInvoice ?? 'New Invoice',
                      subtitle:
                          localizations?.createInvoice ?? 'Create invoice',
                      color: Colors.green,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateInvoiceScreen(),
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 310.ms).slideX(begin: -0.1),

                  if (user?.isDoctor == 1 || user?.isAdmin == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.folder_rounded,
                      title: localizations?.createMedicalRecord ??
                          'Create Medical Record',
                      subtitle: localizations?.newRecord ?? 'New record',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateMedicalRecordScreen(),
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 350.ms).slideX(begin: -0.1),

                  // Calendar & Appointments Section
                  if (user?.isAdmin == 1 ||
                      user?.isDoctor == 1 ||
                      user?.isReceptionist == 1 ||
                      user?.isPatient == 1)
                    _buildSectionHeader(
                            context,
                            localizations?.calendarAndAppointments ??
                                'Calendar & Appointments',
                            isDark)
                        .animate()
                        .fadeIn(delay: 360.ms),

                  if (user?.isAdmin == 1 ||
                      user?.isDoctor == 1 ||
                      user?.isReceptionist == 1 ||
                      user?.isPatient == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.calendar_month_rounded,
                      title: localizations?.calendar ?? 'Calendar',
                      subtitle: localizations?.calendarView ?? 'Calendar view',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CalendarScreen(),
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 370.ms).slideX(begin: -0.1),

                  if (user?.isAdmin == 1 ||
                      user?.isDoctor == 1 ||
                      user?.isReceptionist == 1 ||
                      user?.isPatient == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.event_rounded,
                      title: localizations?.appointments ?? 'Appointments',
                      subtitle:
                          localizations?.allAppointments ?? 'All appointments',
                      color: Colors.cyan,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AppointmentsScreen(),
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 380.ms).slideX(begin: -0.1),

                  if (user?.isAdmin == 1 ||
                      user?.isDoctor == 1 ||
                      user?.isReceptionist == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.pending_actions_rounded,
                      title: localizations?.appointmentRequests ??
                          'Appointment Requests',
                      subtitle: localizations?.managePendingRequests ??
                          'Manage pending requests',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AppointmentRequestsScreen(),
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 385.ms).slideX(begin: -0.1),

                  if (user?.isAdmin == 1 ||
                      user?.isDoctor == 1 ||
                      user?.isReceptionist == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.meeting_room_rounded,
                      title: localizations?.waitingRoom ?? 'Waiting Room',
                      subtitle: localizations?.waitingRoomDisplay ??
                          'Waiting room display',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WaitingRoomScreen(),
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 390.ms).slideX(begin: -0.1),

                  // Management Section
                  if (user?.isAdmin == 1 ||
                      user?.isDoctor == 1 ||
                      user?.isReceptionist == 1)
                    _buildSectionHeader(context,
                            localizations?.management ?? 'Management', isDark)
                        .animate()
                        .fadeIn(delay: 400.ms),

                  if (user?.isAdmin == 1 ||
                      user?.isDoctor == 1 ||
                      user?.isReceptionist == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.people_rounded,
                      title: localizations?.patients ?? 'Patients',
                      subtitle: localizations?.patientList ?? 'Patient list',
                      color: Colors.teal,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PatientsScreen(),
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 450.ms).slideX(begin: -0.1),

                  if (user?.isAdmin == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.medical_services_rounded,
                      title: localizations?.doctors ?? 'Doctors',
                      subtitle:
                          localizations?.manageDoctors ?? 'Manage doctors',
                      color: Colors.indigo,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to doctors screen
                      },
                    ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1),

                  if (user?.isAdmin == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.local_hospital_rounded,
                      title: localizations?.services ?? 'Services',
                      subtitle:
                          localizations?.manageServices ?? 'Manage services',
                      color: Colors.pink,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to services screen
                      },
                    ).animate().fadeIn(delay: 550.ms).slideX(begin: -0.1),

                  if (user?.isAdmin == 1 ||
                      user?.isDoctor == 1 ||
                      user?.isReceptionist == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.folder_rounded,
                      title: localizations?.medicalRecords ?? 'Medical Records',
                      subtitle: localizations?.allRecords ?? 'All records',
                      color: Colors.deepPurple,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MedicalRecordsScreen(),
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 650.ms).slideX(begin: -0.1),

                  // Patient Records Section
                  if (user?.isPatient == 1)
                    _buildSectionHeader(
                            context,
                            localizations?.medicalRecords ?? 'My Records',
                            isDark)
                        .animate()
                        .fadeIn(delay: 400.ms),

                  if (user?.isPatient == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.folder_rounded,
                      title:
                          localizations?.medicalRecords ?? 'My Medical Records',
                      subtitle: localizations?.allRecords ??
                          'View my medical records',
                      color: Colors.deepPurple,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MedicalRecordsScreen(),
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 410.ms).slideX(begin: -0.1),

                  if (user?.isAdmin == 1 || user?.isDoctor == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.medication_rounded,
                      title: localizations?.medications ?? 'Medications',
                      subtitle: localizations?.manageMedications ??
                          'Manage medications',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MedicationsScreen(),
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 660.ms).slideX(begin: -0.1),

                  if (user?.isAdmin == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.assessment_rounded,
                      title: localizations?.reports ?? 'Reports',
                      subtitle: localizations?.viewReports ?? 'View reports',
                      color: Colors.teal,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReportsScreen(),
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 710.ms).slideX(begin: -0.1),

                  if (user?.isAdmin == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.medical_services_rounded,
                      title: 'Specialties',
                      subtitle: 'Manage medical specialties',
                      color: Colors.deepPurple,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SpecialtiesScreen(),
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 715.ms).slideX(begin: -0.1),

                  // Invoice Management
                  if (user?.isAdmin == 1 || user?.isAccountant == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.receipt_long_rounded,
                      title: localizations?.invoices ?? 'Invoices',
                      subtitle: localizations?.invoiceManagement ??
                          'Invoice management',
                      color: Colors.green,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InvoicesScreenModern(),
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.1),

                  if (user?.isAdmin == 1 || user?.isAccountant == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.payment_rounded,
                      title: localizations?.subscriptionsTitle ?? 'Abonnements',
                      subtitle: localizations?.upgradePlan ??
                          'Plans et renouvellements',
                      color: Colors.blueGrey,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const SubscriptionManagementScreen(),
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 705.ms).slideX(begin: -0.1),

                  if (user?.isDoctor == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.description_rounded,
                      title:
                          localizations?.myPrescriptions ?? 'My Prescriptions',
                      subtitle: localizations?.myPrescriptionsSubtitle ??
                          'My prescriptions',
                      color: Colors.amber,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to prescriptions screen
                      },
                    ).animate().fadeIn(delay: 650.ms).slideX(begin: -0.1),

                  // Doctor Tools Section
                  if (user?.isDoctor == 1)
                    _buildSectionHeader(
                            context,
                            localizations?.doctorTools ?? 'Doctor Tools',
                            isDark)
                        .animate()
                        .fadeIn(delay: 680.ms),

                  if (user?.isDoctor == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.history_rounded,
                      title: localizations?.patientHistory ?? 'Patient History',
                      subtitle:
                          localizations?.medicalHistory ?? 'Medical history',
                      color: Colors.indigo,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to patient history screen
                      },
                    ).animate().fadeIn(delay: 690.ms).slideX(begin: -0.1),

                  if (user?.isDoctor == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.psychology_rounded,
                      title: localizations?.diagnosis ?? 'Diagnosis',
                      subtitle:
                          localizations?.diagnosticTools ?? 'Diagnostic tools',
                      color: Colors.deepOrange,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to diagnosis tools screen
                      },
                    ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.1),

                  if (user?.isDoctor == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.science_rounded,
                      title: localizations?.labResults ?? 'Lab Results',
                      subtitle: localizations?.analysesAndTests ??
                          'Analyses and tests',
                      color: Colors.cyan,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to lab results screen
                      },
                    ).animate().fadeIn(delay: 710.ms).slideX(begin: -0.1),

                  if (user?.isDoctor == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.assessment_rounded,
                      title: localizations?.medicalReports ?? 'Medical Reports',
                      subtitle: localizations?.reportsAndStatistics ??
                          'Reports and statistics',
                      color: Colors.teal,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to medical reports screen
                      },
                    ).animate().fadeIn(delay: 720.ms).slideX(begin: -0.1),

                  if (user?.isDoctor == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.note_add_rounded,
                      title: localizations?.clinicalNotes ?? 'Clinical Notes',
                      subtitle: localizations?.notesAndObservations ??
                          'Notes and observations',
                      color: Colors.brown,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to clinical notes screen
                      },
                    ).animate().fadeIn(delay: 730.ms).slideX(begin: -0.1),

                  if (user?.isDoctor == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.vaccines_rounded,
                      title: localizations?.vaccinations ?? 'Vaccinations',
                      subtitle: localizations?.vaccinationManagement ??
                          'Vaccination management',
                      color: Colors.lightGreen,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to vaccinations screen
                      },
                    ).animate().fadeIn(delay: 740.ms).slideX(begin: -0.1),

                  if (user?.isDoctor == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.emergency_rounded,
                      title: localizations?.emergencies ?? 'Emergencies',
                      subtitle:
                          localizations?.emergencyCases ?? 'Emergency cases',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to emergencies screen
                      },
                    ).animate().fadeIn(delay: 750.ms).slideX(begin: -0.1),

                  if (user?.isDoctor == 1)
                    _buildModernDrawerItem(
                      context,
                      icon: Icons.assignment_rounded,
                      title: localizations?.consultations ?? 'Consultations',
                      subtitle:
                          localizations?.myConsultations ?? 'My consultations',
                      color: Colors.blueGrey,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to consultations screen
                      },
                    ).animate().fadeIn(delay: 760.ms).slideX(begin: -0.1),

                  const SizedBox(height: 8),

                  // Settings Section
                  _buildSectionHeader(context,
                          localizations?.settings ?? 'Settings', isDark)
                      .animate()
                      .fadeIn(delay: 800.ms),
                  _buildModernDrawerItem(
                    context,
                    icon: Icons.settings_rounded,
                    title: localizations?.settings ?? 'Settings',
                    subtitle: localizations?.configuration ?? 'Configuration',
                    color: Colors.grey,
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navigate to settings screen
                    },
                  ).animate().fadeIn(delay: 810.ms).slideX(begin: -0.1),

                  _buildModernDrawerItem(
                    context,
                    icon: Icons.language_rounded,
                    title: AppLocalizations.of(context)?.language ?? 'Language',
                    subtitle:
                        AppLocalizations.of(context)?.language ?? 'Language',
                    color: Colors.indigo,
                    onTap: () {
                      debugPrint('[AppDrawer] Language menu item tapped');
                      debugPrint('[AppDrawer] Closing drawer...');
                      // Close drawer first
                      Navigator.pop(context);
                      // Show language switcher using global navigator key
                      // This ensures dialog shows even after drawer closes
                      Future.delayed(const Duration(milliseconds: 200), () {
                        debugPrint(
                            '[AppDrawer] Checking navigatorKey.currentContext...');
                        if (navigatorKey.currentContext != null) {
                          debugPrint(
                              '[AppDrawer] navigatorKey.currentContext is available, showing dialog');
                          showDialog(
                            context: navigatorKey.currentContext!,
                            builder: (BuildContext dialogContext) {
                              debugPrint('[AppDrawer] Dialog builder called');
                              return const LanguageSwitcherDialog();
                            },
                            barrierDismissible: true,
                          );
                        } else {
                          debugPrint(
                              '[AppDrawer] ERROR: navigatorKey.currentContext is NULL!');
                        }
                      });
                    },
                  ).animate().fadeIn(delay: 815.ms).slideX(begin: -0.1),

                  _buildModernDrawerItem(
                    context,
                    icon: Icons.help_outline_rounded,
                    title: localizations?.helpAndSupport ?? 'Help & Support',
                    subtitle: localizations?.needHelp ?? 'Need help?',
                    color: Colors.blueGrey,
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navigate to help screen
                    },
                  ).animate().fadeIn(delay: 820.ms).slideX(begin: -0.1),

                  _buildModernDrawerItem(
                    context,
                    icon: Icons.star_rounded,
                    title: localizations?.rateApp ?? 'Rate the app',
                    subtitle:
                        localizations?.rateOnPlayStore ?? 'Rate on Play Store',
                    color: Colors.amber,
                    onTap: () {
                      Navigator.pop(context);
                      _openPlayStoreReview(context);
                    },
                  ).animate().fadeIn(delay: 830.ms).slideX(begin: -0.1),
                ],
              ),
            ),

            // Modern Logout Button
            _buildModernLogoutButton(context, ref, isDark)
                .animate()
                .fadeIn(delay: 900.ms)
                .slideY(begin: 0.1, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(
    BuildContext context,
    user,
    bool isDark,
    Color primaryColor,
  ) {
    // Try multiple possible field names for profile image
    final avatarUrl = user?.additionalData?['avatar'] as String?;
    final imgSrc = user?.additionalData?['img_src'] as String?;
    final profilePhotoPath =
        user?.additionalData?['profile_photo_path'] as String?;
    final imageUrl = avatarUrl ?? imgSrc ?? profilePhotoPath;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 28,
        left: 0,
        right: 0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor.withOpacity(0.85),
            primaryColor.withOpacity(0.75),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles in background
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          // Main content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar with modern design
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: imageUrl != null
                            ? CachedNetworkImageProvider(imageUrl)
                            : null,
                        child: imageUrl == null
                            ? (user?.name != null
                                ? Text(
                                    user!.name![0].toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 50,
                                    color: primaryColor,
                                  ))
                            : null,
                      ),
                      // Status indicator (optional - can be removed if not needed)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // User Name with better styling
                Text(
                  user?.name ?? 'Utilisateur',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // User Email with icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        user?.email ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // User Role Badge with modern design
                if (user != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getRoleIcon(user),
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getUserRole(user),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon(user) {
    if (user.isAdmin == 1) return Icons.admin_panel_settings_rounded;
    if (user.isDoctor == 1) return Icons.medical_services_rounded;
    if (user.isNurse == 1) return Icons.local_hospital_rounded;
    if (user.isReceptionist == 1) return Icons.receipt_long_rounded;
    if (user.isPharmacist == 1) return Icons.medication_rounded;
    if (user.isLabTechnician == 1) return Icons.science_rounded;
    if (user.isAccountant == 1) return Icons.calculate_rounded;
    if (user.isPatient == 1) return Icons.person_rounded;
    return Icons.person_outline_rounded;
  }

  Widget _buildSectionHeader(BuildContext context, String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildModernDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                // Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.grey.shade900,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white.withOpacity(0.6)
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Arrow Icon
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernLogoutButton(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50,
        border: Border(
          top: BorderSide(
            color:
                isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.shade600,
              Colors.red.shade700,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.pop(context);
              _showModernLogoutDialog(context, ref);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Déconnexion',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showModernLogoutDialog(BuildContext context, WidgetRef ref) {
    // Get the notifier before showing dialog to avoid ref disposal issues
    final authNotifier = ref.read(authProvider.notifier);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                'Déconnexion',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // Message
              Text(
                'Êtes-vous sûr de vouloir vous déconnecter ?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Annuler',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Close dialog
                        Navigator.pop(dialogContext);
                        // Call logout - navigation will be handled by listener
                        authNotifier.logout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Déconnexion',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getUserRole(user) {
    if (user.isAdmin == 1) return 'Administrateur';
    if (user.isDoctor == 1) return 'Médecin';
    if (user.isNurse == 1) return 'Infirmier(ère)';
    if (user.isReceptionist == 1) return 'Réceptionniste';
    if (user.isPharmacist == 1) return 'Pharmacien(ne)';
    if (user.isLabTechnician == 1) return 'Technicien(ne) Labo';
    if (user.isAccountant == 1) return 'Comptable';
    if (user.isPatient == 1) return 'Patient';
    return 'Utilisateur';
  }

  Future<void> _openPlayStoreReview(BuildContext context) async {
    const playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.nextpital.prodoc';
    final uri = Uri.parse(playStoreUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint('Error opening Play Store: $e');
      // Show error message to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Impossible d\'ouvrir le Play Store. Veuillez réessayer plus tard.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
