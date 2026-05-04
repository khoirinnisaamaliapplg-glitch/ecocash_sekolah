import 'package:flutter/material.dart';

class RefundsScreen extends StatefulWidget {
  const RefundsScreen({super.key});

  @override
  State<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends State<RefundsScreen> {
  final List<Map<String, dynamic>> _monthlyRecap = [
    {
      'month': 'May',
      'location': 'Henley Community C...',
      'amount': 'Rp 100.000',
      'status': 'Paid Out',
      'isExpanded': true,
    },
    {
      'month': 'April',
      'location': 'Henley Community C...',
      'amount': 'Rp 75.000',
      'status': 'Paid Out',
      'isExpanded': false,
    },
    {
      'month': 'March',
      'location': 'Henley Community C...',
      'amount': 'Rp 120.000',
      'status': 'Paid Out',
      'isExpanded': false,
    },
    {
      'month': 'February',
      'location': 'Henley Community C...',
      'amount': 'Rp 90.000',
      'status': 'Paid Out',
      'isExpanded': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            // Ditambah sedikit karena card sekarang lebih besar
            const SizedBox(height: 140), 
            _buildRecapList(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildRecapList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18), // Padding header list lebih besar
              decoration: const BoxDecoration(
                color: Color(0xFFFFD966),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: const [
                  Icon(Icons.calendar_month, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Recap Monthly',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            ListView.separated(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _monthlyRecap.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _monthlyRecap[index];
                return Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: item['isExpanded'],
                    onExpansionChanged: (val) => setState(() => item['isExpanded'] = val),
                    leading: Image.asset(
                      'assets/icons/recycle.png', // Tetap sama
                      width: 35,
                      height: 35,
                    ),
                    title: Text(
                      item['month'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Text(
                      'Recycled at ${item['location']}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    trailing: Icon(
                      item['isExpanded'] ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 28,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(72, 0, 20, 25),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['amount'],
                              style: const TextStyle(
                                color: Color(0xFF107569),
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF107569)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                item['status'],
                                style: const TextStyle(
                                  color: Color(0xFF107569),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 300, // Header sedikit lebih tinggi
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg2.png'),
              fit: BoxFit.cover,
            ),
          ),
          padding: const EdgeInsets.only(top: 60, left: 20),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Back',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -110, // Disesuaikan karena card lebih besar
          left: 15,
          right: 15,
          child: _buildBalanceCard(),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(25), // Padding diperbesar agar card lebih besar
        child: Column(
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/icons/mingcute.png', // Tetap sama
                  width: 45,
                  height: 45,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Refunds',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Image.asset('assets/icons/share.png', width: 45, height: 45), // Tetap sama
              ],
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                _buildInfoBox('Available balance', 'Rp. 0', const Color(0xFFE6F9E6)),
                const SizedBox(width: 10),
                _buildInfoBox('Total paid out', 'Rp. 0', const Color(0xFFE6F2FA)),
                const SizedBox(width: 10),
                _buildInfoBox('Total earnings', 'Rp. 0', const Color(0xFFFFF9E6)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(String title, String value, Color color) {
    return Expanded(
      child: Container(
        height: 70, // Tinggi box info diperbesar
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}