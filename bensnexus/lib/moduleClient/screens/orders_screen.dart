// lib/screens/orders_screen.dart

import 'package:flutter/material.dart';
import '../../commun/widgets/order_card.dart'; // Votre OrderCard restauré
import '../../commun/widgets/options_menu.dart';
import '../../commun/fonctionCommun/fonctionCl1.dart';
import 'order_details_screen.dart';
import '../../commun/widgets/search_filter_widgets.dart'; // Le fichier que vous avez demandé
import 'package:flutter_svg/flutter_svg.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchController = TextEditingController();

  // États des filtres pour chaque onglet
  String _activeFilterStatus = 'Tous';
  bool _activeOnlyWithNotif = false;

  String _historyFilterStatus = 'Tous';
  bool _historyOnlyWithNotif = false;

  // Données de l'application
  final List<Map<String, dynamic>> _activeOrders = [
    {
      'id': '1',
      'title': 'Livraison ciment',
      'address': 'ouakam brioche dorée',
      'status': 'en cours',
      'notif': 3
    },
    {
      'id': '2',
      'title': 'Livraison container',
      'address': 'Thiès',
      'status': 'en attente',
      'notif': 0
    },
    {
      'id': '3',
      'title': 'Livraison panneau solaire',
      'address': 'Mbour',
      'status': 'en attente de confirmation',
      'notif': 7
    },
  ];
  final List<Map<String, dynamic>> _completedOrders = [
    {
      'id': '4',
      'title': 'Livraison Riz',
      'address': '8 Rue de Rivoli, Paris',
      'status': 'livrée',
      'completedDate': '2023-05-15',
      'notif': 0
    },
    {
      'id': '5',
      'title': 'Livraison colis',
      'address': 'Dakar Plateau',
      'status': 'annulée',
      'completedDate': '2023-05-14',
      'notif': 2
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredList({
    required List<Map<String, dynamic>> sourceList,
    required String selectedStatus,
    required bool onlyWithNotif,
  }) {
    final query = _searchController.text.toLowerCase();
    return sourceList.where((order) {
      final title = (order['title'] ?? '').toLowerCase();
      final address = (order['address'] ?? '').toLowerCase();
      final status = order['status'] ?? '';
      final notif = order['notif'] ?? 0;
      final matchesSearch =
          query.isEmpty || title.contains(query) || address.contains(query);
      final matchesStatus =
          selectedStatus == 'Tous' || status == selectedStatus;
      final matchesNotif = !onlyWithNotif || notif > 0;
      return matchesSearch && matchesStatus && matchesNotif;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const activeStatusOptions = [
      'Tous',
      'en cours',
      'en attente',
      'en attente de confirmation'
    ];
    const historyStatusOptions = ['Tous', 'livrée', 'annulée'];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mes Commandes'),
          actions: [
            OptionsMenu(
              options: const [
                'Boîte de réception',
                'Profil',
                'Paramètres',
                'Déconnexion'
              ],
              functions: [
                () => goToInbox(context),
                () => goToProfile(context),
                () => goToSettings(context),
                () => logout(context)
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Actives'), Tab(text: 'Historique')],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: SearchBarWidget(controller: _searchController),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Onglet Commandes Actives
                  _buildOrderList(
                    context: context,
                    orders: _getFilteredList(
                        sourceList: _activeOrders,
                        selectedStatus: _activeFilterStatus,
                        onlyWithNotif: _activeOnlyWithNotif),
                    filterPanel: FilterPanel(
                      selectedStatus: _activeFilterStatus,
                      onlyWithNotif: _activeOnlyWithNotif,
                      statusOptions: activeStatusOptions,
                      onStatusChanged: (value) =>
                          setState(() => _activeFilterStatus = value),
                      onNotifChanged: (value) =>
                          setState(() => _activeOnlyWithNotif = value),
                      onClearFilters: () => setState(() {
                        _activeFilterStatus = 'Tous';
                        _activeOnlyWithNotif = false;
                      }),
                    ),
                    onStart: (orderId) {/* ... Logique onStart ... */},
                  ),
                  // Onglet Historique
                  _buildOrderList(
                    context: context,
                    orders: _getFilteredList(
                        sourceList: _completedOrders,
                        selectedStatus: _historyFilterStatus,
                        onlyWithNotif: _historyOnlyWithNotif),
                    isHistory: true,
                    filterPanel: FilterPanel(
                      selectedStatus: _historyFilterStatus,
                      onlyWithNotif: _historyOnlyWithNotif,
                      statusOptions: historyStatusOptions,
                      onStatusChanged: (value) =>
                          setState(() => _historyFilterStatus = value),
                      onNotifChanged: (value) =>
                          setState(() => _historyOnlyWithNotif = value),
                      onClearFilters: () => setState(() {
                        _historyFilterStatus = 'Tous';
                        _historyOnlyWithNotif = false;
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // **BOUTON FLOTTANT RESTAURÉ**
        floatingActionButton: FloatingActionButton(
          onPressed: () => goToInbox(context),
          child: SvgPicture.asset(
            'assetes/svg/chat_icon.svg',
            width: 30,
            height: 30,
            // color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderList({
    required BuildContext context,
    required List<Map<String, dynamic>> orders,
    required Widget filterPanel,
    bool isHistory = false,
    Function(String)? onStart,
  }) {
    return Column(
      children: [
        filterPanel,
        const Divider(height: 1),
        Expanded(
          child: orders.isEmpty
              ? Center(
                  child: Text(isHistory
                      ? 'Aucune commande dans l’historique'
                      : 'Aucune commande active')
                  )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      10, 0, 10, 80), // Espace pour le FAB
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return OrderCard(
                      order: order,
                      isHistory: isHistory,
                      onStart:
                          onStart != null ? () => onStart(order['id']) : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrderDetailsScreen(orderId: order['id']),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
