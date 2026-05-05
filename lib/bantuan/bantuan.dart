import 'package:flutter/material.dart';

class DonationPage extends StatefulWidget {
  const DonationPage({super.key});

  @override
  State<DonationPage> createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage> {
  // Status aktif untuk toggle menu
  bool isBrowseActive = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header dengan Background Image dan Toggle Button
            _buildHeader(context),

            // Konten Body
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(
                    height: 40,
                  ), // Jarak disesuaikan agar konten tidak tertutup toggle
                  _buildSearchAndFilter(),
                  const SizedBox(height: 25),
                  _buildCategoryTabs(),
                  const SizedBox(height: 25),

                  // Daftar Donasi
                  _buildDonationCard(
                    title: "Bantuan Korban Banjir Aceh",
                    foundation: "Aceh Heritage Foundation",
                    target: "10m",
                    progress: 1.0,
                    donations: "189 Donations",
                    isClosed: true,
                    progressColor: Colors.redAccent,
                  ),
                  const SizedBox(height: 20),
                  _buildDonationCard(
                    title: "Bantuan Korban Banjir Aceh",
                    foundation: "Ideas Edvolution",
                    target: "5m",
                    progress: 0.63,
                    donations: "143 Donations",
                    isClosed: false,
                    progressColor: const Color(0xFF28A745),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior:
          Clip.none, // Penting agar widget yang melayang tidak terpotong
      children: [
        Container(
          height: 320,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg.png'),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const Text(
                      'Bantuan Sosial',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // TOMBOL TOGGLE (My Donation & Browse Charities)
        // Kita letakkan di atas Balance Card
        Positioned(
          bottom:
              85, // Sesuaikan jarak ini agar berada tepat di atas Balance Card
          left: 20,
          right: 20,
          child: Container(
            height: 55,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildToggleItem("My Donation", !isBrowseActive, () {
                  setState(() => isBrowseActive = false);
                }),
                _buildToggleItem("Browse Charities", isBrowseActive, () {
                  setState(() => isBrowseActive = true);
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Fungsi helper untuk item toggle agar bisa diklik
  Widget _buildToggleItem(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.black : Colors.grey[600],
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: "Search for charity campa...",
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.tune, size: 18, color: Colors.black87),
              SizedBox(width: 8),
              Text(
                "Filter & Sort",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _categoryItem(
          "Latest",
          Icons.watch_later,
          const Color(0xFFE1F5FE),
          Colors.lightBlue,
        ),
        _categoryItem(
          "Urgent",
          Icons.notifications_active_outlined,
          Colors.transparent,
          Colors.blue,
        ),
        _categoryItem(
          "Top Donate",
          Icons.emoji_events_outlined,
          Colors.transparent,
          Colors.blue,
        ),
      ],
    );
  }

  Widget _categoryItem(String label, IconData icon, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationCard({
    required String title,
    required String foundation,
    required String target,
    required double progress,
    required String donations,
    required bool isClosed,
    required Color progressColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[200],
                  child: const Icon(
                    Icons.image,
                    color: Colors.white70,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isClosed)
                      const Text(
                        "Closed 🔴",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      "Foundation :",
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                    Text(
                      "by $foundation",
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "${(progress * 100).toInt()}% target pendanaan : $target",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFFEEEEEE),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progressColor,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isClosed ? Icons.favorite_border : Icons.favorite,
                    color: isClosed ? Colors.grey : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    donations,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: isClosed ? null : () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: isClosed
                      ? const Color(0xFFE0E0E0)
                      : const Color(0xFF28A745),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text("Donate now"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
