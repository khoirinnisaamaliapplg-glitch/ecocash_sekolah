import 'package:flutter/material.dart';

class EcomerPage extends StatelessWidget {
  const EcomerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Warna background abu muda
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Header dengan Gambar + Kartu Saldo Melayang
            _buildHeader(context),

            // 2. Jarak tambahan karena kartu saldo menggunakan Positioned (melayang)
            const SizedBox(height: 85),

            // 3. Banner Penawaran (Attractive Offer)
            _buildOfferBanner(),

            // 4. Grid Produk
            _buildProductGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none, // Agar kartu saldo tidak terpotong di bawah
      children: [
        // --- BACKGROUND IMAGE ---
        Container(
          height: 250,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg.png'),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tombol Back
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const Text(
                        'Back',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // Judul
                  const Padding(
                    padding: EdgeInsets.only(left: 15, top: 10),
                    child: Text(
                      'e-Commerce',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // --- KARTU SALDO (PUTIH) ---
        Positioned(
          top: 180, // Mengatur kartu agar "memotong" bagian bawah header
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(26),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset('assets/icons/dompet.png', height: 35, width: 35),
                        const SizedBox(width: 12),
                        const Text(
                          "Rp. 100.000",
                          style: TextStyle(
                            fontSize: 24, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Image.asset('assets/icons/mingcute.png', height: 30, width: 30),
                  ],
                ),
                const SizedBox(height: 15),
                const Text(
                  "Exchange of Goods",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Text(
                  "Come on, exchange your balance and get the prize you want!",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfferBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFFFF7066), // Warna coral/pink sesuai desain
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.stars, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Text(
            "Attractive offer",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true, // Wajib agar tidak error di dalam Column/SingleChildScrollView
        physics: const NeverScrollableScrollPhysics(), // Scroll mengikuti layar utama
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
        childAspectRatio: 0.65, // Rasio tinggi kotak produk
        children: [
          _buildProductItem("Lampu dari sendok plastik bekas", "Rp 80.000", Icons.lightbulb_outline),
          _buildProductItem("Cermin di hiasi sendok plastik", "Rp 75.000", Icons.grid_view),
          _buildProductItem("Pot Tanaman dari kaleng bekas", "Rp 20.000", Icons.yard_outlined),
          _buildProductItem("Tempat alat belajar dari kaleng", "Rp 35.000", Icons.edit_note),
        ],
      ),
    );
  }

  Widget _buildProductItem(String title, String price, IconData placeholderIcon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 5),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bagian Gambar
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Icon(placeholderIcon, size: 50, color: Colors.grey[400]),
              // Jika ingin pakai gambar sungguhan:
              // child: ClipRRect(
              //   borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              //   child: Image.asset('assets/image_name.png', fit: BoxFit.cover),
              // ),
            ),
          ),
          // Bagian Teks & Tombol
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  price,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 35,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32), // Hijau gelap
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Exchange now",
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}