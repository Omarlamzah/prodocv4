import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/result.dart';
import '../data/models/appointment_model.dart';
import '../data/models/service_model.dart';
import '../providers/appointment_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/locale_providers.dart';
import '../providers/service_providers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/error_widget.dart';
import '../widgets/loading_widget.dart';
import '../l10n/app_localizations.dart';
import 'create_appointment_screen.dart';
import 'public_appointment_booking_screen.dart';
import 'doctor_calendar_screen.dart';
import '../data/models/time_slot_model.dart';
import '../providers/appointment_calendar_providers.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

// Helper extension to safely access localization strings
extension AppLocalizationsExtension on AppLocalizations? {
  // Helper method to safely get a string with fallback
  // This allows us to use keys that may not exist yet in AppLocalizations
  String getString(String key, String fallback) {
    if (this == null) return fallback;
    // For now, just return fallback since many keys don't exist yet
    // This will be replaced when keys are added to AppLocalizations
    return fallback;
  }
}

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedAppointments = <int>{};
  Timer? _debounce;

  String _searchTerm = '';
  String _statusFilter = 'all';
  String _priorityFilter = 'all';
  String _serviceFilter = 'all';
  String _timeFilter = 'day';
  bool _showStatistics = false;
  bool _showAdvancedFilters = false; // New: Collapsible advanced filters
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 1;
  bool _isGridView = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController
      _filtersController; // New: For filter expansion animation
  late Animation<double> _filtersAnimation;

  // Suggested Color Scheme for good UI/UX in medical/appointment app:
  // Primary: Calm blue for trust/actions (#1976D2)
  // Secondary: Soft green for success/completed (#388E3C)
  // Error: Red for warnings/cancelled (#D32F2F)
  // Background: Light neutral (#FAFAFA)
  // Surface: White (#FFFFFF)
  // OnPrimary: White text on primary (#FFFFFF)
  // These can be set in your ThemeData if not already.

  DateFormat _getDateFormatter() {
    final locale = ref.watch(localeProvider).locale;
    return DateFormat('dd MMM yyyy', locale.toString());
  }

  DateFormat _getDateTimeFormatter() {
    final locale = ref.watch(localeProvider).locale;
    return DateFormat('dd MMM yyyy HH:mm', locale.toString());
  }

  static final DateFormat _apiFormatter = DateFormat('yyyy-MM-dd');

  // Format date with relative time (like Next.js formatDateWithRelative)
  String _formatDateWithRelative(AppointmentModel appointment) {
    final localizations = AppLocalizations.of(context);
    if (appointment.appointmentDate == null ||
        appointment.appointmentTime == null) {
      return 'Unknown date';
    }

    try {
      final dateStr = appointment.appointmentDate!;
      final timeStr = appointment.appointmentTime!.substring(0, 5); // Get HH:mm
      final dateTimeStr = '$dateStr $timeStr:00';
      final appointmentDateTime = DateTime.parse(dateTimeStr);

      final formattedDate = _getDateTimeFormatter().format(appointmentDateTime);
      final now = DateTime.now();
      final difference = now.difference(appointmentDateTime);

      String relativeTime;
      final isFrench = ref.watch(localeProvider).locale.languageCode == 'fr';

      if (difference.inDays > 365) {
        final years = (difference.inDays / 365).floor();
        relativeTime = isFrench
            ? (years == 1 ? 'il y a 1 an' : 'il y a $years ans')
            : (years == 1 ? '1 year ago' : '$years years ago');
      } else if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        relativeTime = isFrench
            ? (months == 1 ? 'il y a 1 mois' : 'il y a $months mois')
            : (months == 1 ? '1 month ago' : '$months months ago');
      } else if (difference.inDays > 0) {
        relativeTime = isFrench
            ? (difference.inDays == 1
                ? 'il y a 1 jour'
                : 'il y a ${difference.inDays} jours')
            : (difference.inDays == 1
                ? '1 day ago'
                : '${difference.inDays} days ago');
      } else if (difference.inHours > 0) {
        relativeTime = isFrench
            ? (difference.inHours == 1
                ? 'il y a 1 heure'
                : 'il y a ${difference.inHours} heures')
            : (difference.inHours == 1
                ? '1 hour ago'
                : '${difference.inHours} hours ago');
      } else if (difference.inMinutes > 0) {
        relativeTime = isFrench
            ? (difference.inMinutes == 1
                ? 'il y a 1 minute'
                : 'il y a ${difference.inMinutes} minutes')
            : (difference.inMinutes == 1
                ? '1 minute ago'
                : '${difference.inMinutes} minutes ago');
      } else {
        relativeTime = isFrench ? 'à l\'instant' : 'just now';
      }

      // For future dates
      if (appointmentDateTime.isAfter(now)) {
        final futureDiff = appointmentDateTime.difference(now);
        if (futureDiff.inDays > 0) {
          relativeTime = isFrench
              ? (futureDiff.inDays == 1
                  ? 'dans 1 jour'
                  : 'dans ${futureDiff.inDays} jours')
              : (futureDiff.inDays == 1
                  ? 'in 1 day'
                  : 'in ${futureDiff.inDays} days');
        } else if (futureDiff.inHours > 0) {
          relativeTime = isFrench
              ? (futureDiff.inHours == 1
                  ? 'dans 1 heure'
                  : 'dans ${futureDiff.inHours} heures')
              : (futureDiff.inHours == 1
                  ? 'in 1 hour'
                  : 'in ${futureDiff.inHours} hours');
        } else {
          relativeTime = isFrench ? 'bientôt' : 'soon';
        }
      }

      return '$formattedDate ($relativeTime)';
    } catch (e) {
      final localizations = AppLocalizations.of(context);
      return localizations?.invalidDate ?? 'Invalid date';
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _filtersController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _filtersAnimation = CurvedAnimation(
      parent: _filtersController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animationController.dispose();
    _filtersController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  AppointmentsParams _currentParams() {
    return AppointmentsParams(
      page: _currentPage,
      search: _searchTerm.isEmpty ? null : _searchTerm,
      status: _statusFilter == 'all' ? null : _statusFilter,
      priority: _priorityFilter == 'all' ? null : _priorityFilter,
      startDate: _startDate != null ? _apiFormatter.format(_startDate!) : null,
      endDate: _endDate != null ? _apiFormatter.format(_endDate!) : null,
    );
  }

  Future<void> _refreshAppointments() async {
    await ref.refresh(appointmentsProvider(_currentParams()).future);
  }

  void _handleSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _searchTerm = value.trim();
          _currentPage = 1;
          _selectedAppointments.clear();
        });
      }
    });
  }

  void _resetFilters() {
    if (mounted) {
      setState(() {
        _searchController.clear();
        _searchTerm = '';
        _statusFilter = 'all';
        _priorityFilter = 'all';
        _serviceFilter = 'all';
        _timeFilter = 'day';
        _startDate = null;
        _endDate = null;
        _currentPage = 1;
        _selectedAppointments.clear();
      });
    }
  }

  void _toggleSelection(int? appointmentId) {
    if (appointmentId == null || !mounted) return;
    if (mounted) {
      setState(() {
        if (_selectedAppointments.contains(appointmentId)) {
          _selectedAppointments.remove(appointmentId);
        } else {
          _selectedAppointments.add(appointmentId);
        }
      });
    }
  }

  List<AppointmentModel> _applyClientFilters(
      List<AppointmentModel> appointments) {
    final now = DateTime.now();
    return appointments.where((appointment) {
      final serviceMatches = _serviceFilter == 'all' ||
          appointment.service?.id?.toString() == _serviceFilter;

      final localSearch = _searchTerm.toLowerCase();
      final matchesSearch = _searchTerm.isEmpty ||
          [
            appointment.patient?.user?.name,
            appointment.patient?.cniNumber,
            appointment.doctor?.user?.name,
            appointment.service?.title,
            appointment.notes,
            appointment.id?.toString(),
          ]
              .whereType<String>()
              .any((entry) => entry.toLowerCase().contains(localSearch));

      final appointmentDate = _parseAppointmentDate(appointment);

      bool matchesTime = true;
      if (_startDate != null || _endDate != null) {
        final start = _startDate ?? appointmentDate;
        final end = _endDate ?? appointmentDate;
        if (appointmentDate != null && start != null && end != null) {
          matchesTime =
              !appointmentDate.isBefore(start) && !appointmentDate.isAfter(end);
        }
      } else if (_timeFilter != 'all') {
        if (appointmentDate == null) {
          matchesTime = false;
        } else {
          switch (_timeFilter) {
            case 'day':
              matchesTime = appointmentDate.year == now.year &&
                  appointmentDate.month == now.month &&
                  appointmentDate.day == now.day;
              break;
            case 'week':
              final weekStart = now.subtract(Duration(days: now.weekday - 1));
              final weekEnd = weekStart.add(const Duration(days: 6));
              matchesTime = !appointmentDate.isBefore(weekStart) &&
                  !appointmentDate.isAfter(weekEnd);
              break;
            case 'month':
              matchesTime = appointmentDate.year == now.year &&
                  appointmentDate.month == now.month;
              break;
          }
        }
      }

      return serviceMatches && matchesSearch && matchesTime;
    }).toList()
      ..sort((a, b) {
        final dateA = _parseAppointmentDate(a) ?? DateTime(1900);
        final dateB = _parseAppointmentDate(b) ?? DateTime(1900);
        final comparison = dateB.compareTo(dateA);
        if (comparison != 0) return comparison;
        return (b.appointmentTime ?? '').compareTo(a.appointmentTime ?? '');
      });
  }

  DateTime? _parseAppointmentDate(AppointmentModel appointment) {
    if (appointment.appointmentDate == null) return null;
    try {
      return DateTime.parse(appointment.appointmentDate!);
    } catch (_) {
      return null;
    }
  }

  Map<String, int> _computeStatusCounts(List<AppointmentModel> appointments) {
    final counts = <String, int>{
      'scheduled': 0,
      'completed': 0,
      'cancelled': 0,
      'no_show': 0,
    };
    for (final appointment in appointments) {
      final status = appointment.status ?? 'scheduled';
      counts.update(status, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Map<String, int> _computePriorityCounts(List<AppointmentModel> appointments) {
    final counts = <String, int>{
      'high': 0,
      'medium': 0,
      'low': 0,
    };
    for (final appointment in appointments) {
      final priority = appointment.priority ?? 'medium';
      counts.update(priority, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    // Watch locale provider to rebuild when language changes
    ref.watch(localeProvider);
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final appointmentsAsync = ref.watch(appointmentsProvider(_currentParams()));
    final servicesAsync = ref.watch(servicesProvider);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600 && size.width < 900;
    final isDesktop = size.width >= 900;
    final isMobile = size.width < 600;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
      floatingActionButton: _buildModernFAB(context, authState),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(context, authState, isDesktop, isMobile),
            // Compact Filters Section
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
                  vertical: 8,
                ),
                child: _buildCompactFiltersCard(
                    context,
                    _extractServices(servicesAsync),
                    isDark,
                    isDesktop,
                    isTablet,
                    isMobile),
              ),
            ),
            // Advanced filters as collapsible section
            if (_showAdvancedFilters)
              SliverToBoxAdapter(
                child: SizeTransition(
                  sizeFactor: _filtersAnimation,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
                      vertical: 8,
                    ),
                    child: _buildAdvancedFiltersCard(
                        context,
                        _extractServices(servicesAsync),
                        isDark,
                        isDesktop,
                        isTablet,
                        isMobile),
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
              ),
              sliver: appointmentsAsync.when(
                data: (result) {
                  if (result is Failure<List<AppointmentModel>>) {
                    return SliverToBoxAdapter(
                      child: CustomErrorWidget(
                        message: result.message,
                        onRetry: _refreshAppointments,
                      ),
                    );
                  }
                  if (result is Success<List<AppointmentModel>>) {
                    final filteredAppointments =
                        _applyClientFilters(result.data);
                    return SliverMainAxisGroup(
                      slivers: [
                        if (_showStatistics)
                          SliverToBoxAdapter(
                            child: _buildStatisticsSection(
                                filteredAppointments, isDark, isDesktop),
                          ),
                        if (_selectedAppointments.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _buildSelectionToolbar(isDark),
                          ),
                        if (filteredAppointments.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody:
                                false, // Add this to prevent child scrolling issues
                            child: _buildEmptyState(isDark),
                          )
                        else
                          _buildAppointmentsList(
                            filteredAppointments,
                            isDesktop,
                            isTablet,
                            isMobile,
                          ),
                        SliverToBoxAdapter(
                          child: _buildPaginationControls(
                              result.data.isEmpty, isDesktop),
                        ),
                      ],
                    );
                  }
                  return const SliverFillRemaining(child: SizedBox.shrink());
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: LoadingWidget()),
                ),
                error: (error, stackTrace) => SliverToBoxAdapter(
                  child: CustomErrorWidget(
                    message: error.toString(),
                    onRetry: _refreshAppointments,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    AuthState authState,
    bool isDesktop,
    bool isMobile,
  ) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Text(
        localizations?.appointments ?? 'Appointments',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: [
        if (isDesktop)
          IconButton(
            icon: Icon(_isGridView
                ? Icons.view_list_rounded
                : Icons.grid_view_rounded),
            tooltip: _isGridView
                ? (localizations?.listView ?? 'List view')
                : (localizations?.gridView ?? 'Grid view'),
            onPressed: () {
              if (mounted) setState(() => _isGridView = !_isGridView);
            },
          ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: localizations?.refresh ?? 'Refresh',
          onPressed: _refreshAppointments,
        ),
      ],
    );
  }

  Widget _buildModernFAB(BuildContext context, AuthState authState) {
    final localizations = AppLocalizations.of(context);
    return FloatingActionButton.extended(
      onPressed: () => _showQuickActionsSheet(context, authState),
      label: Text(localizations?.quickActions ?? 'Quick Actions'),
      icon: const Icon(Icons.add_rounded),
      elevation: 4,
      backgroundColor: const Color(0xFF1976D2),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isDark ? const Color(0xFF1F1F25) : const Color(0xFFFFFFFF),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: const Color(0xFF1976D2)),
              const SizedBox(height: 6),
              Text(
                label,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickActionsSheet(BuildContext context, AuthState authState) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A1A2E).withOpacity(0.98)
              : Colors.white.withOpacity(0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor,
                          primaryColor.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.flash_on_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    localizations?.quickActions ?? 'Quick Actions',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Quick Actions Grid
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceEvenly,
                  children: [
                    // Nouveau Rendez-vous
                    if (authState.user?.isAdmin == 1 ||
                        authState.user?.isReceptionist == 1 ||
                        authState.user?.isPatient == 1)
                      _buildQuickActionCard(
                        context: ctx,
                        icon: Icons.add_circle_rounded,
                        title: localizations?.createAppointment ??
                            'New Appointment',
                        subtitle: localizations?.newAppointment ??
                            'Create appointment',
                        color: const Color(0xFF1976D2),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (authState.user?.isPatient == 1) {
                            Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const PublicAppointmentBookingScreen(),
                              ),
                            );
                          } else {
                            Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) => const CreateAppointmentScreen(),
                              ),
                            );
                          }
                        },
                      ),
                    // Calendrier
                    _buildQuickActionCard(
                      context: ctx,
                      icon: Icons.calendar_month_rounded,
                      title: localizations?.calendar ?? 'Calendar',
                      subtitle: localizations?.calendarView ?? 'View calendar',
                      color: const Color(0xFF388E3C),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => const CalendarScreen(),
                          ),
                        );
                      },
                    ),
                    // Filtres
                    _buildQuickActionCard(
                      context: ctx,
                      icon: Icons.filter_list_rounded,
                      title:
                          localizations?.advancedFilters ?? 'Advanced Filters',
                      subtitle: 'Show filters',
                      color: const Color(0xFFFF9800),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _showAdvancedFilters = !_showAdvancedFilters;
                          if (_showAdvancedFilters) {
                            _filtersController.forward();
                          } else {
                            _filtersController.reverse();
                          }
                        });
                      },
                    ),
                    // Statistiques
                    _buildQuickActionCard(
                      context: ctx,
                      icon: Icons.bar_chart_rounded,
                      title: localizations?.statistics ?? 'Statistics',
                      subtitle:
                          localizations?.viewStatistics ?? 'View statistics',
                      color: const Color(0xFF9C27B0),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _showStatistics = !_showStatistics);
                      },
                    ),
                    // Actualiser
                    _buildQuickActionCard(
                      context: ctx,
                      icon: Icons.refresh_rounded,
                      title: localizations?.refresh ?? 'Refresh',
                      subtitle: localizations?.refreshList ?? 'Refresh list',
                      color: Colors.grey[600]!,
                      onTap: () {
                        Navigator.pop(ctx);
                        _refreshAppointments();
                        final localizations = AppLocalizations.of(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(localizations?.listRefreshed ??
                                'List refreshed'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width =
        (MediaQuery.of(context).size.width - 52) / 2; // 2 columns with spacing

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.15),
                  color.withOpacity(0.05),
                  isDark ? const Color(0xFF1A1A2E) : Colors.white,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.white.withOpacity(0.6)
                        : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: (MediaQuery.of(context).size.width - 64) / 2 - 6,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Compact filters card - Simplified design
  Widget _buildCompactFiltersCard(
    BuildContext context,
    List<ServiceModel> services,
    bool isDark,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? const Color(0xFF15151C) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSearchField(context),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip(
                    context,
                    label: localizations?.all ?? 'All',
                    isSelected: _statusFilter == 'all',
                    onTap: () => _updateFilter('status', 'all'),
                  ),
                  _buildFilterChip(
                    context,
                    label: 'Scheduled',
                    isSelected: _statusFilter == 'scheduled',
                    onTap: () => _updateFilter('status', 'scheduled'),
                  ),
                  _buildFilterChip(
                    context,
                    label: 'Completed',
                    isSelected: _statusFilter == 'completed',
                    onTap: () => _updateFilter('status', 'completed'),
                  ),
                  _buildFilterChip(
                    context,
                    label: 'Cancelled',
                    isSelected: _statusFilter == 'cancelled',
                    onTap: () => _updateFilter('status', 'cancelled'),
                  ),
                  IconButton(
                    icon: Icon(
                      _showAdvancedFilters
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                    onPressed: () {
                      setState(() {
                        _showAdvancedFilters = !_showAdvancedFilters;
                        if (_showAdvancedFilters) {
                          _filtersController.forward();
                        } else {
                          _filtersController.reverse();
                        }
                      });
                    },
                    tooltip: _showAdvancedFilters
                        ? (localizations?.hideAdvancedFilters ??
                            'Hide advanced filters')
                        : (localizations?.showAdvancedFilters ??
                            'Show advanced filters'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Legacy method - keeping for compatibility
  Widget _buildBasicFiltersCard(
    BuildContext context,
    List<ServiceModel> services,
    bool isDark,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? const Color(0xFF15151C) : const Color(0xFFFFFFFF),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Filters',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search or quickly select a status'
                      'Search or quickly select a status',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(_showAdvancedFilters
                    ? Icons.expand_less
                    : Icons.expand_more),
                onPressed: () {
                  setState(() {
                    _showAdvancedFilters = !_showAdvancedFilters;
                    if (_showAdvancedFilters) {
                      _filtersController.forward();
                    } else {
                      _filtersController.reverse();
                    }
                  });
                },
                tooltip: _showAdvancedFilters
                    ? ('Hide advanced filters'
                        'Hide advanced filters')
                    : ('Show advanced filters'
                        'Show advanced filters'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSearchField(context),
          const SizedBox(height: 12),
          // Quick status chips instead of full dropdown for basic view
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildFilterChip(
                context,
                label: localizations?.all ?? 'All',
                isSelected: _statusFilter == 'all',
                onTap: () => _updateFilter('status', 'all'),
              ),
              _buildFilterChip(
                context,
                label: 'Scheduled',
                isSelected: _statusFilter == 'scheduled',
                onTap: () => _updateFilter('status', 'scheduled'),
              ),
              _buildFilterChip(
                context,
                label: 'Completed',
                isSelected: _statusFilter == 'completed',
                onTap: () => _updateFilter('status', 'completed'),
              ),
              _buildFilterChip(
                context,
                label: 'Cancelled',
                isSelected: _statusFilter == 'cancelled',
                onTap: () => _updateFilter('status', 'cancelled'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh),
                label: Text(localizations?.reset ?? 'Reset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2)
                      .withOpacity(0.15), // Suggested primary
                  foregroundColor: const Color(0xFF1976D2),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showComingSoon(
                    context,
                    'Export available soon.'
                    'Export available soon.'),
                icon: const Icon(Icons.download),
                label: Text('Export'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // New: Advanced filters in separate card
  Widget _buildAdvancedFiltersCard(
    BuildContext context,
    List<ServiceModel> services,
    bool isDark,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? const Color(0xFF1B1B22) : const Color(0xFFF6F7FB),
        border: Border.all(
            color:
                const Color(0xFF1976D2).withOpacity(0.1)), // Suggested primary
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advanced Filters',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1976D2), // Suggested primary
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          // Priority, Service, Time dropdowns
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterDropdown(
                context,
                label: localizations?.priority ?? 'Priority',
                value: _priorityFilter,
                items: [
                  DropdownMenuItem(
                      value: 'all', child: Text(localizations?.all ?? 'All')),
                  DropdownMenuItem(
                      value: 'high',
                      child: Text(localizations?.high ?? 'High')),
                  DropdownMenuItem(
                      value: 'medium',
                      child: Text(localizations?.medium ?? 'Medium')),
                  DropdownMenuItem(
                      value: 'low', child: Text(localizations?.low ?? 'Low')),
                ],
                onChanged: (value) => _updateFilter('priority', value ?? 'all'),
              ),
              _buildFilterDropdown(
                context,
                label: localizations?.services ?? 'Service',
                value: _serviceFilter,
                items: [
                  DropdownMenuItem(
                      value: 'all', child: Text(localizations?.all ?? 'All')),
                  ...services.map(
                    (service) => DropdownMenuItem(
                      value: service.id?.toString(),
                      child: Text(service.title ?? 'Service'),
                    ),
                  ),
                ],
                onChanged: (value) => _updateFilter('service', value ?? 'all'),
              ),
              _buildFilterDropdown(
                context,
                label: localizations?.period ?? 'Period',
                value: _timeFilter,
                enabled: _startDate == null && _endDate == null,
                items: [
                  DropdownMenuItem(
                      value: 'day',
                      child: Text(localizations?.today ?? 'Today')),
                  DropdownMenuItem(
                      value: 'week',
                      child: Text(localizations?.thisWeek ?? 'This Week')),
                  DropdownMenuItem(
                      value: 'month',
                      child: Text(localizations?.thisMonth ?? 'This Month')),
                  DropdownMenuItem(
                      value: 'all', child: Text(localizations?.all ?? 'All')),
                ],
                onChanged: (value) => _updateFilter('time', value ?? 'day'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Date pickers - Simplified layout
          Row(
            children: [
              Expanded(
                child: _buildDatePickerField(
                  context,
                  label: localizations?.start ?? 'Start',
                  date: _startDate,
                  onTap: _pickStartDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDatePickerField(
                  context,
                  label: localizations?.end ?? 'End',
                  date: _endDate,
                  onTap: _pickEndDate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // New helper: Update filter with page reset
  void _updateFilter(String type, String value) {
    if (!mounted) return;
    setState(() {
      switch (type) {
        case 'status':
          _statusFilter = value;
          break;
        case 'priority':
          _priorityFilter = value;
          break;
        case 'service':
          _serviceFilter = value;
          break;
        case 'time':
          _timeFilter = value;
          break;
      }
      _currentPage = 1;
      _selectedAppointments.clear();
    });
  }

  // New: Filter chip for quick selection - Smaller text
  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 10), // Smaller text as requested
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor:
          const Color(0xFF1976D2).withOpacity(0.1), // Suggested primary
      selectedColor: const Color(0xFF1976D2).withOpacity(0.2),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: localizations?.searchPatientDoctorService ??
            'Search patient, doctor, service...',
        prefixIcon: const Icon(Icons.search,
            color: Color(0xFF1976D2)), // Suggested primary
        suffixIcon: _searchTerm.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _handleSearchChanged('');
                },
              ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1F1F25) : const Color(0xFFF8F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF1976D2), // Suggested primary
            width: 2,
          ),
        ),
      ),
      onChanged: _handleSearchChanged,
    );
  }

  List<ServiceModel> _extractServices(
      AsyncValue<Result<List<ServiceModel>>> servicesAsync) {
    return servicesAsync.when(
      data: (result) {
        if (result is Success<List<ServiceModel>>) {
          return result.data;
        }
        return <ServiceModel>[];
      },
      loading: () => <ServiceModel>[],
      error: (_, __) => <ServiceModel>[],
    );
  }

  Widget _buildFilterDropdown(
    BuildContext context, {
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: MediaQuery.of(context).size.width > 720
          ? 160
          : double.infinity, // Slightly smaller
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1B22) : const Color(0xFFF6F7FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: value,
              onChanged: enabled ? onChanged : null,
              items: items,
              decoration: InputDecoration(
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF1B1B22) : const Color(0xFFF6F7FB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1976D2), // Suggested primary
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerField(
    BuildContext context, {
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark ? const Color(0xFF1B1B22) : const Color(0xFFF6F7FB),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    date == null
                        ? ('Select')
                        : _getDateFormatter().format(date),
                    style: TextStyle(
                      color: date == null
                          ? Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withOpacity(0.6)
                          : null,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1976D2), // Suggested primary
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
        _currentPage = 1;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1976D2), // Suggested primary
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
        if (_startDate != null && picked.isBefore(_startDate!)) {
          _startDate = picked;
        }
        _currentPage = 1;
      });
    }
  }

  Widget _buildStatisticsSection(
      List<AppointmentModel> appointments, bool isDark, bool isDesktop) {
    final localizations = AppLocalizations.of(context);
    final statusCounts = _computeStatusCounts(appointments);
    final priorityCounts = _computePriorityCounts(appointments);
    final total = appointments.length;

    Widget buildStatCard({
      required String label,
      required int value,
      required Color color,
    }) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? const Color(0xFF1B1B22) : const Color(0xFFFFFFFF),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  total == 0
                      ? '0%'
                      : '${((value / total) * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: color.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1976D2).withOpacity(0.1), // Suggested primary
            const Color(0xFF1976D2).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1976D2).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localizations?.quickStatistics ?? 'Quick Statistics',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              Switch.adaptive(
                value: _showStatistics,
                onChanged: (value) {
                  if (mounted) setState(() => _showStatistics = value);
                },
                activeColor: const Color(0xFF1976D2), // Suggested primary
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Responsive stats: Stack on mobile, row on desktop
          isDesktop
              ? Row(
                  children: [
                    Expanded(
                        child: buildStatCard(
                            label: localizations?.scheduled ?? 'Scheduled',
                            value: statusCounts['scheduled'] ?? 0,
                            color:
                                const Color(0xFF1976D2))), // Blue for scheduled
                    const SizedBox(width: 12),
                    Expanded(
                        child: buildStatCard(
                            label: localizations?.completed ?? 'Completed',
                            value: statusCounts['completed'] ?? 0,
                            color: const Color(
                                0xFF388E3C))), // Green for completed
                    const SizedBox(width: 12),
                    Expanded(
                        child: buildStatCard(
                            label: localizations?.cancelled ?? 'Cancelled',
                            value: statusCounts['cancelled'] ?? 0,
                            color:
                                const Color(0xFFD32F2F))), // Red for cancelled
                  ],
                )
              : Column(
                  children: [
                    buildStatCard(
                        label: localizations?.scheduled ?? 'Scheduled',
                        value: statusCounts['scheduled'] ?? 0,
                        color: const Color(0xFF1976D2)),
                    const SizedBox(height: 8),
                    buildStatCard(
                        label: localizations?.completed ?? 'Completed',
                        value: statusCounts['completed'] ?? 0,
                        color: const Color(0xFF388E3C)),
                    const SizedBox(height: 8),
                    buildStatCard(
                        label: localizations?.cancelled ?? 'Cancelled',
                        value: statusCounts['cancelled'] ?? 0,
                        color: const Color(0xFFD32F2F)),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildSelectionToolbar(bool isDark) {
    final localizations = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? const Color(0xFF1F1F25) : const Color(0xFFFFFFFF),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
              Expanded(
                child: Text(
                  '${_selectedAppointments.length} ${'selected'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  if (mounted) setState(() => _selectedAppointments.clear());
                },
                icon: const Icon(Icons.clear_all),
                label: Text(localizations?.clear ?? 'Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBulkStatusButton(
                context,
                label: localizations?.markAsCompleted ?? 'Mark as Completed',
                status: 'completed',
                color: const Color(0xFF388E3C),
                icon: Icons.check_circle_outline,
              ),
              _buildBulkStatusButton(
                context,
                label: localizations?.cancel ?? 'Cancel',
                status: 'cancelled',
                color: const Color(0xFFD32F2F),
                icon: Icons.cancel_outlined,
              ),
              _buildBulkStatusButton(
                context,
                label: localizations?.reschedule ?? 'Reschedule',
                status: 'scheduled',
                color: const Color(0xFF1976D2),
                icon: Icons.schedule,
              ),
              _buildBulkStatusButton(
                context,
                label: localizations?.noShow ?? 'No Show',
                status: 'no_show',
                color: Colors.grey,
                icon: Icons.person_off_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulkStatusButton(
    BuildContext context, {
    required String label,
    required String status,
    required Color color,
    required IconData icon,
  }) {
    return OutlinedButton.icon(
      onPressed: _selectedAppointments.isEmpty
          ? null
          : () => _handleBulkStatusUpdate(status),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: color),
        foregroundColor: color,
      ),
    );
  }

  Future<void> _handleBulkStatusUpdate(String status) async {
    if (_selectedAppointments.isEmpty) return;

    final localizations = AppLocalizations.of(context);
    final statusLabel = _statusLabel(status);
    final count = _selectedAppointments.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.confirmation ?? 'Confirm'),
        content: Text(
          '${localizations?.doYouWantToChangeStatusOf ?? 'Do you really want to change the status of'} $count ${localizations?.appointmentsTo ?? 'appointments to'} "$statusLabel"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'cancelled'
                  ? const Color(0xFFD32F2F)
                  : status == 'completed'
                      ? const Color(0xFF388E3C)
                      : const Color(0xFF1976D2),
            ),
            child: Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await ref.read(
        bulkUpdateAppointmentStatusProvider(
          BulkUpdateStatusParams(
            appointmentIds: _selectedAppointments.toList(),
            status: status,
          ),
        ).future,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      result.when(
        success: (data) {
          final updatedCount = data['updated_count'] as int? ?? 0;
          final failedCount = data['failed_count'] as int? ?? 0;

          final localizations = AppLocalizations.of(context);
          if (failedCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '$updatedCount ${localizations?.appointmentsUpdated ?? 'appointments updated'}, $failedCount ${localizations?.errorTitle ?? 'failed'}',
                ),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${localizations?.statusOfAppointmentsChanged ?? 'Status of'} $updatedCount ${localizations?.appointmentsTo ?? 'appointments changed to'} "$statusLabel"',
                ),
                backgroundColor: const Color(0xFF388E3C),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }

          // Clear selection and refresh
          if (mounted) {
            setState(() => _selectedAppointments.clear());
            _refreshAppointments();
          }
        },
        failure: (error) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${localizations?.error ?? 'Error'}: $error'),
              backgroundColor: const Color(0xFFD32F2F),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${localizations?.error ?? 'Error'}: ${e.toString()}'),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildAppointmentsList(
    List<AppointmentModel> appointments,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    if (isDesktop) {
      return _isGridView
          ? _buildAppointmentGrid(appointments, 2)
          : _buildAppointmentsTable(appointments);
    }
    if (isTablet) {
      return _buildAppointmentGrid(appointments, 1);
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final appointment = appointments[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildEnhancedAppointmentCard(
              context,
              appointment,
              Theme.of(context).brightness == Brightness.dark,
              _selectedAppointments.contains(appointment.id),
              index,
            ),
          );
        },
        childCount: appointments.length,
      ),
    );
  }

  Widget _buildAppointmentGrid(
      List<AppointmentModel> appointments, int crossAxisCount) {
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final appointment = appointments[index];
            return _buildEnhancedAppointmentCard(
              context,
              appointment,
              Theme.of(context).brightness == Brightness.dark,
              _selectedAppointments.contains(appointment.id),
              index,
            );
          },
          childCount: appointments.length,
        ),
      ),
    );
  }

  Widget _buildAppointmentsTable(List<AppointmentModel> appointments) {
    final localizations = AppLocalizations.of(context);
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[900]
              : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              const Color(0xFF1976D2).withOpacity(0.1), // Suggested primary
            ),
            columns: [
              DataColumn(
                label: Checkbox(
                  value: appointments.isNotEmpty &&
                      _selectedAppointments.length == appointments.length &&
                      appointments.every((appt) =>
                          appt.id != null &&
                          _selectedAppointments.contains(appt.id)),
                  onChanged: (value) {
                    if (mounted) {
                      setState(() {
                        if (value == true) {
                          _selectedAppointments.addAll(
                            appointments
                                .where((appt) => appt.id != null)
                                .map((appt) => appt.id!),
                          );
                        } else {
                          _selectedAppointments.removeAll(
                            appointments
                                .where((appt) => appt.id != null)
                                .map((appt) => appt.id!),
                          );
                        }
                      });
                    }
                  },
                ),
              ),
              DataColumn(
                  label: Text('ID',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(
                  label: Text(localizations?.patient ?? 'Patient',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(
                  label: Text('Doctor',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(
                  label: Text(localizations?.services ?? 'Service',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(
                  label: Text(localizations?.date ?? 'Date',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(
                  label: Text('Time',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(
                  label: Text('Status',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(
                  label: Text(localizations?.priority ?? 'Priority',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(
                  label: Text('Actions',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
            ],
            rows: appointments.map((appointment) {
              final dateWithRelative = _formatDateWithRelative(appointment);
              final timeLabel =
                  appointment.appointmentTime?.substring(0, 5) ?? '—';
              final statusColor = _getStatusColor(appointment.status);
              final priorityColor = _getPriorityColor(appointment.priority);
              final isSelected = appointment.id != null &&
                  _selectedAppointments.contains(appointment.id);
              return DataRow(
                selected: isSelected,
                onSelectChanged: (selected) {
                  if (appointment.id != null) {
                    _toggleSelection(appointment.id);
                  }
                },
                cells: [
                  DataCell(
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        if (appointment.id != null) {
                          _toggleSelection(appointment.id);
                        }
                      },
                    ),
                  ),
                  DataCell(Text(appointment.id?.toString() ?? '—',
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(
                      appointment.patient?.user?.name ??
                          (localizations?.unknown ?? 'Unknown'),
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(
                      appointment.doctor?.user?.name ??
                          (localizations?.unknown ?? 'Unknown'),
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(
                      appointment.service?.title ??
                          (localizations?.unknownService ?? 'Unknown service'),
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(dateWithRelative,
                      style: const TextStyle(fontSize: 11))),
                  DataCell(
                      Text(timeLabel, style: const TextStyle(fontSize: 12))),
                  DataCell(_buildStatusChip(
                      _statusLabel(appointment.status), statusColor)),
                  DataCell(_buildPriorityChip(
                      _priorityLabel(appointment.priority), priorityColor)),
                  DataCell(
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, size: 20),
                      onSelected: (value) =>
                          _handleTableAction(value, appointment),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              const Icon(Icons.visibility, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                  localizations?.viewDetails ?? 'View Details'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit, size: 18),
                              const SizedBox(width: 8),
                              Text(localizations?.edit ?? 'Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'completed',
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  size: 18, color: Color(0xFF388E3C)),
                              const SizedBox(width: 8),
                              Text(localizations?.markAsCompleted ??
                                  'Mark as Completed'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'cancelled',
                          child: Row(
                            children: [
                              const Icon(Icons.cancel,
                                  size: 18, color: Color(0xFFD32F2F)),
                              const SizedBox(width: 8),
                              Text(localizations?.cancel ?? 'Cancel'),
                            ],
                          ),
                        ),
                        if (appointment.status != 'completed' &&
                            appointment.status != 'cancelled' &&
                            appointment.id != null)
                          PopupMenuItem(
                            value: 'reminder',
                            child: Row(
                              children: [
                                const Icon(Icons.message_rounded,
                                    size: 18, color: Color(0xFF25D366)),
                                const SizedBox(width: 8),
                                Text(localizations?.sendWhatsAppReminder ??
                                    'Send WhatsApp Reminder'),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'prescriptions',
                          child: Row(
                            children: [
                              const Icon(Icons.description, size: 18),
                              const SizedBox(width: 8),
                              Text(localizations?.viewPrescriptions ??
                                  'View Prescriptions'),
                            ],
                          ),
                        ),
                        if (appointment.additionalData?['invoice'] != null)
                          PopupMenuItem(
                            value: 'invoice',
                            child: Row(
                              children: [
                                const Icon(Icons.receipt, size: 18),
                                const SizedBox(width: 8),
                                Text(localizations?.accessInvoice ??
                                    'Access Invoice'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedAppointmentCard(
    BuildContext context,
    AppointmentModel appointment,
    bool isDark,
    bool isSelected,
    int index,
  ) {
    final localizations = AppLocalizations.of(context);
    final appointmentDate = _parseAppointmentDate(appointment);
    final dateLabel = appointmentDate != null
        ? _getDateFormatter().format(appointmentDate)
        : (localizations?.unknownDate ?? 'Unknown date');
    final rawTime = appointment.appointmentTime ?? '';
    final timeLabel = rawTime.isEmpty
        ? '--'
        : rawTime.substring(0, rawTime.length >= 5 ? 5 : rawTime.length);

    final statusColor = _getStatusColor(appointment.status);
    final priorityColor = _getPriorityColor(appointment.priority);

    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOutBack, // Smoother animation
      builder: (context, double value, child) {
        // Clamp opacity to valid range
        final clampedOpacity = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: clampedOpacity,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - clampedOpacity)),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleSelection(appointment.id),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isSelected
                    ? [
                        const Color(0xFF1976D2).withOpacity(0.15),
                        const Color(0xFF1976D2).withOpacity(0.08),
                      ]
                    : isDark
                        ? [
                            const Color(0xFF1F1F25),
                            const Color(0xFF15151C),
                          ]
                        : [
                            Colors.white,
                            Colors.grey[50]!,
                          ],
              ),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1976D2)
                    : isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey[200]!.withOpacity(0.5),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFF1976D2).withOpacity(0.3)
                      : Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                  blurRadius: isSelected ? 20 : 15,
                  offset: const Offset(0, 8),
                  spreadRadius: isSelected ? 2 : 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (appointment.id != null)
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(appointment.id),
                          visualDensity:
                              VisualDensity.compact, // Smaller checkbox
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${localizations?.appointmentNumber ?? 'Appointment'} #${appointment.id ?? '—'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(
                          _statusLabel(appointment.status), statusColor),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Simplified info rows: Use ListView for better scrolling if needed, but keep wrap for now
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                          Icons.person_rounded,
                          appointment.patient?.user?.name ??
                              (localizations?.unknown ??
                                  'Unknown')), // Simplified to chips
                      _buildInfoChip(
                          Icons.local_hospital_rounded,
                          appointment.doctor?.user?.name ??
                              (localizations?.unknown ?? 'Unknown')),
                      _buildInfoChip(
                          Icons.medical_services_rounded,
                          appointment.service?.title ??
                              (localizations?.unknownService ??
                                  'Unknown service')),
                      _buildInfoChip(Icons.event, dateLabel),
                      _buildInfoChip(Icons.schedule_rounded, timeLabel),
                      _buildPriorityChip(
                          _priorityLabel(appointment.priority), priorityColor),
                    ],
                  ),
                  if ((appointment.notes ?? '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2)
                            .withOpacity(0.05), // Suggested primary
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notes_rounded,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(appointment.notes!,
                                  style: const TextStyle(fontSize: 12))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Actions: Horizontal scroll if many, but limit to 3-4 primary
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildActionButton(
                          icon: Icons.visibility_rounded,
                          label: localizations?.details ?? 'Details',
                          onTap: () => _showDetailsSheet(appointment),
                        ),
                        const SizedBox(width: 6),
                        _buildActionButton(
                          icon: Icons.edit_outlined,
                          label: localizations?.edit ?? 'Edit',
                          onTap: () => _handleEditAppointment(appointment),
                        ),
                        const SizedBox(width: 6),
                        _buildActionButton(
                          icon: Icons.receipt_long_rounded,
                          label: localizations?.invoice ?? 'Invoice',
                          onTap: () => _showComingSoon(
                              context,
                              'Billing coming soon.'
                              'Billing coming soon.'),
                          color: const Color(0xFF388E3C), // Suggested green
                        ),
                        if (appointment.status != 'completed' &&
                            appointment.status != 'cancelled' &&
                            appointment.id != null) ...[
                          const SizedBox(width: 6),
                          _buildActionButton(
                            icon: Icons.message_rounded,
                            label: localizations?.whatsApp ?? 'WhatsApp',
                            onTap: () =>
                                _handleSendWhatsAppReminder(appointment),
                            color: const Color(0xFF25D366), // WhatsApp green
                          ),
                        ],
                      ],
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

  // New: Simplified info chip
  Widget _buildInfoChip(IconData icon, String value) {
    if (value == '—' || value.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2).withOpacity(0.08), // Suggested primary
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1976D2)),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF388E3C); // Suggested green
      case 'cancelled':
        return const Color(0xFFD32F2F); // Suggested red
      case 'no_show':
        return Colors.grey;
      default:
        return const Color(0xFF1976D2); // Suggested blue
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'high':
        return const Color(0xFFD32F2F); // Suggested red
      case 'low':
        return const Color(0xFF388E3C); // Suggested green
      default:
        return Colors.orange;
    }
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: color != null
            ? BorderSide(color: color)
            : const BorderSide(color: Color(0xFF1976D2)),
        foregroundColor: color ?? const Color(0xFF1976D2),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final localizations = AppLocalizations.of(context);
    return Center(
      // <-- Now returns just the Center widget
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDark ? const Color(0xFF15151C) : const Color(0xFFFFFFFF),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                size: 64,
                color: const Color(0xFF1976D2).withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              localizations?.noAppointments ?? 'No Appointments',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 6),
            Text(
              localizations?.adjustYourFilters ??
                  'Adjust your filters or create a new one.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const CreateAppointmentScreen()),
                ),
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                    localizations?.createAppointment ?? 'Create Appointment'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls(bool isCurrentPageEmpty, bool isDesktop) {
    final localizations = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: _currentPage > 1
                ? () {
                    if (mounted) {
                      setState(() {
                        _currentPage -= 1;
                        _selectedAppointments.clear();
                      });
                    }
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
            label: Text(
                isDesktop
                    ? (localizations?.previous ?? 'Previous')
                    : (localizations?.previous ?? 'Prev.'),
                style: const TextStyle(fontSize: 12)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color:
                  const Color(0xFF1976D2).withOpacity(0.1), // Suggested primary
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${localizations?.page ?? 'Page'} $_currentPage',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF1976D2), // Suggested primary
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              if (isCurrentPageEmpty) {
                final localizations = AppLocalizations.of(context);
                _showComingSoon(
                    context, localizations?.endOfResults ?? 'End of results.');
                return;
              }
              if (mounted) {
                setState(() {
                  _currentPage += 1;
                  _selectedAppointments.clear();
                });
              }
            },
            icon: const Icon(Icons.chevron_right),
            label: Text(localizations?.next ?? 'Next',
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFFF9800), // Orange for info
      ),
    );
  }

  void _handleTableAction(String action, AppointmentModel appointment) {
    final localizations = AppLocalizations.of(context);
    switch (action) {
      case 'view':
        _showDetailsSheet(appointment);
        break;
      case 'edit':
        _handleEditAppointment(appointment);
        break;
      case 'completed':
        _handleSingleStatusUpdate(appointment, 'completed');
        break;
      case 'cancelled':
        _handleSingleStatusUpdate(appointment, 'cancelled');
        break;
      case 'reminder':
        _handleSendWhatsAppReminder(appointment);
        break;
      case 'prescriptions':
        final localizations = AppLocalizations.of(context);
        _showComingSoon(
            context,
            localizations?.viewPrescriptionsAvailableSoon ??
                'View prescriptions available soon.');
        break;
      case 'invoice':
        final localizations = AppLocalizations.of(context);
        _showComingSoon(
            context,
            localizations?.invoiceAccessAvailableSoon ??
                'Invoice access available soon.');
        break;
    }
  }

  Future<void> _handleSingleStatusUpdate(
      AppointmentModel appointment, String status) async {
    if (appointment.id == null) return;

    final localizations = AppLocalizations.of(context);
    final statusLabel = _statusLabel(status);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.confirmation ?? 'Confirm'),
        content: Text(
            '${localizations?.doYouWantToChangeStatus ?? 'Do you really want to change the status to'} "$statusLabel"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'cancelled'
                  ? const Color(0xFFD32F2F)
                  : status == 'completed'
                      ? const Color(0xFF388E3C)
                      : const Color(0xFF1976D2),
            ),
            child: Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await ref.read(
      updateAppointmentStatusProvider(
        UpdateStatusParams(
          appointmentId: appointment.id!,
          status: status,
        ),
      ).future,
    );

    if (!mounted) return;

    result.when(
      success: (_) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${localizations?.statusChangedTo ?? 'Status changed to'} "$statusLabel"'),
            backgroundColor: const Color(0xFF388E3C),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refreshAppointments();
      },
      failure: (error) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations?.error ?? 'Error'}: $error'),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  Future<void> _handleSendReminder(AppointmentModel appointment) async {
    if (appointment.id == null) return;

    final result = await ref.read(
      sendWhatsAppReminderProvider(appointment.id!).future,
    );

    if (!mounted) return;

    final localizations = AppLocalizations.of(context);
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Reminder sent to ${appointment.patient?.user?.name ?? 'the patient'} for appointment #${appointment.id}'
                'Reminder sent to ${appointment.patient?.user?.name ?? 'the patient'} for appointment #${appointment.id}'),
            backgroundColor: const Color(0xFF1976D2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations?.error ?? 'Error'}: $error'),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _showDetailsSheet(AppointmentModel appointment) {
    final localizations = AppLocalizations.of(context);
    final appointmentDate = _parseAppointmentDate(appointment);
    final isCompleted = appointment.status == 'completed';
    final isCancelled = appointment.status == 'cancelled';

    AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      animType: AnimType.scale,
      title: localizations?.appointmentDetails ?? 'Appointment Details',
      desc: '',
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: Color(0xFF1976D2), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${localizations?.appointmentNumber ?? 'Appointment'} #${appointment.id ?? '—'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Patient Information
              if (appointment.patient != null) ...[
                _buildDetailsRow(localizations?.patient ?? 'Patient',
                    appointment.patient?.user?.name ?? '—'),
                if (appointment.patient?.phone != null ||
                    appointment.patient?.phoneNumber != null)
                  _buildDetailsRow(
                      localizations?.phone ?? 'Phone',
                      appointment.patient?.phoneNumber ??
                          appointment.patient?.phone ??
                          '—'),
                if (appointment.patient?.user?.email != null)
                  _buildDetailsRow(localizations?.email ?? 'Email',
                      appointment.patient?.user?.email ?? '—'),
                if (appointment.patient?.cniNumber != null)
                  _buildDetailsRow(
                      'CNI', appointment.patient?.cniNumber ?? '—'),
              ],
              const Divider(height: 24),
              // Doctor Information
              if (appointment.doctor != null) ...[
                _buildDetailsRow(localizations?.doctor ?? 'Doctor',
                    appointment.doctor?.user?.name ?? '—'),
                if (appointment.doctor?.user?.email != null)
                  _buildDetailsRow(localizations?.doctorEmail ?? 'Doctor Email',
                      appointment.doctor?.user?.email ?? '—'),
              ],
              const Divider(height: 24),
              // Service Information
              _buildDetailsRow(localizations?.services ?? 'Service',
                  appointment.service?.title ?? '—'),
              // Appointment Date/Time
              _buildDetailsRow(
                  localizations?.date ?? 'Date',
                  appointmentDate != null
                      ? _getDateFormatter().format(appointmentDate)
                      : '—'),
              _buildDetailsRow(localizations?.time ?? 'Time',
                  appointment.appointmentTime ?? '—'),
              // Status and Priority
              _buildDetailsRow(localizations?.status ?? 'Status',
                  _statusLabel(appointment.status)),
              _buildDetailsRow(localizations?.priority ?? 'Priority',
                  _priorityLabel(appointment.priority)),
              const Divider(height: 24),
              // Additional Information
              if (appointment.createdAt != null)
                _buildDetailsRow(
                    localizations?.createdAt ?? 'Created At',
                    DateFormat('dd MMM yyyy HH:mm',
                            ref.watch(localeProvider).locale.toString())
                        .format(appointment.createdAt!)),
              if (appointment.updatedAt != null)
                _buildDetailsRow(
                    localizations?.updatedAt ?? 'Updated At',
                    DateFormat('dd MMM yyyy HH:mm',
                            ref.watch(localeProvider).locale.toString())
                        .format(appointment.updatedAt!)),
              if ((appointment.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDetailsRow(
                    localizations?.notes ?? 'Notes', appointment.notes!),
              ],
            ],
          ),
        ),
      ),
      btnOkText: localizations?.close ?? 'Close',
      btnOkColor: const Color(0xFF1976D2),
      btnOkOnPress: () {},
      // Add WhatsApp button as cancel button (second button)
      btnCancelText: !isCompleted && !isCancelled && appointment.id != null
          ? (localizations?.sendWhatsAppReminder ?? 'Send WhatsApp Reminder')
          : null,
      btnCancelColor: const Color(0xFF25D366),
      btnCancelIcon: !isCompleted && !isCancelled && appointment.id != null
          ? Icons.message_rounded
          : null,
      btnCancelOnPress: !isCompleted && !isCancelled && appointment.id != null
          ? () {
              // Close details dialog first
              Navigator.of(context).pop();
              // Then call the handler
              _handleSendWhatsAppReminder(appointment);
            }
          : null,
    ).show();
  }

  Future<void> _handleSendWhatsAppReminder(AppointmentModel appointment) async {
    if (appointment.id == null || !mounted) return;

    final patientName = appointment.patient?.user?.name ?? 'ce patient';

    // Wait a moment to ensure previous dialog is closed
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    // Show confirmation dialog using the root navigator to stay on current screen
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text('Send WhatsApp Reminder'),
          content: Text('Send WhatsApp reminder to $patientName?'
              'Send WhatsApp reminder to $patientName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(localizations?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366), // WhatsApp green
              ),
              child: Text(localizations?.sendResetLink ?? 'Send'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    // Show loading
    final localizations = AppLocalizations.of(context);
    AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      animType: AnimType.scale,
      title: localizations?.sending ?? 'Sending...',
      desc: localizations?.sendingWhatsAppReminder ??
          'Sending WhatsApp reminder...',
      dismissOnTouchOutside: false,
    ).show();

    final result = await ref.read(
      sendWhatsAppReminderProvider(appointment.id!).future,
    );

    // Close loading dialog - only pop if we can
    if (mounted) {
      final navigator = Navigator.of(context, rootNavigator: false);
      if (navigator.canPop()) {
        navigator.pop();
      }
    }

    if (!mounted) return;

    result.when(
      success: (_) {
        if (!mounted) return;
        final localizations = AppLocalizations.of(context);
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          title: localizations?.success ?? 'Success',
          desc: localizations?.whatsAppReminderSentSuccessfully ??
              'WhatsApp reminder sent successfully!',
          btnOkText: 'OK',
          btnOkColor: Colors.green,
          btnOkOnPress: () {},
        ).show();
      },
      failure: (error) {
        if (!mounted) return;
        final localizations = AppLocalizations.of(context);
        String errorMessage = localizations?.failedToSendWhatsAppReminder ??
            'Failed to send WhatsApp reminder. Please try again.';

        if (error.contains('Daily message limit') || error.contains('429')) {
          errorMessage = localizations?.dailyMessageLimitReached ??
              'Daily message limit reached. Please try again tomorrow.';
        } else if (error.isNotEmpty) {
          errorMessage = error;
        }

        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.scale,
          title: localizations?.error ?? 'Error',
          desc: errorMessage,
          btnOkText: 'OK',
          btnOkColor: Colors.red,
          btnOkOnPress: () {},
        ).show();
      },
    );
  }

  Widget _buildDetailsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                  fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String? status) {
    final localizations = AppLocalizations.of(context);
    switch (status) {
      case 'completed':
        return localizations?.completed ?? 'Completed';
      case 'cancelled':
        return localizations?.cancelled ?? 'Cancelled';
      case 'no_show':
        return localizations?.noShow ?? 'No Show';
      case 'scheduled':
      default:
        return localizations?.scheduled ?? 'Scheduled';
    }
  }

  String _priorityLabel(String? priority) {
    final localizations = AppLocalizations.of(context);
    switch (priority) {
      case 'high':
        return localizations?.high ?? 'High';
      case 'low':
        return localizations?.low ?? 'Low';
      case 'medium':
      default:
        return localizations?.medium ?? 'Medium';
    }
  }

  void _handleEditAppointment(AppointmentModel appointment) {
    final localizations = AppLocalizations.of(context);
    if (appointment.id == null || appointment.doctor?.id == null) {
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations?.cannotEditAppointment ??
              'Cannot edit this appointment'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    DateTime selectedDate = appointment.appointmentDate != null
        ? DateTime.parse(appointment.appointmentDate!)
        : DateTime.now();
    String selectedTime = _formatTime(appointment.appointmentTime);
    final doctorId = appointment.doctor!.id!;

    showDialog(
      context: context,
      builder: (context) => _EditAppointmentDialog(
        appointment: appointment,
        initialDate: selectedDate,
        initialTime: selectedTime,
        doctorId: doctorId,
        onUpdate: (date, time) async {
          final formattedDate = DateFormat('yyyy-MM-dd').format(date);
          String formattedTime = time;
          if (formattedTime.contains(':') &&
              formattedTime.split(':').length == 3) {
            final parts = formattedTime.split(':');
            formattedTime = '${parts[0]}:${parts[1]}';
          }
          if (!RegExp(r'^([0-1][0-9]|2[0-3]):[0-5][0-9]$')
              .hasMatch(formattedTime)) {
            formattedTime = _formatTime(time);
          }

          final appointmentData = <String, dynamic>{
            'doctor_id': doctorId.toString(),
            'appointment_date': formattedDate,
            'appointment_time': formattedTime,
            'priority': appointment.priority ?? 'medium',
            'status': appointment.status ?? 'scheduled',
            'notes': appointment.notes,
            'service_id': appointment.service?.id?.toString(),
            'patient_id': appointment.patient?.id,
          };

          final result = await ref.read(
            updateAppointmentProvider(
              UpdateAppointmentParams(
                appointmentId: appointment.id!,
                appointmentData: appointmentData,
              ),
            ).future,
          );

          result.when(
            success: (_) {
              final localizations = AppLocalizations.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(localizations?.appointmentUpdatedSuccessfully ??
                      'Appointment updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              _refreshAppointments();
            },
            failure: (error) {
              final localizations = AppLocalizations.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${localizations?.error ?? 'Error'}: $error'),
                  backgroundColor: Colors.red,
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null) return '00:00';
    try {
      if (time.contains(':') && time.split(':').length == 3) {
        final parts = time.split(':');
        return '${parts[0]}:${parts[1]}';
      }
      return time;
    } catch (e) {
      return '00:00';
    }
  }
}

// Edit Appointment Dialog Widget
class _EditAppointmentDialog extends ConsumerStatefulWidget {
  final AppointmentModel appointment;
  final DateTime initialDate;
  final String initialTime;
  final int doctorId;
  final Function(DateTime date, String time) onUpdate;

  const _EditAppointmentDialog({
    required this.appointment,
    required this.initialDate,
    required this.initialTime,
    required this.doctorId,
    required this.onUpdate,
  });

  @override
  ConsumerState<_EditAppointmentDialog> createState() =>
      _EditAppointmentDialogState();
}

class _EditAppointmentDialogState
    extends ConsumerState<_EditAppointmentDialog> {
  late DateTime _selectedDate;
  String? _selectedTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _selectedTime = widget.initialTime;
  }

  Future<void> _selectDate(BuildContext context) async {
    final locale = ref.watch(localeProvider).locale;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: locale,
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
      });
    }
  }

  String _normalizeTime(String time) {
    if (time.contains(':') && time.split(':').length == 3) {
      final parts = time.split(':');
      return '${parts[0]}:${parts[1]}';
    }
    if (RegExp(r'^([0-1][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(time)) {
      return time;
    }
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        final hour = parts[0].padLeft(2, '0');
        final minute = parts[1].padLeft(2, '0');
        return '$hour:$minute';
      }
    } catch (e) {
      // If parsing fails, return default
    }
    return '09:00';
  }

  Future<void> _handleSave() async {
    if (_selectedTime == null || _selectedTime!.isEmpty) {
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(localizations?.pleaseSelectTime ?? 'Please select a time'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final normalizedTime = _normalizeTime(_selectedTime!);
    await widget.onUpdate(_selectedDate, normalizedTime);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final timeSlotsAsync = ref.watch(
      timeSlotsProvider(
        TimeSlotsParams(
          doctorId: widget.doctorId,
          date: formattedDate,
        ),
      ),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations?.editAppointment ?? 'Edit Appointment',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.appointment.patient?.user?.name ?? 'Inconnu',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                final locale = ref.watch(localeProvider).locale;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations?.date ?? 'Date',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.grey[300]!,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                DateFormat(
                                        'EEEE d MMMM yyyy', locale.toString())
                                    .format(_selectedDate),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down_rounded),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations?.time ?? 'Time',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            timeSlotsAsync.when(
              data: (result) => result.when(
                success: (timeSlots) {
                  if (timeSlots.isEmpty) {
                    final localizations = AppLocalizations.of(context);
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Text(
                        localizations?.noTimeSlotsAvailable ??
                            'No time slots available for this date',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    );
                  }

                  final availableSlots =
                      timeSlots.where((slot) => slot.available).toList();

                  if (_selectedTime != null &&
                      !availableSlots
                          .any((slot) => slot.time == _selectedTime)) {
                    availableSlots.add(TimeSlotModel(
                      time: _selectedTime!,
                      available: true,
                    ));
                    availableSlots.sort((a, b) => a.time.compareTo(b.time));
                  }

                  return Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: availableSlots.isEmpty
                        ? Builder(
                            builder: (context) {
                              final localizations =
                                  AppLocalizations.of(context);
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                    localizations?.noTimeSlotsAvailableShort ??
                                        'No time slots available'),
                              );
                            },
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: availableSlots.length,
                            itemBuilder: (context, index) {
                              final slot = availableSlots[index];
                              final isSelected = _selectedTime == slot.time;
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedTime = slot.time;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.1)
                                        : Colors.transparent,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.05)
                                            : Colors.grey[200]!,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.radio_button_checked_rounded
                                            : Icons
                                                .radio_button_unchecked_rounded,
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        slot.time,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  );
                },
                failure: (error) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Erreur: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  'Erreur: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(localizations?.cancel ?? 'Cancel'),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(localizations?.save ?? 'Save'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
