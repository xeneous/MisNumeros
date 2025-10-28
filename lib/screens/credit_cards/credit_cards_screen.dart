import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../models/credit_card.dart';
import '../../services/database_service.dart';
import '../../widgets/credit_cards/credit_card_list_item.dart';
import '../../widgets/credit_cards/add_credit_card_fab.dart';

class CreditCardsScreen extends StatefulWidget {
  const CreditCardsScreen({super.key});

  @override
  State<CreditCardsScreen> createState() => _CreditCardsScreenState();
}

class _CreditCardsScreenState extends State<CreditCardsScreen> {
  List<CreditCard> _creditCards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCreditCards();
  }

  Future<void> _loadCreditCards() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;

    if (currentUser != null) {
      try {
        final dbService = DatabaseService();
        final creditCards = await dbService.getCreditCards(currentUser.id);
        setState(() {
          _creditCards = creditCards;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar tarjetas: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tarjetas de Crédito'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _creditCards.isEmpty
          ? _buildEmptyState()
          : _buildCreditCardsList(),
      floatingActionButton: const AddCreditCardFab(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No tienes tarjetas aún',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega tu primera tarjeta de crédito',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCardsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _creditCards.length,
      itemBuilder: (context, index) {
        final creditCard = _creditCards[index];
        return CreditCardListItem(
          creditCard: creditCard,
          onCreditCardUpdated: _loadCreditCards,
        );
      },
    );
  }
}
