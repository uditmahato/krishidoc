// history_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:krishidoc/locale/base_language_key.dart';
import 'package:krishidoc/locale/localization.dart';
import 'package:krishidoc/locale/language_ar.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../models/history_model.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final BaseLanguage lang = BaseLanguage.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lang.history,
          
        ),
      ),
      body: user == null
          ? Center(
              child: Text(
                lang.loginPrompt,
                
              ),
            )
          : FutureBuilder<List<HistoryEntry>>(
              future: FirestoreService().getHistory(user.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      lang.noHistory,
                      
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final entry = snapshot.data![index];
                    return ListTile(
                      leading: entry.imageUrl.isNotEmpty
                          ? Image.network(entry.imageUrl, width: 56, height: 56, fit: BoxFit.cover)
                          : const Icon(Icons.image),
                      title: Text(
                        entry.diseaseName,
                        
                      ),
                      subtitle: Text(
                        entry.timestamp.toString(),
                        
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}