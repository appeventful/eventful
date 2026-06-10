import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

class PolicyDetailScreen extends StatelessWidget {
  final String title;
  final String policyType;

  const PolicyDetailScreen({super.key, required this.title, required this.policyType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('app_settings').doc('policies').get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }
          
          String content = '';
          
          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            content = data[policyType] ?? '';
          }

          if (content.isEmpty) {
            // Try fallback collection 'legal_texts' if 'app_settings/policies' is empty
            String docId = policyType;
            if (policyType == 'terms') docId = 'terms_of_use';
            if (policyType == 'privacy') docId = 'privacy_policy';

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('legal_texts').doc(docId).get(),
              builder: (context, fallbackSnap) {
                if (fallbackSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.orange));
                }

                if (fallbackSnap.hasData && fallbackSnap.data!.exists) {
                  var fbData = fallbackSnap.data!.data() as Map<String, dynamic>;
                  content = fbData['content'] ?? '';
                }

                if (content.isEmpty) {
                  // Final fallback to constants
                  if (policyType == 'terms') content = defaultTermsOfUse;
                  else if (policyType == 'privacy') content = defaultPrivacyPolicy;
                  else if (policyType == 'kvkk') content = defaultKVKK;
                  else content = 'Metin henüz eklenmemiş.';
                }

                return _buildContent(content);
              },
            );
          }

          return _buildContent(content);
        },
      ),
    );
  }

  Widget _buildContent(String content) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      height: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          content,
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
