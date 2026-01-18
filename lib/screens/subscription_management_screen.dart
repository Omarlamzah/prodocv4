import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/subscription_model.dart';
import '../data/models/subscription_plan_model.dart';
import '../l10n/app_localizations.dart';
import '../providers/api_providers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/language_switcher.dart';

class SubscriptionManagementScreen extends ConsumerStatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  ConsumerState<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends ConsumerState<SubscriptionManagementScreen> {
  bool _loading = true;
  bool _processing = false;
  bool _showPlanSheet = false;
  String _actionType =
      'nouveau'; // 'nouveau' | 'mettre à niveau' | 'renouveler'

  List<SubscriptionModel> _subscriptions = [];
  List<SubscriptionPlanModel> _plans = [];
  String? _tenant;

  final List<String> _activeStatuses = const ['active', 'trialing'];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  SubscriptionModel? get _currentSub {
    if (_subscriptions.isEmpty) return null;
    final sorted = [..._subscriptions]..sort((a, b) =>
        (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return sorted.first;
  }

  bool get _hasActive => _subscriptions
      .any((s) => s.isActive && _activeStatuses.contains(s.status));

  bool get _canRenew {
    final current = _currentSub;
    if (current == null) return false;

    // Allow renewal if not active (expired/cancelled/suspended)
    if (!current.isActive &&
        ['cancelled', 'suspended', 'expired'].contains(current.status)) {
      return true;
    }

    // Allow renewal if active BUT expiring soon (<= 3 days)
    if (current.isActive && _activeStatuses.contains(current.status)) {
      final daysLeft = _daysLeft(current);
      return daysLeft != null && daysLeft <= 3;
    }

    return false;
  }

  int? _daysLeft(SubscriptionModel sub) {
    DateTime? endDate = sub.endsAt;
    if (sub.status == 'trialing' && sub.trialEndsAt != null) {
      endDate = sub.trialEndsAt;
    }
    if (endDate == null) return null;

    final now = DateTime.now();
    final timeDiff = endDate.difference(now);

    // Calculate days using ceil (round up) - same as React: Math.ceil(timeDiff / (1000 * 60 * 60 * 24))
    // Convert to hours first, then divide by 24 and round up
    final hoursDiff = timeDiff.inHours;
    final daysLeft = (hoursDiff / 24).ceil();

    return daysLeft >= 0 ? daysLeft : 0;
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    final service = ref.read(subscriptionServiceProvider);
    final subsResult = await service.getSubscriptions();
    final plansResult = await service.getPlans();

    if (!mounted) return;

    subsResult.when(
      success: (data) {
        _subscriptions = (data['subscriptions'] as List<SubscriptionModel>);
        _tenant = data['tenant']?.toString();
      },
      failure: (message) {
        _showSnack(message);
      },
    );

    plansResult.when(
      success: (plans) => _plans = plans,
      failure: (message) => _showSnack(message),
    );

    setState(() => _loading = false);
  }

  Future<void> _handleSubscribe(SubscriptionPlanModel plan) async {
    setState(() => _processing = true);
    final service = ref.read(subscriptionServiceProvider);
    // TODO: replace with deep link / universal link if available
    const returnUrl =
        'https://nextpital.com/dashboard/admin/subscription/success';
    const cancelUrl =
        'https://nextpital.com/dashboard/admin/subscription/cancel';

    final result = await service.createSubscription(
      planId: plan.id,
      returnUrl: returnUrl,
      cancelUrl: cancelUrl,
      isRenewal: _actionType == 'renouveler',
      isUpgrade: _actionType == 'mettre à niveau',
    );

    if (!mounted) return;

    result.when(
      success: (data) async {
        final approvalUrl = data['approval_url']?.toString();
        if (approvalUrl != null && approvalUrl.isNotEmpty) {
          // Open the PayPal approval URL in external browser
          try {
            final uri = Uri.parse(approvalUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              _showSnack(
                  'Impossible d\'ouvrir l\'URL de paiement. Veuillez réessayer.');
            }
          } catch (e) {
            _showSnack('Erreur lors de l\'ouverture de l\'URL de paiement: $e');
          }
        } else {
          // No approval URL - subscription might have been processed directly
          _showSnack('Abonnement traité avec succès.');
          await _fetchData();
        }
      },
      failure: (message) {
        // Show the actual error message from the server
        _showSnack(message);
      },
    );

    setState(() {
      _processing = false;
      _showPlanSheet = false;
    });
  }

  Future<void> _handleRenew() async {
    final current = _currentSub;
    if (current == null) {
      _showSnack('Aucun abonnement à renouveler');
      setState(() {
        _actionType = 'nouveau';
        _showPlanSheet = true;
      });
      return;
    }

    // Check days left to ensure renewal is allowed
    final daysLeft = _daysLeft(current);

    // Allow renewal if:
    // 1. Subscription is not active (expired/cancelled/suspended), OR
    // 2. Subscription is active but expires in <= 3 days
    final canRenewNow = !current.isActive ||
        (current.isActive &&
            _activeStatuses.contains(current.status) &&
            daysLeft != null &&
            daysLeft <= 3);

    if (!canRenewNow) {
      if (current.isActive && _activeStatuses.contains(current.status)) {
        if (daysLeft == null || daysLeft > 3) {
          _showSnack(
              'Vous ne pouvez renouveler que si l\'abonnement expire dans 3 jours ou moins. Jours restants: ${daysLeft ?? "N/A"}');
          return;
        }
      } else {
        _showSnack('Cet abonnement ne peut pas être renouvelé pour le moment');
        return;
      }
    }

    // Set renewal action type
    _actionType = 'renouveler';

    // Find the plan matching current subscription
    final plan = _plans.firstWhere(
      (p) => p.id.toString() == current.planId.toString(),
      orElse: () => SubscriptionPlanModel(
        id: current.planId.toString(),
        name: current.planName,
        price: current.planPrice,
        interval: current.planInterval,
        description: null,
      ),
    );

    // Proceed with renewal - this will send isRenewal: true to the server
    await _handleSubscribe(plan);
  }

  Future<void> _handleCancel(int id) async {
    setState(() => _processing = true);
    final service = ref.read(subscriptionServiceProvider);
    final result = await service.cancelSubscription(id);

    if (!mounted) return;

    result.when(
      success: (_) => _showSnack('Abonnement annulé'),
      failure: (message) => _showSnack(message),
    );
    setState(() => _processing = false);
    await _fetchData();
  }

  void _openPlans(String action) {
    setState(() {
      _actionType = action;
      _showPlanSheet = true;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildStatusChip(SubscriptionModel sub) {
    Color bg;
    Color fg;
    String label;
    if (_activeStatuses.contains(sub.status) && sub.isActive) {
      bg = Colors.green.shade100;
      fg = Colors.green.shade800;
      label = AppLocalizations.of(context)?.activeStatus ?? 'Actif';
    } else if (sub.status == 'cancelled' || sub.status == 'expired') {
      bg = Colors.red.shade100;
      fg = Colors.red.shade800;
      label = sub.status == 'expired'
          ? (AppLocalizations.of(context)?.expiredStatus ?? 'Expiré')
          : (AppLocalizations.of(context)?.cancelSubscription ?? 'Annulé');
    } else if (sub.status == 'suspended') {
      bg = Colors.yellow.shade100;
      fg = Colors.yellow.shade800;
      label = AppLocalizations.of(context)?.suspendedStatus ?? 'Suspendu';
    } else if (sub.status == 'pending') {
      bg = Colors.orange.shade100;
      fg = Colors.orange.shade800;
      label = AppLocalizations.of(context)?.pendingStatus ?? 'En attente';
    } else {
      bg = Colors.grey.shade200;
      fg = Colors.grey.shade800;
      label = sub.status;
    }
    return Chip(
      label: Text(label),
      backgroundColor: bg,
      labelStyle: TextStyle(color: fg),
    );
  }

  Widget _buildCurrentCard() {
    final current = _currentSub;
    if (current == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)?.noActiveSubscription ??
                    'Aucun abonnement',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)?.noActiveSubscriptionDesc ??
                    'Souscrivez à un plan pour activer les fonctionnalités premium.',
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _openPlans('nouveau'),
                child: Text(AppLocalizations.of(context)?.choosePlan ??
                    'Choisir un plan'),
              ),
            ],
          ),
        ),
      );
    }

    final daysLeft = _daysLeft(current);
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  current.planName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusChip(current),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              (AppLocalizations.of(context)?.pricePerInterval(
                      current.planPrice.toStringAsFixed(2),
                      current.planInterval)) ??
                  '${current.planPrice.toStringAsFixed(2)} / ${current.planInterval}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
                '${AppLocalizations.of(context)?.startDate ?? 'Début :'} ${_formatDate(current.startedAt)}'),
            Text(
                '${AppLocalizations.of(context)?.endDate ?? 'Fin :'} ${_formatDate(current.endsAt ?? current.trialEndsAt)}'),
            if (daysLeft != null && current.isActive)
              Text(
                AppLocalizations.of(context)?.daysLeft(daysLeft) ??
                    'Jours restants : $daysLeft',
                style: TextStyle(
                  color: daysLeft <= 7 ? Colors.red : Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 12),
            // Use Wrap to prevent overflow - buttons will wrap to next line if needed
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (current.isActive &&
                    _activeStatuses.contains(current.status))
                  OutlinedButton.icon(
                    onPressed:
                        _processing ? null : () => _handleCancel(current.id),
                    icon: const Icon(Icons.cancel),
                    label: Text(
                        AppLocalizations.of(context)?.cancelSubscription ??
                            'Annuler l\'abonnement'),
                  ),
                // Show renew button if can renew (expired/cancelled OR active but expiring in <= 3 days)
                if (_canRenew)
                  ElevatedButton.icon(
                    onPressed: _processing ? null : _handleRenew,
                    icon: const Icon(Icons.refresh),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    label: Text(
                      _processing
                          ? (AppLocalizations.of(context)?.loading ??
                              'Traitement...')
                          : (AppLocalizations.of(context)?.renewSamePlan ??
                              'Renouveler le même plan'),
                    ),
                  ),
                // Only show upgrade button if user doesn't have active subscription OR subscription expires in more than 3 days
                if (!_hasActive ||
                    (current.isActive &&
                        _activeStatuses.contains(current.status) &&
                        (_daysLeft(current) == null ||
                            (_daysLeft(current) ?? 0) > 3)))
                  ElevatedButton.icon(
                    onPressed: _processing
                        ? null
                        : () => _openPlans('mettre à niveau'),
                    icon: const Icon(Icons.upgrade),
                    label: Text(AppLocalizations.of(context)?.upgradePlan ??
                        'Mettre à niveau / changer'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  List<SubscriptionPlanModel> get _upgradePlans {
    final current = _currentSub;
    if (current == null) return _plans;
    return _plans
        .where((p) => p.id.toString() != current.planId.toString())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            localizations?.subscriptionsTitle ?? 'Gestion des abonnements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: localizations?.language ?? 'Language',
            onPressed: () => showLanguageSwitcher(context),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    localizations?.manageSubscriptionsFor(
                            _tenant ?? 'votre compte') ??
                        'Gérez vos abonnements pour ${_tenant ?? 'votre compte'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  if (!_hasActive)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizations?.noActiveSubscription ??
                                  'Aucun abonnement actif',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              localizations?.noActiveSubscriptionDesc ??
                                  'Votre abonnement est expiré ou inactif. Certaines fonctionnalités peuvent être limitées.',
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (_canRenew)
                                  ElevatedButton(
                                    onPressed:
                                        _processing ? null : _handleRenew,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green),
                                    child: Text(_processing
                                        ? (localizations?.loading ??
                                            'Traitement...')
                                        : (localizations?.renewSamePlan ??
                                            'Renouveler le même plan')),
                                  ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: _processing
                                      ? null
                                      : () => _openPlans('nouveau'),
                                  child: Text(localizations?.choosePlan ??
                                      'Choisir un plan'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  _buildCurrentCard(),
                  if (_subscriptions.length > 1) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Historique',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ..._subscriptions.skip(1).map(
                          (sub) => ListTile(
                            title: Text(sub.planName),
                            subtitle: Text(
                                '${localizations?.startDate ?? 'Début :'} ${_formatDate(sub.startedAt)}  -  ${localizations?.endDate ?? 'Fin :'} ${_formatDate(sub.endsAt ?? sub.trialEndsAt)}'),
                            trailing: _buildStatusChip(sub),
                          ),
                        ),
                  ],
                ],
              ),
            ),
      bottomSheet: _showPlanSheet
          ? _PlanSheet(
              actionType: _actionType,
              plans: _actionType == 'mettre à niveau' ? _upgradePlans : _plans,
              onClose: () => setState(() => _showPlanSheet = false),
              onSelect: _processing ? null : _handleSubscribe,
              processing: _processing,
            )
          : null,
    );
  }
}

class _PlanSheet extends StatelessWidget {
  const _PlanSheet({
    required this.actionType,
    required this.plans,
    required this.onClose,
    required this.onSelect,
    required this.processing,
  });

  final String actionType;
  final List<SubscriptionPlanModel> plans;
  final VoidCallback onClose;
  final void Function(SubscriptionPlanModel)? onSelect;
  final bool processing;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return FractionallySizedBox(
      heightFactor: 0.65,
      child: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    actionType == 'mettre à niveau'
                        ? (localizations?.upgradePlan ??
                            'Mettre à niveau / changer')
                        : (localizations?.choosePlan ?? 'Choisir un plan'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: plans.isEmpty
                    ? Center(
                        child: Text(
                            localizations?.noData ?? 'Aucun plan disponible'))
                    : ListView.separated(
                        itemCount: plans.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final plan = plans[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        plan.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 4),
                                      if ((plan.description ?? '').isNotEmpty)
                                        Text(
                                          plan.description ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.grey),
                                        ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${plan.price.toStringAsFixed(2)} / ${plan.interval}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 150,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      ElevatedButton(
                                        onPressed:
                                            processing || onSelect == null
                                                ? null
                                                : () => onSelect!(plan),
                                        child: Text(
                                          processing
                                              ? (localizations?.loading ??
                                                  'Traitement...')
                                              : (actionType == 'mettre à niveau'
                                                  ? (localizations
                                                          ?.upgradePlan ??
                                                      'Mettre à niveau / changer')
                                                  : (localizations
                                                          ?.choosePlan ??
                                                      'Souscrire')),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
