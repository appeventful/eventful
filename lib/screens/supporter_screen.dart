import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';

class SupporterScreen extends StatefulWidget {
  const SupporterScreen({super.key});

  @override
  State<SupporterScreen> createState() => _SupporterScreenState();
}

class _SupporterScreenState extends State<SupporterScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // handle error here.
    });
    _initStoreInfo();
  }

  Future<void> _initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final Set<String> _kIds = isIOS 
      ? <String>{'eventful_bronze_ios', 'eventful_silver_ios', 'eventful_gold_ios'}
      : <String>{'bronz', 'gumus', 'altin'};

    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_kIds);
    
    if (mounted) {
      setState(() {
        _products = response.productDetails;
        _isLoading = false;
      });
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          // Show error
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          // Success!
          await _handleSuccessfulPurchase(purchaseDetails);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    });
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    String tier = 'none';
    String badgeId = '';
    
    final pId = purchase.productID;
    if (pId == 'bronz' || pId == 'eventful_bronze_ios') {
      tier = 'bronze';
      badgeId = 'supporter_bronze';
    } else if (pId == 'gumus' || pId == 'eventful_silver_ios') {
      tier = 'silver';
      badgeId = 'supporter_silver';
    } else if (pId == 'altin' || pId == 'eventful_gold_ios') {
      tier = 'gold';
      badgeId = 'supporter_gold';
    }

    if (tier != 'none') {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'supporterTier': tier,
        'badges': FieldValue.arrayUnion([badgeId]),
      });
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Desteğiniz için teşekkürler! Rozetiniz profilinize eklendi. 🎉')),
        );
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final platform = Theme.of(context).platform;
    final isIOS = platform == TargetPlatform.iOS;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Destekçi Ol'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.favorite, size: 80, color: Colors.red),
                  const SizedBox(height: 24),
                  const Text(
                    'Eventful\'u Destekleyin',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Uygulamamızın gelişmesine katkıda bulunarak topluluğumuzun bir parçası olun. Her destek, daha kaliteli etkinlikler ve yeni özellikler demektir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(height: 40),
                  _buildTierCard(
                    title: 'Bronz Destekçi',
                    price: '29.99₺ / ay',
                    description: 'Profilinizde Bronz rozet kazanır ve isminiz turuncu görünür.',
                    color: Colors.orange.shade700,
                    productId: isIOS ? 'eventful_bronze_ios' : 'bronz',
                  ),
                  const SizedBox(height: 16),
                  _buildTierCard(
                    title: 'Gümüş Destekçi',
                    price: '59.99₺ / ay',
                    description: 'Profilinizde Gümüş rozet kazanır ve isminiz gümüş renginde parlar.',
                    color: Colors.blueGrey.shade400,
                    productId: isIOS ? 'eventful_silver_ios' : 'gumus',
                  ),
                  const SizedBox(height: 16),
                  _buildTierCard(
                    title: 'Altın Destekçi',
                    price: '119.99₺ / ay',
                    description: 'Altın rozet kazanır, isminiz altın renginde parlar ve en üst düzey desteği sağlarsınız.',
                    color: Colors.amber.shade600,
                    productId: isIOS ? 'eventful_gold_ios' : 'altin',
                  ),
                  const SizedBox(height: 40),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Belki Daha Sonra', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      await _inAppPurchase.restorePurchases();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Satın alımlar geri yükleniyor...')),
                        );
                      }
                    },
                    child: const Text('Satın Alımları Geri Yükle', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Abonelik Bilgilendirmesi',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isIOS 
                      ? 'Ödeme, satın alma onayının ardından Apple ID hesabınızdan tahsil edilecektir. Abonelik, mevcut dönemin bitiminden en az 24 saat önce iptal edilmediği sürece otomatik olarak yenilenir. Hesabınızdan mevcut dönemin bitiminden 24 saat önce yenileme ücreti alınacaktır. Aboneliklerinizi satın aldıktan sonra App Store hesap ayarlarınıza giderek yönetebilir ve iptal edebilirsiniz.'
                      : 'Ödeme, satın alma onayının ardından Google Play hesabınızdan tahsil edilecektir. Abonelik, mevcut dönemin bitiminden en az 24 saat önce iptal edilmediği sürece otomatik olarak yenilenir. Hesabınızdan mevcut dönemin bitiminden 24 saat önce yenileme ücreti alınacaktır. Aboneliklerinizi satın aldıktan sonra Google Play Store abonelik ayarlarınıza giderek yönetebilir ve iptal edebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegalLink('Kullanım Koşulları', 'https://eventfulapp.org/terms'),
                      const Text('  •  ', style: TextStyle(color: Colors.grey)),
                      _buildLegalLink('Gizlilik Politikası', 'https://eventfulapp.org/privacy'),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildLegalLink(String title, String url) {
    return InkWell(
      onTap: () async {
        final Uri uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline),
      ),
    );
  }

  Widget _buildTierCard({
    required String title,
    required String price,
    required String description,
    required Color color,
    required String productId,
  }) {
    ProductDetails? product;
    try {
      product = _products.firstWhere((p) => p.id == productId);
    } catch (_) {}

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 8),
          Text(product?.price ?? price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: () {
                if (product != null) {
                  final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
                  // Otomatik yenilenen abonelikler için buyNonConsumable kullanılır
                  // Apple tarafında "Auto-Renewable Subscription" olarak seçilmelidir
                  _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
                } else {
                  _showStoreError();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Destekle', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showStoreError() {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mağaza Bağlantı Hatası'),
        content: Text(isIOS 
          ? 'App Store bağlantısı kurulamadı. Lütfen internet bağlantınızı ve Apple ID hesabınızın açık olduğunu kontrol edin.'
          : 'Google Play Store bağlantısı kurulamadı. Lütfen internet bağlantınızı ve Google hesabınızın açık olduğunu kontrol edin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam')),
        ],
      ),
    );
  }

  void _handleMockPurchase(String productId) {
    // Bu metod artık kullanılmıyor, yerine _showStoreError eklendi.
  }
}
