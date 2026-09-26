import 'package:flutter/material.dart';

class SafetyTipsPage extends StatefulWidget {
  const SafetyTipsPage({super.key});

  @override
  State<SafetyTipsPage> createState() => _SafetyTipsPageState();
}

class _SafetyTipsPageState extends State<SafetyTipsPage> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _categories = [
    'All',
    'Emergency',
    'Solo Travel',
    'Scams',
    'Zones & GPS',
    'Health',
    'Culture',
  ];

  static const List<Map<String, dynamic>> _safetyTips = [
    {
      'id': 'tip_1',
      'category': 'Emergency',
      'title': 'Emergency SOS & SafeTour Protocol',
      'summary': 'How to trigger emergency response and what happens next.',
      'icon': Icons.emergency_rounded,
      'color': Color(0xFFEF4444),
      'isCrucial': true,
      'points': [
        'Press the red SOS button on your SafeTour home screen for 3 seconds.',
        'Your exact GPS coordinates are instantly dispatched to nearby emergency response teams and your emergency contacts.',
        'If data connection is lost, SafeTour sends a cellular SMS fallback with your last known coordinates.',
        'National Emergency Helpline: 112 (Police, Fire, Ambulance).',
        'Tourist In Distress Helpline: 1363 (Toll-Free, 24/7 multi-lingual).',
      ],
    },
    {
      'id': 'tip_2',
      'category': 'Emergency',
      'title': 'What To Do If Lost Or Stranded',
      'summary': 'Immediate actions to take when separated from your group or lost.',
      'icon': Icons.wrong_location_rounded,
      'color': Color(0xFFEF4444),
      'isCrucial': true,
      'points': [
        'Stay calm and remain in a well-lit, populated public area (hotel lobby, metro station, reputable restaurant).',
        'Open the SafeTour Live Map to check nearby police stations, hospitals, or transit stops.',
        'Do not accept rides from unmarked private vehicles or aggressive strangers offering "shortcuts".',
        'Share your live location with a trusted family member or travel partner.',
      ],
    },
    {
      'id': 'tip_3',
      'category': 'Solo Travel',
      'title': 'Solo Traveler Night Precautions',
      'summary': 'Best practices for safe navigation after dark.',
      'icon': Icons.nightlight_round,
      'color': Color(0xFF6366F1),
      'isCrucial': false,
      'points': [
        'Plan evening transit before leaving your accommodation; use verified ride-hailing apps or pre-paid counters.',
        'Keep your phone battery above 30% before heading out at night; carry a power bank.',
        'Avoid dimly lit alleys or poorly populated riverbanks/monuments after closing hours.',
        'Keep your hotel address written on a card or saved offline on your phone.',
      ],
    },
    {
      'id': 'tip_4',
      'category': 'Solo Travel',
      'title': 'Digital Identity & Document Safety',
      'summary': 'Protecting your passport, ID, and valuables.',
      'icon': Icons.badge_outlined,
      'color': Color(0xFF6366F1),
      'isCrucial': false,
      'points': [
        'Use SafeTour Digital ID to carry a secure, blockchain-verified digital credential instead of carrying physical passports everywhere.',
        'Keep original passports and visas locked in the hotel safe; carry photocopies or digital copies.',
        'Never hand over your original passport to unofficial vendors or bike rental shops as a deposit.',
      ],
    },
    {
      'id': 'tip_5',
      'category': 'Scams',
      'title': 'Common Tourist Scams & How To Avoid Them',
      'summary': 'Recognizing fake guides, rigged meters, and distraction tricks.',
      'icon': Icons.gpp_bad_rounded,
      'color': Color(0xFFF59E0B),
      'isCrucial': false,
      'points': [
        'Closed Attraction Scam: If a driver or stranger claims a temple or monument is "closed for a festival today", verify with official gates before changing plans.',
        'Fake Tour Guides: Only hire authorized guides who possess government-issued ID badges.',
        'Unmetered Taxis: Always insist on using the meter or book via trusted ride-hailing apps with predetermined fares.',
        'Gem / Souvenir Export Scam: Politely decline strangers offering high-value gemstone "export" schemes.',
      ],
    },
    {
      'id': 'tip_6',
      'category': 'Scams',
      'title': 'ATM & Financial Transaction Safety',
      'summary': 'Protecting payment cards and cash withdrawals.',
      'icon': Icons.atm_rounded,
      'color': Color(0xFFF59E0B),
      'isCrucial': false,
      'points': [
        'Use ATMs physically attached to bank branches with security guards rather than isolated standalone machines.',
        'Inspect card slots for skimming attachments and cover the keypad with your hand while entering PINs.',
        'Avoid flashing large bundles of cash at public markets; carry multiple small currency notes.',
      ],
    },
    {
      'id': 'tip_7',
      'category': 'Zones & GPS',
      'title': 'Understanding SafeTour Safety Zones',
      'summary': 'How geofencing protects you from entering restricted or hazardous areas.',
      'icon': Icons.fmd_good_rounded,
      'color': Color(0xFF10B981),
      'isCrucial': false,
      'points': [
        '🟢 Green Zones: Verified safe tourist corridors with high security and emergency support.',
        '🟡 Yellow Zones: Cautionary zones (crowded markets, unverified trails) where extra alertness is advised.',
        '🔴 Red Zones: Restricted zones, wildlife reserves, steep cliff edges, or hazardous areas where entry triggers an instant safety alert.',
        'Ensure location permissions are set to "Always Allow" so background safety geofencing remains active.',
      ],
    },
    {
      'id': 'tip_8',
      'category': 'Health',
      'title': 'Drinking Water & Food Hygiene',
      'summary': 'Preventing traveler’s diarrhea and heat exhaustion.',
      'icon': Icons.water_drop_rounded,
      'color': Color(0xFF06B6D4),
      'isCrucial': false,
      'points': [
        'Drink only sealed bottled water or RO-purified water; verify the cap seal before purchase.',
        'Avoid tap water for drinking and brushing teeth in rural areas.',
        'Eat at busy eateries where food is cooked fresh and served piping hot.',
        'Carry oral rehydration salts (ORS) and stay hydrated, especially in tropical climates.',
      ],
    },
    {
      'id': 'tip_9',
      'category': 'Culture',
      'title': 'Sacred Site Etiquette & Local Laws',
      'summary': 'Respectful practices at temples, mosques, and heritage sites.',
      'icon': Icons.temple_hindu_rounded,
      'color': Color(0xFF8B5CF6),
      'isCrucial': false,
      'points': [
        'Remove footwear and headwear before entering temple or shrine sanctums.',
        'Dress modestly with shoulders and knees covered when visiting religious monuments.',
        'Always ask permission before photographing local residents, religious ceremonies, or military installations.',
        'Be respectful of local customs regarding drone usage; flying drones near heritage forts or airports without permits is strictly prohibited.',
      ],
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredTips {
    return _safetyTips.where((tip) {
      final matchesCategory = _selectedCategory == 'All' ||
          tip['category'].toString().toLowerCase() ==
              _selectedCategory.toLowerCase();
      final q = _searchQuery.trim().toLowerCase();
      if (q.isEmpty) return matchesCategory;

      final title = tip['title'].toString().toLowerCase();
      final summary = tip['summary'].toString().toLowerCase();
      final points = (tip['points'] as List<String>).join(' ').toLowerCase();

      final matchesQuery =
          title.contains(q) || summary.contains(q) || points.contains(q);

      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tips = _filteredTips;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Traveler Safety Tips',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              'Verified advice & emergency guidelines',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Emergency Helpline Quick Reference Bar
          _buildEmergencyBanner(context),

          // Search Field
          _buildSearchField(),

          // Category Selector Chips
          _buildCategoryFilter(),

          // Tips List
          Expanded(
            child: tips.isEmpty
                ? _buildEmptySearch()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: tips.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _TipCard(tip: tips[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_in_talk_rounded,
              color: Color(0xFFDC2626), size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Helplines',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF991B1B),
                  ),
                ),
                Text(
                  'Police: 112 / 100 • Ambulance: 108 • Tourist: 1363',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: const Text(
              '24/7 Live',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search safety advice, scams, emergency...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon:
                const Icon(Icons.search_rounded, color: Colors.black45, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded,
                        color: Colors.black45, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;

          return ChoiceChip(
            showCheckmark: false,
            label: Text(
              cat,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            selected: isSelected,
            selectedColor: const Color(0xFF4F46E5),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : Colors.grey.shade300,
              ),
            ),
            onSelected: (_) {
              setState(() {
                _selectedCategory = cat;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded,
                  size: 40, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 14),
            const Text(
              'No safety tips found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try clearing your search query or selecting "All" categories.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatefulWidget {
  final Map<String, dynamic> tip;

  const _TipCard({required this.tip});

  @override
  State<_TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<_TipCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final tip = widget.tip;
    final color = tip['color'] as Color;
    final isCrucial = tip['isCrucial'] as bool? ?? false;
    final points = tip['points'] as List<String>;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCrucial
            ? Border.all(color: const Color(0xFFFCA5A5), width: 1.2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(tip['icon'] as IconData,
                        color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tip['category'] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                            if (isCrucial) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFFCA5A5)),
                                ),
                                child: const Text(
                                  'PRIORITY',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tip['title'] as String,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.black45,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tip['summary'] as String,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                ...points.map(
                  (pt) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pt,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
