import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:convert';
import '../providers/tenant_website_providers.dart';
import '../data/models/tenant_website_model.dart';
import '../core/utils/result.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import '../core/config/api_constants.dart';
import '../l10n/app_localizations.dart';

class CabinetInfoScreen extends ConsumerWidget {
  const CabinetInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantWebsiteAsync = ref.watch(publicTenantWebsiteProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F23) : const Color(0xFFF0F2F5),
      body: tenantWebsiteAsync.when(
        data: (result) {
          if (result is Success<TenantWebsiteModel>) {
            return _buildContent(context, result.data, isDark, primaryColor);
          } else if (result is Failure<TenantWebsiteModel>) {
            return CustomErrorWidget(message: result.message);
          }
          return const CustomErrorWidget(message: 'Unknown error occurred');
        },
        loading: () => const LoadingWidget(),
        error: (error, _) => CustomErrorWidget(message: error.toString()),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TenantWebsiteModel website,
      bool isDark, Color primaryColor) {
    // Parse Colors
    Color? tenantPrimaryColor;
    if (website.parsedThemeColors != null &&
        website.parsedThemeColors!['primary'] != null) {
      try {
        final colorString = website.parsedThemeColors!['primary'] as String;
        tenantPrimaryColor =
            Color(int.parse(colorString.replaceAll('#', '0xFF')));
      } catch (e) {
        // ignore
      }
    }
    final effectiveColor = tenantPrimaryColor ?? primaryColor;

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context, website, isDark, effectiveColor),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, website, isDark, effectiveColor),
                const SizedBox(height: 24),
                _buildContactActions(context, website, effectiveColor, isDark),
                const SizedBox(height: 24),
                if (website.parsedSocialLinks != null &&
                    website.parsedSocialLinks!.isNotEmpty) ...[
                  _buildSocialLinks(
                      context, website.parsedSocialLinks!, effectiveColor, isDark),
                  const SizedBox(height: 24),
                ],
                if (website.contentBlocks != null &&
                    website.contentBlocks!['services'] != null) ...[
                  _buildServices(context, website.contentBlocks!['services'],
                      isDark, effectiveColor),
                  const SizedBox(height: 24),
                ],
                if (website.parsedWorkHours != null) ...[
                  _buildWorkingHours(context, website.parsedWorkHours!, isDark,
                      effectiveColor),
                  const SizedBox(height: 24),
                ],
                // Add padding at bottom
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(BuildContext context, TenantWebsiteModel website,
      bool isDark, Color primaryColor) {
    final heroImage = website.heroImagePath;
    final logo = website.logoPath;

    return SliverAppBar(
      expandedHeight: 250.0,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF0F0F23) : Colors.white,
      foregroundColor: isDark ? Colors.white : Colors.black,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (heroImage != null && heroImage.isNotEmpty)
              Builder(
                builder: (context) {
                  // Clean the path logic
                  String cleanPath = heroImage
                      .replaceAll(RegExp(r'\s+'), '')
                      .replaceAll('\n', '')
                      .replaceAll('\r', '')
                      .replaceAll('\t', '')
                      .replaceAll(' ', '')
                      .trim();

                  if (cleanPath.startsWith('/')) {
                    cleanPath = cleanPath.substring(1);
                  }

                  final storageBase = ApiConstants.storageBaseUrl.endsWith('/')
                      ? ApiConstants.storageBaseUrl.substring(0, ApiConstants.storageBaseUrl.length - 1)
                      : ApiConstants.storageBaseUrl;
                  
                  final imageUrl = cleanPath.startsWith('http')
                      ? cleanPath
                      : '$storageBase/storage/$cleanPath'.trim();

                  return CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: primaryColor.withOpacity(0.1),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: primaryColor.withOpacity(0.1),
                      child: Icon(Icons.image_not_supported,
                          size: 50, color: primaryColor.withOpacity(0.5)),
                    ),
                  );
                },
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      primaryColor.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Icon(Icons.local_hospital_rounded,
                    size: 80, color: Colors.white.withOpacity(0.3)),
              ),
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TenantWebsiteModel website,
      bool isDark, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (website.logoPath != null && website.logoPath!.isNotEmpty)
          Container(
            width: 100, // Slightly larger
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Builder(
                builder: (context) {
                  String cleanPath = website.logoPath!
                      .replaceAll(RegExp(r'\s+'), '')
                      .replaceAll('\n', '')
                      .replaceAll('\r', '')
                      .replaceAll('\t', '')
                      .replaceAll(' ', '')
                      .trim();

                  if (cleanPath.startsWith('/')) {
                    cleanPath = cleanPath.substring(1);
                  }

                  final storageBase = ApiConstants.storageBaseUrl.endsWith('/')
                      ? ApiConstants.storageBaseUrl.substring(0, ApiConstants.storageBaseUrl.length - 1)
                      : ApiConstants.storageBaseUrl;

                  final imageUrl = cleanPath.startsWith('http')
                      ? cleanPath
                      : '$storageBase/storage/$cleanPath'.trim();

                  return CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  );
                },
              ),
            ),
          )
        else
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.local_hospital, size: 50, color: primaryColor),
          ),
        const SizedBox(height: 16),
        Text(
          website.title ?? 'Clinic Name',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        if (website.contactAddress != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              if (website.googleMapsLocation != null) {
                _launchURL(website.googleMapsLocation!);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 16,
                      color: isDark ? Colors.white70 : Colors.grey[600]),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      website.contactAddress!,
                      style: TextStyle(
                        fontSize: 14,
                        color: (website.googleMapsLocation != null)
                            ? Colors.blue
                            : (isDark ? Colors.white70 : Colors.grey[600]),
                        decoration: (website.googleMapsLocation != null)
                            ? TextDecoration.underline
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (website.description != null && website.description!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              website.description!,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.grey[800],
              ),
            ),
          ),
        ],
      ],
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildContactActions(BuildContext context, TenantWebsiteModel website,
      Color color, bool isDark) {
    final localizations = AppLocalizations.of(context);

    // Prepare list of actions
    List<Widget> actions = [];

    // 1. Call
    if (website.contactPhone != null) {
      actions.add(_buildActionButton(
        context: context,
        icon: Icons.call,
        label: localizations?.call ?? 'Call',
        color: Colors.green,
        onTap: () => _launchURL('tel:${website.contactPhone}'),
        isDark: isDark,
      ));
    }

    // 2. Map
    if (website.googleMapsLocation != null) {
      actions.add(_buildActionButton(
        context: context,
        icon: Icons.map,
        label: localizations?.map ?? 'Map',
        color: Colors.orange,
        onTap: () => _launchURL(website.googleMapsLocation!),
        isDark: isDark,
      ));
    }

    // 3. WhatsApp
    if (website.contactPhone != null) {
      actions.add(_buildActionButton(
        context: context,
        icon: FontAwesomeIcons.whatsapp,
        label: 'WhatsApp',
        color: const Color(0xFF25D366),
        onTap: () {
          final phone = website.contactPhone!.replaceAll(RegExp(r'[^0-9]'), '');
          _launchURL('https://wa.me/$phone');
        },
        isDark: isDark,
      ));
    }

    // 4. Email
    if (website.contactEmail != null) {
      actions.add(_buildActionButton(
        context: context,
        icon: Icons.email_outlined,
        label: localizations?.email ?? 'Email',
        color: Colors.blue,
        onTap: () => _launchURL('mailto:${website.contactEmail}'),
        isDark: isDark,
      ));
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, constraints) {
      // Use GridView or Column of Rows
      return Column(
        children: [
          Row(
            children: [
              if (actions.isNotEmpty) Expanded(child: actions[0]),
              const SizedBox(width: 12),
              if (actions.length > 1)
                Expanded(child: actions[1])
              else
                const Spacer(),
            ],
          ),
          if (actions.length > 2) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: actions[2]),
                const SizedBox(width: 12),
                if (actions.length > 3)
                  Expanded(child: actions[3])
                else
                  const Spacer(),
              ],
            ),
          ],
        ],
      );
    }).animate().fadeIn(delay: 100.ms).slideX();
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLinks(BuildContext context, Map<String, dynamic> links,
      Color color, bool isDark) {
    final localizations = AppLocalizations.of(context);
    final validLinks = links.entries.where((e) => e.value != null && e.value != '#' && e.value.toString().isNotEmpty).toList();

    if (validLinks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations?.followUs ?? 'Follow Us',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: validLinks.map((entry) {
            final platform = entry.key.toLowerCase();
            final url = entry.value.toString();
            
            IconData icon;
            Color iconColor;

            switch (platform) {
              case 'facebook':
                icon = FontAwesomeIcons.facebook;
                iconColor = const Color(0xFF1877F2);
                break;
              case 'instagram':
                icon = FontAwesomeIcons.instagram;
                iconColor = const Color(0xFFE4405F);
                break;
              case 'linkedin':
                icon = FontAwesomeIcons.linkedin;
                iconColor = const Color(0xFF0A66C2);
                break;
              case 'twitter':
              case 'x':
                icon = FontAwesomeIcons.xTwitter;
                iconColor = isDark ? Colors.white : Colors.black;
                break;
              case 'youtube':
                icon = FontAwesomeIcons.youtube;
                iconColor = const Color(0xFFFF0000);
                break;
              default:
                icon = FontAwesomeIcons.globe;
                iconColor = color;
            }

            return InkWell(
              onTap: () => _launchURL(url),
              borderRadius: BorderRadius.circular(50),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                ),
                child: Center(
                  child: FaIcon(icon, color: iconColor, size: 24),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildServices(
      BuildContext context, dynamic servicesData, bool isDark, Color color) {
    final localizations = AppLocalizations.of(context);
    List<String> services = [];
    if (servicesData is List) {
      services = servicesData.map((e) => e.toString()).toList();
    }

    if (services.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations?.ourServices ?? 'Our Services',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: services.map((service) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? color.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color.withOpacity(0.3)),
                boxShadow: isDark ? null : [
                  BoxShadow(color: color.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Text(
                service,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildWorkingHours(BuildContext context, Map<String, dynamic> hours,
      bool isDark, Color color) {
    if (hours.isEmpty) return const SizedBox.shrink();

    final localizations = AppLocalizations.of(context);
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations?.workingHours ?? 'Working Hours',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
             boxShadow: isDark ? null : [
               BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
             ],
          ),
          child: Column(
            children: days.map((day) {
              final dayData = hours[day];
              String timeDisplay = localizations?.closed ?? 'Closed';
              bool isOpen = false;

              if (dayData != null && dayData is Map) {
                final open = dayData['open'];
                final close = dayData['close'];
                if (open != null && close != null) {
                  timeDisplay = '$open - $close';
                  isOpen = true;
                }
              }

              // Localize day name
              String dayName = day;
              switch (day) {
                case 'monday': dayName = localizations?.monday ?? 'Monday'; break;
                case 'tuesday': dayName = localizations?.tuesday ?? 'Tuesday'; break;
                case 'wednesday': dayName = localizations?.wednesday ?? 'Wednesday'; break;
                case 'thursday': dayName = localizations?.thursday ?? 'Thursday'; break;
                case 'friday': dayName = localizations?.friday ?? 'Friday'; break;
                case 'saturday': dayName = localizations?.saturday ?? 'Saturday'; break;
                case 'sunday': dayName = localizations?.sunday ?? 'Sunday'; break;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white70 : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      timeDisplay,
                      style: TextStyle(
                        fontSize: 15,
                        color: isOpen 
                            ? (isDark ? Colors.white : Colors.black87) 
                            : Colors.red.withOpacity(0.7),
                        fontWeight: isOpen ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // Handle error
      debugPrint('Could not launch $urlString');
    }
  }
}
