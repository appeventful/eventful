import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
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

    const Set<String> _kIds = <String>{
      'supporter_bronze_monthly',
      'supporter_silver_monthly',
      'supporter_gold_monthly',
    };
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
    
    if (purchase.productID == 'supporter_bronze_monthly') {
      tier = 'bronze';
      badgeId = 'supporter_bronze';
    } else if (purchase.productID == 'supporter_silver_monthly') {
      tier = 'silver';
      badgeId = 'supporter_silver';
    } else if (purchase.productID == 'supporter_gold_monthly') {
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
                    price: '25₺ / ay',
                    description: 'Profilinizde Bronz rozet kazanır ve isminiz turuncu görünür.',
                    color: Colors.orange.shade700,
                    productId: 'supporter_bronze_monthly',
                  ),
                  const SizedBox(height: 16),
                  _buildTierCard(
                    title: 'Gümüş Destekçi',
                    price: '50₺ / ay',
                    description: 'Profilinizde Gümüş rozet kazanır ve isminiz gümüş renginde parlar.',
                    color: Colors.blueGrey.shade400,
                    productId: 'supporter_silver_monthly',
                  ),
                  const SizedBox(height: 16),
                  _buildTierCard(
                    title: 'Altın Destekçi',
                    price: '100₺ / ay',
                    description: 'Altın rozet kazanır, isminiz altın renginde parlar ve en üst düzey desteği sağlarsınız.',
                    color: Colors.amber.shade600,
                    productId: 'supporter_gold_monthly',
                  ),
                  const SizedBox(height: 40),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Belki Daha Sonra', style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
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
    // If store is not available or product not found, we show mock price
    // In real app, we should use _products finding correct product details
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
                  _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
                } else {
                  // Mock purchase for simulation if not in real store
                  _handleMockPurchase(productId);
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

  void _handleMockPurchase(String productId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simüle Edilmiş Ödeme'),
        content: const Text('Mağaza ID\'leri henüz tanımlanmadığı için bu işlem şu an simüle edilmektedir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleSuccessfulPurchase(PurchaseDetails(
                productID: productId,
                status: PurchaseStatus.purchased,
                transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
                purchaseID: 'mock_id_${DateTime.now().millisecondsSinceEpoch}',
                verificationData: PurchaseVerificationData(localVerificationData: '', serverVerificationData: '', source: ''),
              ));
            },
            child: const Text('Ödemeyi Onayla'),
          ),
        ],
      ),
    );
  }
}
