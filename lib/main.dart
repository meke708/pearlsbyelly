import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// Global API configuration
String gBaseUrl = "http://localhost:5000/api";

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pearls By Elly | Handmade Jewelry & Customer Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFc9a55c), // Warm Bohemian Gold
          primary: const Color(0xFFc9a55c),
          surface: const Color(0xFFfaf6f1), // Soft Cream
          secondary: const Color(0xFF5a331f), // Official Logo Chocolate Brown
        ),
        scaffoldBackgroundColor: const Color(0xFFfaf6f1),
        fontFamily: 'Serif',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const ClientHomePage(),
        '/admin': (context) => const AdminPortalPage(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => const ClientHomePage(),
      ),
    );
  }
}

// --- DATA MODELS ---
class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String role;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Customer',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? 'Opuwo, Namibia',
      role: json['role']?.toString() ?? 'customer',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'role': role,
    };
  }
}

class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final String imageUrl;
  final String description;
  final List<String> details;
  final String? tag;
  final double rating;
  final int reviewCount;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.imageUrl,
    required this.description,
    required this.details,
    this.tag,
    this.rating = 5.0,
    this.reviewCount = 28,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Item',
      category: json['category']?.toString() ?? 'ACCESSORIES',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl']?.toString() ?? 'https://images.unsplash.com/photo-1602751584552-8ba73aad10e1?w=600',
      description: json['description']?.toString() ?? '',
      details: (json['details'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['Handcrafted in Opuwo'],
      tag: json['tag']?.toString(),
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 20,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'imageUrl': imageUrl,
      'description': description,
      'details': details,
      'tag': tag,
      'rating': rating,
      'reviewCount': reviewCount,
    };
  }
}

class OrderModel {
  final String orderCode;
  final String userId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final List<dynamic> items;
  final String customText;
  final String courierMethod;
  final double totalAmount;
  final String status;
  final String dateCreated;

  OrderModel({
    required this.orderCode,
    required this.userId,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.items,
    required this.customText,
    required this.courierMethod,
    required this.totalAmount,
    required this.status,
    required this.dateCreated,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      orderCode: json['orderCode']?.toString() ?? 'PBE-0000',
      userId: json['userId']?.toString() ?? 'guest',
      customerName: json['customerName']?.toString() ?? 'Customer',
      customerEmail: json['customerEmail']?.toString() ?? 'guest@pearlsbyelly.com',
      customerPhone: json['customerPhone']?.toString() ?? '',
      items: json['items'] as List<dynamic>? ?? [],
      customText: json['customText']?.toString() ?? '',
      courierMethod: json['courierMethod']?.toString() ?? 'Courier',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'Order Received & Confirmed',
      dateCreated: json['dateCreated']?.toString() ?? '',
    );
  }
}

// ==========================================
// 1. CLIENT FRONTEND HOME PAGE (ROUTE: '/')
// ==========================================
class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> with SingleTickerProviderStateMixin {
  final GlobalKey _builderKey = GlobalKey();
  final GlobalKey _catalogKey = GlobalKey();
  final GlobalKey _priceListKey = GlobalKey();
  final GlobalKey _storyKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();

  UserModel? _currentUser;
  List<Product> _products = [];
  List<OrderModel> _myUserOrders = [];

  final Map<String, int> _cart = {};
  final Set<String> _wishlist = {};
  String _selectedCategory = 'ALL';
  String _searchQuery = "";
  String _sortBy = 'FEATURED';
  String _selectedCurrency = 'NAD';

  final TextEditingController _customNameController = TextEditingController(text: "SELMA");
  String _selectedBeadTheme = 'BOHO EARTHY';
  String _selectedWristSize = '17cm (Medium)';
  bool _enablePersonalization = false;

  bool _includeGiftPackaging = false;
  final TextEditingController _giftNoteController = TextEditingController();
  final TextEditingController _newsletterController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerEmailController = TextEditingController();

  String _selectedDeliveryRegion = 'Nationwide Courier (Namibia)';
  double _appliedDiscountPercent = 0.0;
  final TextEditingController _promoCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProductsFromBackend();
    _restoreUserSession();
  }

  Future<void> _saveUserSession(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pbe_user_session', jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<void> _clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pbe_user_session');
    } catch (_) {}
  }

  Future<void> _restoreUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString('pbe_user_session');
      if (sessionJson != null && sessionJson.isNotEmpty) {
        final userData = jsonDecode(sessionJson);
        setState(() {
          _currentUser = UserModel.fromJson(userData);
        });
        _fetchMyUserOrders();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _customNameController.dispose();
    _giftNoteController.dispose();
    _newsletterController.dispose();
    _promoCodeController.dispose();
    _customerPhoneController.dispose();
    _customerNameController.dispose();
    _customerEmailController.dispose();
    super.dispose();
  }

  Future<void> _fetchProductsFromBackend() async {
    try {
      final response = await http.get(Uri.parse("$gBaseUrl/products")).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        setState(() {
          _products = list.map((item) => Product.fromJson(item)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchMyUserOrders() async {
    if (_currentUser == null) return;
    try {
      final res = await http.get(Uri.parse("$gBaseUrl/orders/user/${_currentUser!.email}"));
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        setState(() {
          _myUserOrders = list.map((item) => OrderModel.fromJson(item)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _postOrderToApi(Map<String, dynamic> orderPayload) async {
    try {
      await http.post(
        Uri.parse("$gBaseUrl/orders"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(orderPayload),
      );
      _fetchMyUserOrders();
    } catch (_) {}
  }

  Future<void> _openUrl(String urlString) async {
    final Uri uri = Uri.parse(urlString);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  void _scrollToSection(GlobalKey key) {
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  void _toggleWishlist(String productId) {
    setState(() {
      if (_wishlist.contains(productId)) {
        _wishlist.remove(productId);
      } else {
        _wishlist.add(productId);
      }
    });
  }

  void _addToCart(Product product, {int count = 1}) {
    setState(() {
      _cart[product.id] = (_cart[product.id] ?? 0) + count;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✨ ${product.name} added to selection bag.'),
        backgroundColor: const Color(0xFF5a331f),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _removeFromCart(String productId) {
    setState(() {
      if (_cart.containsKey(productId)) {
        if (_cart[productId] == 1) {
          _cart.remove(productId);
        } else {
          _cart[productId] = _cart[productId]! - 1;
        }
      }
    });
  }

  double _getShippingFee() => 60.0;

  double _calculateSubtotal() {
    double total = 0.0;
    _cart.forEach((productId, quantity) {
      final product = _products.firstWhere((p) => p.id == productId, orElse: () => Product(id: '0', name: 'Item', category: '', price: 0, imageUrl: '', description: '', details: []));
      total += product.price * quantity;
    });
    return total;
  }

  double _calculateFinalTotal() {
    double subtotal = _calculateSubtotal();
    double discount = subtotal * _appliedDiscountPercent;
    return (subtotal - discount) + (_cart.isEmpty ? 0.0 : _getShippingFee());
  }

  String _formatPrice(double priceInNAD) {
    if (_selectedCurrency == 'USD') {
      return '\$ ${(priceInNAD * 0.055).toStringAsFixed(2)}';
    } else if (_selectedCurrency == 'EUR') {
      return '€ ${(priceInNAD * 0.051).toStringAsFixed(2)}';
    } else {
      return 'N\$ ${priceInNAD.toStringAsFixed(2)}';
    }
  }

  void _applyPromoCode(StateSetter setModalState) {
    String code = _promoCodeController.text.trim().toUpperCase();
    if (code == 'ELLY10' || code == 'OPUWO10') {
      setModalState(() => _appliedDiscountPercent = 0.10);
      setState(() => _appliedDiscountPercent = 0.10);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 10% VIP Discount Applied!'), backgroundColor: Color(0xFFc9a55c)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Promo Code. Try "ELLY10"'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _sendWhatsAppOrder() {
    if (_cart.isEmpty) return;

    final orderItems = [];
    StringBuffer buffer = StringBuffer();
    buffer.write("✨ *NEW ORDER: PEARLS BY ELLY* ✨\n\n");
    buffer.write("Hello! I'd like to place a custom order for the following items:\n\n");

    _cart.forEach((productId, quantity) {
      final product = _products.firstWhere((p) => p.id == productId, orElse: () => Product(id: '0', name: 'Item', category: '', price: 0, imageUrl: '', description: '', details: []));
      buffer.write("🌸 *${product.name}* (${product.category})\n");
      buffer.write("   Quantity: $quantity\n");
      buffer.write("   Price: ${_formatPrice(product.price * quantity)}\n\n");
      orderItems.add({
        'id': product.id,
        'name': product.name,
        'quantity': quantity,
        'price': product.price
      });
    });

    bool hasCustomItem = _enablePersonalization || _cart.keys.any((id) {
      final p = _products.firstWhere(
        (prod) => prod.id == id,
        orElse: () => Product(id: '0', name: '', category: '', price: 0, imageUrl: '', description: '', details: []),
      );
      return p.category == 'CUSTOM NAME' || id == '1' || id == '7';
    });

    String customText = (hasCustomItem && _customNameController.text.trim().isNotEmpty) ? _customNameController.text.trim().toUpperCase() : '';
    if (hasCustomItem && customText.isNotEmpty) {
      buffer.write("✏️ *Custom Name Requested:* \"$customText\"\n");
      buffer.write("🎨 *Style Theme:* $_selectedBeadTheme\n");
      buffer.write("📏 *Size/Type:* $_selectedWristSize\n\n");
    }

    if (_includeGiftPackaging) {
      buffer.write("🎁 *GIFT PACKAGING REQUESTED*\n");
      if (_giftNoteController.text.trim().isNotEmpty) {
        buffer.write("💌 *Gift Note:* \"${_giftNoteController.text.trim()}\"\n");
      }
      buffer.write("\n");
    }

    String customerName = _currentUser != null ? _currentUser!.name : (_customerNameController.text.trim().isEmpty ? 'Valued Customer' : _customerNameController.text.trim());
    String customerEmail = _currentUser != null ? _currentUser!.email : (_customerEmailController.text.trim().isEmpty ? 'guest@pearlsbyelly.com' : _customerEmailController.text.trim());
    String customerPhone = _currentUser != null ? _currentUser!.phone : (_customerPhoneController.text.trim().isEmpty ? '0816318658' : _customerPhoneController.text.trim());

    buffer.write("👤 *Customer Account:* $customerName ($customerEmail)\n");
    buffer.write("📞 *Phone:* $customerPhone\n");
    buffer.write("🚚 *Courier Delivery:* $_selectedDeliveryRegion\n");
    if (_appliedDiscountPercent > 0) {
      buffer.write("🏷️ *Discount:* ${(_appliedDiscountPercent * 100).toInt()}% OFF applied\n");
    }

    buffer.write("━━━━━━━━━━━━━━━━━━━━\n");
    buffer.write("💰 *FINAL TOTAL:* ${_formatPrice(_calculateFinalTotal())}\n");

    _postOrderToApi({
      'userId': _currentUser != null ? _currentUser!.id : 'guest',
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'items': orderItems,
      'customText': customText,
      'courierMethod': _selectedDeliveryRegion,
      'totalAmount': _calculateFinalTotal(),
      'giftNote': _giftNoteController.text.trim(),
    });

    final encodedText = Uri.encodeComponent(buffer.toString());
    final url = "https://wa.me/264816318658?text=$encodedText";
    _openUrl(url);
  }

  // --- USER AUTHENTICATION MODAL (LOGIN / REGISTER) ---
  void _showUserAuthModal() {
    final loginEmailCtrl = TextEditingController();
    final loginPwdCtrl = TextEditingController();
    final regNameCtrl = TextEditingController();
    final regEmailCtrl = TextEditingController();
    final regPhoneCtrl = TextEditingController();
    final regPwdCtrl = TextEditingController();
    final regAddressCtrl = TextEditingController(text: 'Windhoek, Namibia');

    String authError = '';

    showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: 2,
        child: StatefulBuilder(
          builder: (context, setAuthModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Column(
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Image.asset('assets/pearlsbyelly_logo.jpg', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.stars, color: Color(0xFFc9a55c))),
                  ),
                  const SizedBox(height: 8),
                  const Text('CUSTOMER ACCOUNT PORTAL', style: TextStyle(fontFamily: 'Serif', letterSpacing: 2, fontSize: 16, color: Color(0xFF5a331f))),
                  const TabBar(
                    indicatorColor: Color(0xFFc9a55c),
                    labelColor: Color(0xFF5a331f),
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(text: 'SIGN IN'),
                      Tab(text: 'REGISTER ACCOUNT'),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                height: 320,
                child: TabBarView(
                  children: [
                    // SIGN IN TAB
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          TextField(
                            controller: loginEmailCtrl,
                            decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
                            style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: loginPwdCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                            style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                          ),
                          if (authError.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(authError, style: const TextStyle(color: Colors.redAccent, fontFamily: 'Montserrat', fontSize: 11)),
                          ],
                          const SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5a331f),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 45),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () async {
                              try {
                                final res = await http.post(
                                  Uri.parse("$gBaseUrl/users/login"),
                                  headers: {'Content-Type': 'application/json'},
                                  body: jsonEncode({
                                    'email': loginEmailCtrl.text.trim(),
                                    'password': loginPwdCtrl.text.trim(),
                                  }),
                                );
                                if (res.statusCode == 200) {
                                  final data = jsonDecode(res.body);
                                  setState(() {
                                    _currentUser = UserModel.fromJson(data['user']);
                                  });
                                  _saveUserSession(_currentUser!);
                                  _fetchMyUserOrders();
                                  if (context.mounted) Navigator.pop(context);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('✨ Welcome back, ${_currentUser!.name}!')),
                                  );
                                } else {
                                  setAuthModalState(() => authError = 'Invalid email or password');
                                }
                              } catch (e) {
                                setAuthModalState(() => authError = 'Connection failed');
                              }
                            },
                            child: const Text('LOG IN TO ACCOUNT', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                    // REGISTER TAB
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          TextField(
                            controller: regNameCtrl,
                            decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder()),
                            style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: regEmailCtrl,
                            decoration: const InputDecoration(labelText: 'Email Address *', border: OutlineInputBorder()),
                            style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: regPhoneCtrl,
                            decoration: const InputDecoration(labelText: 'Phone / WhatsApp No. *', border: OutlineInputBorder()),
                            style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: regPwdCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'Password *', border: OutlineInputBorder()),
                            style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: regAddressCtrl,
                            decoration: const InputDecoration(labelText: 'Delivery Address', border: OutlineInputBorder()),
                            style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                          ),
                          if (authError.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(authError, style: const TextStyle(color: Colors.redAccent, fontFamily: 'Montserrat', fontSize: 11)),
                          ],
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFc9a55c),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 45),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () async {
                              try {
                                final res = await http.post(
                                  Uri.parse("$gBaseUrl/users/register"),
                                  headers: {'Content-Type': 'application/json'},
                                  body: jsonEncode({
                                    'name': regNameCtrl.text.trim(),
                                    'email': regEmailCtrl.text.trim(),
                                    'phone': regPhoneCtrl.text.trim(),
                                    'password': regPwdCtrl.text.trim(),
                                    'address': regAddressCtrl.text.trim(),
                                  }),
                                );
                                if (res.statusCode == 201) {
                                  final data = jsonDecode(res.body);
                                  setState(() {
                                    _currentUser = UserModel.fromJson(data['user']);
                                  });
                                  _saveUserSession(_currentUser!);
                                  if (context.mounted) Navigator.pop(context);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('🎉 Account created! Welcome, ${_currentUser!.name}')),
                                  );
                                } else {
                                  final errData = jsonDecode(res.body);
                                  setAuthModalState(() => authError = errData['error'] ?? 'Registration failed');
                                }
                              } catch (e) {
                                setAuthModalState(() => authError = 'Server connection error');
                              }
                            },
                            child: const Text('CREATE MY ACCOUNT', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontFamily: 'Montserrat'))),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showMyAccountOrdersModal() {
    _fetchMyUserOrders();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.person, color: Color(0xFFc9a55c)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'My Account (${_currentUser?.name ?? "User"})',
                style: const TextStyle(fontFamily: 'Serif', fontSize: 18, color: Color(0xFF5a331f)),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: const Color(0xFFfaf6f1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email: ${_currentUser?.email}', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('Phone: ${_currentUser?.phone}', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12)),
                    Text('Address: ${_currentUser?.address}', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('My Order History', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF5a331f))),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: _myUserOrders.isEmpty
                    ? const Center(child: Text('You have no order history yet.', style: TextStyle(color: Colors.grey, fontFamily: 'Montserrat', fontStyle: FontStyle.italic)))
                    : ListView.builder(
                        itemCount: _myUserOrders.length,
                        itemBuilder: (context, index) {
                          final o = _myUserOrders[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('Code: ${o.orderCode}', style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, color: Color(0xFFc9a55c))),
                              subtitle: Text('Status: ${o.status} • Total: ${_formatPrice(o.totalAmount)}', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12)),
                            ),
                          );
                        },
                      ),
              )
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _currentUser = null);
              _clearUserSession();
              Navigator.pop(context);
            },
            child: const Text('LOG OUT', style: TextStyle(color: Colors.redAccent, fontFamily: 'Montserrat')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5a331f), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(fontFamily: 'Montserrat')),
          ),
        ],
      ),
    );
  }

  void _showOrderTrackerDialog() {
    final TextEditingController trackCodeController = TextEditingController();
    bool searched = false;
    List<OrderModel> foundOrders = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setTrackState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(),
            title: Row(
              children: const [
                Icon(Icons.local_shipping_outlined, color: Color(0xFFc9a55c)),
                SizedBox(width: 10),
                Text('COURIER ORDER TRACKER', style: TextStyle(fontFamily: 'Serif', letterSpacing: 2, fontSize: 16, color: Color(0xFF5a331f))),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter your Order Code, Email or WhatsApp Phone Number:', style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: trackCodeController,
                          style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'e.g. PBE-1024 or selma@gmail.com',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFc9a55c), foregroundColor: Colors.white, shape: const RoundedRectangleBorder()),
                        onPressed: () async {
                          final code = trackCodeController.text.trim();
                          if (code.isNotEmpty) {
                            try {
                              final res = await http.get(Uri.parse("$gBaseUrl/orders/track?code=$code"));
                              if (res.statusCode == 200) {
                                final List<dynamic> list = jsonDecode(res.body);
                                foundOrders = list.map((e) => OrderModel.fromJson(e)).toList();
                              }
                            } catch (_) {}
                          }
                          setTrackState(() => searched = true);
                        },
                        child: const Text('TRACK', style: TextStyle(fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (searched) ...[
                    const SizedBox(height: 20),
                    foundOrders.isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: foundOrders.map((o) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                color: const Color(0xFFfaf6f1),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('ORDER STATUS: ${o.orderCode}', style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5a331f))),
                                    Text('Customer: ${o.customerName} (${o.customerEmail})', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11)),
                                    Text('Current Step: ${o.status}', style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFc9a55c))),
                                    const SizedBox(height: 12),
                                    _buildTrackerStep('1. Order Received & Confirmed', true),
                                    _buildTrackerStep('2. Hand-threading Beads in Opuwo', o.status != 'Order Received & Confirmed'),
                                    _buildTrackerStep('3. Packed in Signature Velvet Pouch', o.status == 'Packed in Signature Velvet Pouch' || o.status == 'Dispatched via Courier' || o.status == 'Delivered'),
                                    _buildTrackerStep('4. Dispatched via Courier', o.status == 'Dispatched via Courier' || o.status == 'Delivered'),
                                  ],
                                ),
                              );
                            }).toList(),
                          )
                        : Container(
                            padding: const EdgeInsets.all(16),
                            color: const Color(0xFFfaf6f1),
                            child: const Text('No matching orders found. Please verify your order code with support.', style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.grey)),
                          )
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE', style: TextStyle(color: Color(0xFFc9a55c), fontFamily: 'Montserrat'))),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTrackerStep(String label, bool completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completed ? const Color(0xFFc9a55c) : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: completed ? const Color(0xFF5a331f) : Colors.grey, fontWeight: completed ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  void _showPriceListModal() {
    Map<String, List<double>> catPriceMap = {};
    for (var p in _products) {
      catPriceMap.putIfAbsent(p.category, () => []).add(p.price);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
        title: Column(
          children: [
            Container(
              height: 70,
              width: 70,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Image.asset(
                'assets/pearlsbyelly_logo.jpg',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('PEARLS BY ELLY', style: TextStyle(fontFamily: 'Serif', letterSpacing: 3, fontSize: 18, color: Color(0xFFc9a55c))),
            const SizedBox(height: 4),
            const Text('LIVE CATALOG PRICE GUIDE (N\$)', style: TextStyle(fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5a331f))),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Handmade in Opuwo • We Courier Nationwide', style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Container(
                  color: const Color(0xFFfaf6f1),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: catPriceMap.isNotEmpty
                        ? catPriceMap.entries.map((entry) {
                            entry.value.sort();
                            double minP = entry.value.first;
                            double maxP = entry.value.last;
                            String priceText = minP == maxP ? 'N\$ ${minP.toStringAsFixed(0)}' : 'N\$ ${minP.toStringAsFixed(0)} - N\$ ${maxP.toStringAsFixed(0)}';
                            return _PriceRow(entry.key, priceText);
                          }).toList()
                        : const [
                            _PriceRow('CUSTOM NAME', 'N\$ 45 - N\$ 50'),
                            _PriceRow('BODY JEWELRY', 'N\$ 35 - N\$ 80'),
                            _PriceRow('ACCESSORIES', 'N\$ 25 - N\$ 70'),
                            _PriceRow('SPECIALTY', 'N\$ 60 - N\$ 200'),
                          ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE PRICE LIST', style: TextStyle(color: Color(0xFFc9a55c), fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 980;
    final int crossAxisCount = screenWidth > 1200 ? 4 : (screenWidth > 750 ? 3 : 2);

    List<Product> filteredProducts = _products.where((p) {
      final matchesCategory = _selectedCategory == 'ALL' || p.category == _selectedCategory;
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                           p.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    if (_sortBy == 'PRICE: LOW TO HIGH') {
      filteredProducts.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortBy == 'PRICE: HIGH TO LOW') {
      filteredProducts.sort((a, b) => b.price.compareTo(a.price));
    } else if (_sortBy == 'NAME A-Z') {
      filteredProducts.sort((a, b) => a.name.compareTo(b.name));
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final encodedText = Uri.encodeComponent("Hello Pearls By Elly! I have an inquiry about custom beaded jewelry.");
          _openUrl("https://wa.me/264816318658?text=$encodedText");
        },
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('WhatsApp Us', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 12)),
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(115),
        child: Column(
          children: [
            // Top Announcement Bar
            Container(
              color: const Color(0xFF5a331f),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          '📍 BASED IN OPUWO • POP-UP MARKETS 1ST SEP - 21ST OCT • WE COURIER NATIONWIDE ✨',
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFfaf6f1),
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCurrency,
                          dropdownColor: const Color(0xFF5a331f),
                          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFc9a55c), size: 16),
                          style: const TextStyle(color: Color(0xFFc9a55c), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCurrency = val);
                          },
                          items: const [
                            DropdownMenuItem(value: 'NAD', child: Text('N\$ NAD')),
                            DropdownMenuItem(value: 'USD', child: Text('\$ USD')),
                            DropdownMenuItem(value: 'EUR', child: Text('€ EUR')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Navigation Bar
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFf4e4e1), width: 1)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Brand Title & Logo Monogram
                        InkWell(
                          onTap: () => _scrollToSection(_catalogKey),
                          child: Row(
                            children: [
                              Container(
                                height: 54,
                                width: 54,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Image.asset(
                                  'assets/pearlsbyelly_logo.jpg',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.stars, color: Color(0xFFc9a55c), size: 36),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PEARLS BY ELLY',
                                    style: TextStyle(
                                      color: Color(0xFFc9a55c),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.5,
                                    ),
                                  ),
                                  Text(
                                    'HANDMADE, BOHEMIAN & PERSONALIZED',
                                    style: TextStyle(
                                      color: const Color(0xFF5a331f).withValues(alpha: 0.5),
                                      fontSize: 7.5,
                                      letterSpacing: 1.5,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Desktop Navigation Links
                        if (isDesktop)
                          Flexible(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildNavLink('SHOP CATALOG', () => _scrollToSection(_catalogKey)),
                                  _buildNavLink('CUSTOM NAME BUILDER', () => _scrollToSection(_builderKey)),
                                  _buildNavLink('FLYER PRICE LIST', _showPriceListModal),
                                  _buildNavLink('TRACK ORDER', _showOrderTrackerDialog),
                                  _buildNavLink('ABOUT US', () => _scrollToSection(_storyKey)),
                                  _buildNavLink('FAQ', () => _scrollToSection(_faqKey)),
                                ],
                              ),
                            ),
                          ),

                        // User Account / Auth & Cart Actions
                        Row(
                          children: [
                            // Customer Account Button
                            TextButton.icon(
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF5a331f)),
                              onPressed: () {
                                if (_currentUser != null) {
                                  _showMyAccountOrdersModal();
                                } else {
                                  _showUserAuthModal();
                                }
                              },
                              icon: const Icon(Icons.person_outline, size: 20),
                              label: Text(
                                _currentUser != null ? _currentUser!.name.split(' ').first : 'ACCOUNT',
                                style: const TextStyle(fontFamily: 'Montserrat', fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Wishlist
                            IconButton(
                              icon: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(Icons.favorite_border, color: Color(0xFF5a331f), size: 24),
                                  if (_wishlist.isNotEmpty)
                                    Positioned(
                                      right: -4,
                                      top: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Color(0xFFc9a55c), shape: BoxShape.circle),
                                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                        child: Text(
                                          '${_wishlist.length}',
                                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    )
                                ],
                              ),
                              onPressed: () => _showWishlistBottomSheet(),
                            ),
                            const SizedBox(width: 6),

                            // Cart
                            IconButton(
                              icon: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(Icons.shopping_bag_outlined, color: Color(0xFF5a331f), size: 24),
                                  if (_cart.isNotEmpty)
                                    Positioned(
                                      right: -4,
                                      top: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Color(0xFF5a331f), shape: BoxShape.circle),
                                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                        child: Text(
                                          _cart.values.reduce((a, b) => a + b).toString(),
                                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    )
                                ],
                              ),
                              onPressed: () => _showCartBottomSheet(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Banner
            Container(
              height: 480,
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=1200'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 45),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: const BoxDecoration(color: Color(0xFFc9a55c)),
                      child: const Text('HANDMADE JEWELRY & ACCESSORIES', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'Montserrat')),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Add a touch of personality to your style.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 38, color: Colors.white, fontStyle: FontStyle.italic, height: 1.2),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 650),
                      child: const Text(
                        'From custom name keychains and Yin-Yang pearl necklaces to vibrant waistbeads and pet accessories, we craft unique accessories for you and your pets.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Montserrat', height: 1.5, shadows: [Shadow(blurRadius: 4, color: Colors.black45)]),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFc9a55c),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                          ),
                          onPressed: () => _scrollToSection(_catalogKey),
                          child: const Text('EXPLORE CATALOG', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Montserrat')),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white, width: 1.5),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                          ),
                          onPressed: () => _scrollToSection(_builderKey),
                          child: const Text('CUSTOM BUILDER', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Montserrat')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Custom Name Piece Visualizer Section
            Padding(
              key: _builderKey,
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFf4e4e1), width: 1),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 25, offset: const Offset(0, 10))],
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: const BoxDecoration(color: Color(0xFFfaf6f1)),
                      child: const Text('CUSTOM NAME CREATOR', style: TextStyle(color: Color(0xFFc9a55c), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'Montserrat')),
                    ),
                    const SizedBox(height: 10),
                    const Text('Design Your Custom Name Piece', style: TextStyle(fontSize: 28, color: Color(0xFF5a331f))),
                    const SizedBox(height: 6),
                    const Text('Type your name below (e.g. SELMA or KENDJIK) to preview your custom keyring or bracelet.', style: TextStyle(fontFamily: 'Montserrat', fontSize: 13, color: Colors.grey), textAlign: TextAlign.center),
                    const SizedBox(height: 30),
                    
                    Container(
                      height: 85,
                      alignment: Alignment.center,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _customNameController,
                        builder: (context, value, child) {
                          String text = value.text.trim().toUpperCase();
                          if (text.isEmpty) text = "?";
                          
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildVisualBead('🔑', isAccent: true),
                                ...text.split('').map((char) => _buildVisualBead(char)),
                                _buildVisualBead('✨', isAccent: true),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 25),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: TextField(
                        controller: _customNameController,
                        onChanged: (val) => setState(() {}),
                        maxLength: 12,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'ENTER NAME (e.g. SELMA)',
                          hintStyle: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, letterSpacing: 1),
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFc9a55c), width: 1.5)),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: const Color(0xFF5a331f).withValues(alpha: 0.2))),
                        ),
                        style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, letterSpacing: 2),
                      ),
                    ),

                    const SizedBox(height: 25),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF5a331f), width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                      ),
                      onPressed: () {
                        final customProduct = _products.firstWhere((p) => p.id == '1', orElse: () => _products.first);
                        _addToCart(customProduct);
                      },
                      child: const Text('ADD CUSTOM CREATION TO BAG', style: TextStyle(color: Color(0xFF5a331f), fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ],
                ),
              ),
            ),

            // Product Catalog Grid
            Container(
              key: _catalogKey,
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
              color: const Color(0xFFfaf6f1),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    children: [
                      const Text('Shop Categories', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w400)),
                      const SizedBox(height: 6),
                      const Text('Handcrafted beaded jewelry & accessories made with care in Opuwo.', style: TextStyle(fontFamily: 'Montserrat', color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 30),
                      
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: TextField(
                              onChanged: (val) => setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                hintText: 'Search keychains, waistbeads, rosaries...',
                                prefixIcon: const Icon(Icons.search, color: Color(0xFFc9a55c)),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: BorderSide.none),
                                hintStyle: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: ['ALL', 'CUSTOM NAME', 'BODY JEWELRY', 'ACCESSORIES', 'SPECIALTY'].map<Widget>((category) {
                            final isSelected = _selectedCategory == category;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0),
                              child: ChoiceChip(
                                label: Text(category),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) setState(() => _selectedCategory = category);
                                },
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFF5a331f),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Montserrat',
                                  letterSpacing: 1,
                                ),
                                selectedColor: const Color(0xFF5a331f),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                                side: BorderSide(color: isSelected ? const Color(0xFF5a331f) : const Color(0xFFe4ded8)),
                                showCheckmark: false,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      
                      const SizedBox(height: 45),
                      
                      filteredProducts.isEmpty 
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Text('No accessories match your search.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                        )
                      : GridView.builder(
                        key: ValueKey(_selectedCategory + _searchQuery + _sortBy + _selectedCurrency + _products.length.toString()),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredProducts.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: crossAxisCount == 2 ? 0.60 : (crossAxisCount == 3 ? 0.66 : 0.72),
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 20,
                        ),
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return _buildPremiumProductCard(product);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Live Price List Section
            Container(
              key: _priceListKey,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      const Text('OFFICIAL CATALOG PRICE LIST', style: TextStyle(color: Color(0xFFc9a55c), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'Montserrat')),
                      const SizedBox(height: 8),
                      const Text('Standard Pricing Guide', style: TextStyle(fontSize: 30, fontFamily: 'Serif')),
                      const SizedBox(height: 35),
                      
                      Wrap(
                        spacing: 20,
                        runSpacing: 12,
                        children: _products.isNotEmpty
                            ? _products.map((p) => _buildPriceBadge(p.name, _formatPrice(p.price))).toList()
                            : [
                                _buildPriceBadge('Beaded Rings', 'N\$ 5'),
                                _buildPriceBadge('Keyholders', 'N\$ 40 - N\$ 70'),
                                _buildPriceBadge('Bracelets', 'N\$ 20 - N\$ 70'),
                                _buildPriceBadge('Rosaries', 'N\$ 100'),
                              ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // About Us / "Meet Pearls By Elly" Brand Section
            Container(
              key: _storyKey,
              color: const Color(0xFFfaf6f1),
              padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Row(
                    children: [
                      if (isDesktop)
                        Expanded(
                          child: Container(
                            height: 380,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFf4e4e1)),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                            ),
                            child: Image.asset(
                              'assets/pearlsbyelly_logo.jpg',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.stars, color: Color(0xFFc9a55c), size: 100),
                            ),
                          ),
                        ),
                      if (isDesktop) const SizedBox(width: 50),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ABOUT OUR BRAND', style: TextStyle(color: Color(0xFFc9a55c), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'Montserrat')),
                            const SizedBox(height: 12),
                            const Text('Meet Pearls By Elly', style: TextStyle(fontSize: 34, fontFamily: 'Serif', height: 1.2, color: Color(0xFF5a331f))),
                            const SizedBox(height: 20),
                            const Text(
                              'We specialize in handcrafted, personalized accessories made with love in Opuwo, Namibia. Whether you are looking for a meaningful rosary, a fun phone charm, stylish waistbeads, or a custom pet accessory, every piece is made with care.',
                              style: TextStyle(fontFamily: 'Montserrat', fontSize: 14, height: 1.6, color: Colors.black87),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'We offer courier delivery so you can get your favorite pieces no matter where you are in Namibia.',
                              style: TextStyle(fontFamily: 'Montserrat', fontSize: 14, height: 1.6, color: Colors.black87),
                            ),
                            const SizedBox(height: 30),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF5a331f), width: 1.5),
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                shape: const RoundedRectangleBorder(),
                              ),
                              onPressed: () => _scrollToSection(_catalogKey),
                              child: const Text('SHOP OUR PIECES', style: TextStyle(color: Color(0xFF5a331f), fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),

            // Instagram Collection Gallery Section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 20),
              color: Colors.white,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    children: [
                      const Text('#PEARLS_BYELLY_ ON INSTAGRAM', style: TextStyle(color: Color(0xFFc9a55c), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'Montserrat')),
                      const SizedBox(height: 8),
                      const Text('Styled by You & Handcrafted in Opuwo', style: TextStyle(fontSize: 30, fontFamily: 'Serif', color: Color(0xFF5a331f))),
                      const SizedBox(height: 35),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          double cardWidth = (constraints.maxWidth - 45) / 4;
                          if (constraints.maxWidth < 600) cardWidth = (constraints.maxWidth - 15) / 2;
                          return Wrap(
                            spacing: 15,
                            runSpacing: 15,
                            children: [
                              _buildInstagramPhoto('https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=500', '@pearls_byelly_', cardWidth),
                              _buildInstagramPhoto('https://images.unsplash.com/photo-1535632066927-ab7c9ab60908?w=500', '@selma_nam', cardWidth),
                              _buildInstagramPhoto('https://images.unsplash.com/photo-1576053139778-7e32f2ae3cfd?w=500', '@kendjik_style', cardWidth),
                              _buildInstagramPhoto('https://images.unsplash.com/photo-1602751584552-8ba73aad10e1?w=500', '@opuwo_vibes', cardWidth),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // FAQ Accordion Section
            Container(
              key: _faqKey,
              color: const Color(0xFFfaf6f1),
              padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      const Text('Frequently Asked Questions', style: TextStyle(fontSize: 30, fontFamily: 'Serif', color: Color(0xFF5a331f))),
                      const SizedBox(height: 8),
                      const Text('Everything you need to know about placing an order with Pearls By Elly.', style: TextStyle(fontFamily: 'Montserrat', color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 40),
                      _buildFaqTile(
                        'How do I place an order via WhatsApp?',
                        'Simply select your favorite items or design a custom name piece, add them to your Bag, and tap "Checkout via WhatsApp Order". A formatted order message will automatically open in WhatsApp addressed to +264816318658.',
                      ),
                      _buildFaqTile(
                        'Do you deliver outside Opuwo?',
                        'Yes! "We Courier" nationwide across Namibia. Whether you are in Windhoek, Swakopmund, Walvis Bay, Rundu, or Katima Mulilo, we deliver directly to your nearest courier station.',
                      ),
                      _buildFaqTile(
                        'Can I request custom names, words, or pet sizes?',
                        'Yes! We craft custom keychains, name bracelets, and pet collar charms personalized with any name or word of your choice.',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Newsletter Subscription Bar
            Container(
              color: const Color(0xFF2e2521),
              padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      const Text('JOIN THE ELLY CLUB', style: TextStyle(color: Color(0xFFc9a55c), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 3, fontFamily: 'Montserrat')),
                      const SizedBox(height: 10),
                      const Text('Be first to hear about new bead drops & Opuwo pop-up market dates.', style: TextStyle(color: Colors.white, fontFamily: 'Montserrat', fontSize: 13), textAlign: TextAlign.center),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newsletterController,
                              style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat', fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Enter your email address',
                                hintStyle: TextStyle(color: Colors.white38, fontFamily: 'Montserrat', fontSize: 13),
                                filled: true,
                                fillColor: Colors.white10,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFc9a55c),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                              shape: const RoundedRectangleBorder(),
                            ),
                            onPressed: () {
                              if (_newsletterController.text.isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✨ Welcome to the Elly VIP Club!')),
                                );
                                _newsletterController.clear();
                              }
                            },
                            child: const Text('JOIN', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat', fontSize: 11)),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),

            // Complete Brand Footer Section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 30),
              color: const Color(0xFF5a331f),
              width: double.infinity,
              child: Column(
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Image.asset(
                      'assets/pearlsbyelly_logo.jpg',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('PEARLS BY ELLY', style: TextStyle(color: Color(0xFFfaf6f1), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4)),
                  const SizedBox(height: 8),
                  const Text('Handmade Jewelry & Accessories • Based in Opuwo, Namibia', style: TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'Montserrat')),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _openUrl('https://wa.me/264816318658'),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat, color: Color(0xFF25D366), size: 16),
                        SizedBox(width: 6),
                        Text('Phone / WhatsApp: +264816318658', style: TextStyle(color: Color(0xFFc9a55c), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Montserrat', decoration: TextDecoration.underline)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(height: 1, width: double.infinity, constraints: const BoxConstraints(maxWidth: 600), color: Colors.white12),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 10,
                    children: [
                      _buildSocialLink('INSTAGRAM: @pearls_byelly_', 'https://instagram.com/pearls_byelly_'),
                      _buildSocialLink('TIKTOK: @pearls_byelly_', 'https://tiktok.com/@pearls_byelly_'),
                      _buildSocialLink('FACEBOOK: Pearls Byelly', 'https://facebook.com/PearlsByelly'),
                    ],
                  ),
                  const SizedBox(height: 28),
                  InkWell(
                    onTap: () => Navigator.pushNamed(context, '/admin'),
                    child: const Text(
                      'Admin Portal Access 🔒',
                      style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'Montserrat', decoration: TextDecoration.underline),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('© 2026 Pearls By Elly. All Rights Reserved.', style: TextStyle(color: Colors.white24, fontSize: 11, fontFamily: 'Montserrat')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavLink(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5a331f),
            fontSize: 10.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontFamily: 'Montserrat',
          ),
        ),
      ),
    );
  }

  Widget _buildVisualBead(String content, {bool isAccent = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isAccent ? const Color(0xFFc9a55c) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF5a331f).withValues(alpha: 0.15), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        content,
        style: TextStyle(
          color: isAccent ? Colors.white : const Color(0xFF5a331f),
          fontWeight: FontWeight.bold,
          fontSize: 16,
          fontFamily: 'Montserrat',
        ),
      ),
    );
  }

  void _showProductDetailModal(Product product) {
    bool wantsCustomName = product.category == 'CUSTOM NAME' || _enablePersonalization;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFfaf6f1),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        product.imageUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(height: 200, color: const Color(0xFFe4ded8), child: const Icon(Icons.image, size: 60, color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5a331f)))),
                        Text(_formatPrice(product.price), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFc9a55c), fontFamily: 'Montserrat')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(product.description, style: const TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.4)),
                    if (product.details.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: product.details.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFFc9a55c)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(d, style: const TextStyle(fontSize: 11.5, fontFamily: 'Montserrat'))),
                            ],
                          ),
                        )).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),

                    // Personalization Toggle Option
                    SwitchListTile(
                      activeThumbColor: const Color(0xFFc9a55c),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Add Personalized Name Beads?', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5a331f), fontSize: 13.5)),
                      subtitle: const Text('Thread custom black & white letter beads onto this piece', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      value: wantsCustomName,
                      onChanged: (val) {
                        setModalState(() {
                          wantsCustomName = val;
                        });
                      },
                    ),

                    if (wantsCustomName) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customNameController,
                        maxLength: 12,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'ENTER NAME (e.g. SELMA or KENDJIK)',
                          hintStyle: TextStyle(fontFamily: 'Montserrat', fontSize: 12),
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        onChanged: (val) {
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildVisualBead('🔑', isAccent: true),
                            ...(_customNameController.text.trim().isEmpty ? '?' : _customNameController.text.trim().toUpperCase())
                                .split('')
                                .map((char) => _buildVisualBead(char)),
                            _buildVisualBead('✨', isAccent: true),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5a331f),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        setState(() {
                          _enablePersonalization = wantsCustomName;
                        });
                        _addToCart(product);
                        Navigator.pop(context);
                      },
                      child: Text(
                        wantsCustomName ? 'ADD PERSONALIZED PIECE TO BAG' : 'ADD STANDARD PIECE TO BAG',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Montserrat', fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPremiumProductCard(Product product) {
    final isWishlisted = _wishlist.contains(product.id);
    return Card(
      elevation: 2,
      child: Stack(
        children: [
          InkWell(
            onTap: () => _showProductDetailModal(product),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(image: NetworkImage(product.imageUrl), fit: BoxFit.cover),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF5a331f)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(_formatPrice(product.price), style: const TextStyle(color: Color(0xFFc9a55c), fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Montserrat')),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: MaterialButton(
                              onPressed: () => _addToCart(product),
                              color: const Color(0xFF5a331f),
                              child: const Text('ADD TO BAG', style: TextStyle(color: Colors.white, fontSize: 9.0, fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.tune, color: Color(0xFF5a331f), size: 18),
                            tooltip: 'Customize & View Details',
                            onPressed: () => _showProductDetailModal(product),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.redAccent : const Color(0xFF5a331f), size: 20),
              onPressed: () => _toggleWishlist(product.id),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBadge(String title, String price) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFfaf6f1),
        border: Border.all(color: const Color(0xFFe4ded8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5a331f))),
          const SizedBox(width: 8),
          Text(price, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFc9a55c))),
        ],
      ),
    );
  }

  Widget _buildInstagramPhoto(String imageUrl, String handle, double size) {
    return InkWell(
      onTap: () => _openUrl('https://instagram.com/pearls_byelly_'),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.25),
          padding: const EdgeInsets.all(12),
          alignment: Alignment.bottomLeft,
          child: Row(
            children: [
              const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(handle, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqTile(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF5a331f))),
        iconColor: const Color(0xFFc9a55c),
        collapsedIconColor: const Color(0xFF5a331f),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Text(answer, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13, height: 1.5, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildSocialLink(String label, String url) {
    return InkWell(
      onTap: () => _openUrl(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFfaf6f1),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontFamily: 'Montserrat',
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFFc9a55c),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.open_in_new, color: Color(0xFFc9a55c), size: 12),
          ],
        ),
      ),
    );
  }

  void _showWishlistBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFfaf6f1),
      builder: (context) {
        final wishlisted = _products.where((p) => _wishlist.contains(p.id)).toList();
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Saved Favorites (${wishlisted.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5a331f))),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: wishlisted.length,
                  itemBuilder: (context, index) {
                    final item = wishlisted[index];
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text(_formatPrice(item.price)),
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFfaf6f1),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Selection Bag (${_cart.values.fold(0, (a, b) => a + b)})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5a331f))),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _cart.length,
                  itemBuilder: (context, index) {
                    final pId = _cart.keys.elementAt(index);
                    final qty = _cart[pId]!;
                    final product = _products.firstWhere((p) => p.id == pId, orElse: () => Product(id: '0', name: 'Item', category: '', price: 0, imageUrl: '', description: '', details: []));
                    final isCustomized = (product.category == 'CUSTOM NAME' || _enablePersonalization) && _customNameController.text.trim().isNotEmpty;

                    return Card(
                      elevation: 0.5,
                      color: Colors.white,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            product.imageUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: const Color(0xFFe4ded8), child: const Icon(Icons.image, size: 24, color: Colors.grey)),
                          ),
                        ),
                        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5a331f))),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_formatPrice(product.price)} x $qty', style: const TextStyle(fontSize: 11.5, color: Color(0xFFc9a55c), fontFamily: 'Montserrat', fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            if (isCustomized)
                              Row(
                                children: [
                                  const Icon(Icons.edit, size: 11, color: Color(0xFFc9a55c)),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text('Custom Name: "${_customNameController.text.trim().toUpperCase()}"', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF5a331f)), overflow: TextOverflow.ellipsis)),
                                ],
                              )
                            else
                              const Text('Style: Standard (No name beads)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                side: const BorderSide(color: Color(0xFF5a331f), width: 1),
                              ),
                              icon: const Icon(Icons.tune, size: 12, color: Color(0xFF5a331f)),
                              label: const Text('CUSTOMIZE', style: TextStyle(fontFamily: 'Montserrat', fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF5a331f))),
                              onPressed: () {
                                Navigator.pop(context);
                                _showProductDetailModal(product);
                              },
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                              tooltip: 'Remove from Bag',
                              onPressed: () {
                                _removeFromCart(pId);
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              StatefulBuilder(
                builder: (context, setCartState) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFfaf6f1),
                      border: Border.all(color: const Color(0xFFe4ded8)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          activeColor: const Color(0xFFc9a55c),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Add Custom Name Beads to Item(s)?', style: TextStyle(fontFamily: 'Montserrat', fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF5a331f))),
                          subtitle: Text(_enablePersonalization && _customNameController.text.trim().isNotEmpty ? 'Name: "${_customNameController.text.trim().toUpperCase()}"' : 'Standard piece (no name beads)', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          value: _enablePersonalization,
                          onChanged: (val) {
                            setCartState(() {
                              _enablePersonalization = val ?? false;
                            });
                            setState(() {});
                          },
                        ),
                        if (_enablePersonalization) ...[
                          const SizedBox(height: 4),
                          TextField(
                            controller: _customNameController,
                            maxLength: 12,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Custom Name (e.g. SELMA or KENDJIK)',
                              isDense: true,
                              counterText: '',
                              border: OutlineInputBorder(),
                            ),
                            style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.bold),
                            onChanged: (val) {
                              setCartState(() {});
                              setState(() {});
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promoCodeController,
                      decoration: const InputDecoration(hintText: 'Promo Code (e.g. ELLY10)', isDense: true, border: OutlineInputBorder()),
                      style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatefulBuilder(
                    builder: (context, setModalState) {
                      return OutlinedButton(
                        onPressed: () => _applyPromoCode(setModalState),
                        child: const Text('APPLY', style: TextStyle(fontFamily: 'Montserrat', fontSize: 10, fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_currentUser == null) ...[
                TextField(
                  controller: _customerNameController,
                  decoration: const InputDecoration(labelText: 'Your Name *', border: OutlineInputBorder()),
                  style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customerEmailController,
                  decoration: const InputDecoration(labelText: 'Email Address *', border: OutlineInputBorder()),
                  style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customerPhoneController,
                  decoration: const InputDecoration(labelText: 'Phone / WhatsApp *', border: OutlineInputBorder()),
                  style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(_formatPrice(_calculateFinalTotal()), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFc9a55c))),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () {
                  _sendWhatsAppOrder();
                  Navigator.pop(context);
                },
                child: const Text('CHECKOUT VIA WHATSAPP ORDER', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// 2. DEDICATED ADMIN PORTAL ROUTE ('/admin')
// ==========================================
class AdminPortalPage extends StatefulWidget {
  const AdminPortalPage({super.key});

  @override
  State<AdminPortalPage> createState() => _AdminPortalPageState();
}

class _AdminPortalPageState extends State<AdminPortalPage> {
  bool _isAuthenticated = false;
  bool _isServerOnline = false;
  bool _obscurePassword = true;

  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _productSearchController = TextEditingController();
  String _errorMessage = '';
  String _orderStatusFilter = 'ALL';
  String _productCategoryFilter = 'ALL';

  List<Product> _adminProducts = [];
  List<OrderModel> _adminOrders = [];
  List<UserModel> _adminUsers = [];
  Map<String, dynamic> _adminStats = {
    'totalRevenue': 0.0,
    'totalOrders': 0,
    'activeProducts': 0,
    'totalUsers': 0,
    'pendingOrders': 0,
  };

  @override
  void initState() {
    super.initState();
    _checkServerAndFetchData();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String urlString) async {
    final Uri uri = Uri.parse(urlString);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  Future<void> _checkServerAndFetchData() async {
    try {
      final statsRes = await http.get(Uri.parse("$gBaseUrl/stats")).timeout(const Duration(seconds: 3));
      if (statsRes.statusCode == 200) {
        setState(() {
          _adminStats = jsonDecode(statsRes.body);
          _isServerOnline = true;
        });
      }

      final prodRes = await http.get(Uri.parse("$gBaseUrl/products"));
      if (prodRes.statusCode == 200) {
        final List<dynamic> list = jsonDecode(prodRes.body);
        setState(() {
          _adminProducts = list.map((e) => Product.fromJson(e)).toList();
        });
      }

      final orderRes = await http.get(Uri.parse("$gBaseUrl/orders"));
      if (orderRes.statusCode == 200) {
        final List<dynamic> list = jsonDecode(orderRes.body);
        setState(() {
          _adminOrders = list.map((e) => OrderModel.fromJson(e)).toList();
        });
      }

      final userRes = await http.get(Uri.parse("$gBaseUrl/users"));
      if (userRes.statusCode == 200) {
        final List<dynamic> list = jsonDecode(userRes.body);
        setState(() {
          _adminUsers = list.map((e) => UserModel.fromJson(e)).toList();
        });
      }
    } catch (e) {
      setState(() => _isServerOnline = false);
    }
  }

  Future<void> _attemptLogin() async {
    final pwd = _passwordController.text.trim();
    if (pwd == 'admin') {
      setState(() {
        _isAuthenticated = true;
        _errorMessage = '';
      });
      _checkServerAndFetchData();
      return;
    }

    try {
      final res = await http.post(
        Uri.parse("$gBaseUrl/admin/login"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': pwd}),
      );
      if (res.statusCode == 200) {
        setState(() {
          _isAuthenticated = true;
          _errorMessage = '';
        });
        _checkServerAndFetchData();
        return;
      }
    } catch (_) {}

    setState(() {
      _errorMessage = 'Invalid Admin Password! Please enter "admin".';
    });
  }

  Future<void> _createNewProduct(Product product) async {
    if (_isServerOnline) {
      try {
        await http.post(
          Uri.parse("$gBaseUrl/products"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(product.toJson()),
        );
      } catch (_) {}
    }
    _checkServerAndFetchData();
  }

  Future<void> _deleteProduct(String id) async {
    if (_isServerOnline) {
      try {
        await http.delete(Uri.parse("$gBaseUrl/products/$id"));
      } catch (_) {}
    }
    _checkServerAndFetchData();
  }

  Future<void> _updateOrderStatus(String code, String status) async {
    if (_isServerOnline) {
      try {
        await http.put(
          Uri.parse("$gBaseUrl/orders/$code/status"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'status': status}),
        );
      } catch (_) {}
    }
    _checkServerAndFetchData();
  }

  Color _getStatusColor(String status) {
    if (status.contains('Delivered')) return Colors.green.shade700;
    if (status.contains('Dispatched')) return Colors.teal.shade700;
    if (status.contains('Threading')) return Colors.amber.shade900;
    if (status.contains('Packed')) return Colors.purple.shade700;
    return const Color(0xFFc9a55c);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return Scaffold(
        backgroundColor: const Color(0xFF2e2521),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 12,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(36.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 70,
                        width: 70,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFfaf6f1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFc9a55c)),
                        ),
                        child: Image.asset(
                          'assets/pearlsbyelly_logo.jpg',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.stars, color: Color(0xFFc9a55c), size: 40),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'PEARLS BY ELLY',
                        style: TextStyle(fontFamily: 'Serif', letterSpacing: 3, fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5a331f)),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFc9a55c).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                        child: const Text('ENTERPRISE ADMIN CONSOLE', style: TextStyle(fontFamily: 'Montserrat', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF5a331f), letterSpacing: 1.2)),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onSubmitted: (_) => _attemptLogin(),
                        decoration: InputDecoration(
                          labelText: 'Admin Password',
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFc9a55c)),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      if (_errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5a331f),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _attemptLogin,
                        child: const Text('AUTHENTICATE & ENTER PORTAL', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                        icon: const Icon(Icons.arrow_back, size: 14, color: Color(0xFFc9a55c)),
                        label: const Text('Return to Customer Storefront', style: TextStyle(color: Color(0xFFc9a55c), fontFamily: 'Montserrat', fontSize: 12, fontWeight: FontWeight.w600)),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 850;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFf8f5f0),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Container(
            color: const Color(0xFF2e2521),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                          child: Image.asset(
                            'assets/pearlsbyelly_logo.jpg',
                            height: 32,
                            width: 32,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.stars, color: Color(0xFFc9a55c), size: 28),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('PEARLS BY ELLY', style: TextStyle(color: Color(0xFFc9a55c), fontFamily: 'Serif', letterSpacing: 2.5, fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('EXECUTIVE ADMIN CONSOLE & FULFILLMENT CENTER', style: TextStyle(color: Colors.white54, fontFamily: 'Montserrat', fontSize: 8, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Spacer(),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isServerOnline ? Colors.green.shade900.withValues(alpha: 0.6) : Colors.orange.shade900.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _isServerOnline ? Colors.greenAccent : Colors.orangeAccent, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _isServerOnline ? Colors.greenAccent : Colors.orangeAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isServerOnline ? 'API ONLINE (5000)' : 'STANDALONE MODE',
                                style: TextStyle(fontSize: 10, fontFamily: 'Montserrat', fontWeight: FontWeight.bold, color: _isServerOnline ? Colors.greenAccent : Colors.orangeAccent),
                              ),
                            ],
                          ),
                        ),

                        if (isDesktop) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFc9a55c)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                            icon: const Icon(Icons.storefront, size: 14, color: Color(0xFFc9a55c)),
                            label: const Text('VISIT STOREFRONT', style: TextStyle(fontFamily: 'Montserrat', fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ),
                        ],

                        const SizedBox(width: 12),
                        PopupMenuButton<String>(
                          icon: CircleAvatar(
                            backgroundColor: const Color(0xFFc9a55c),
                            radius: 16,
                            child: const Text('E', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Montserrat')),
                          ),
                          onSelected: (val) {
                            if (val == 'store') Navigator.pushReplacementNamed(context, '/');
                            if (val == 'logout') setState(() => _isAuthenticated = false);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'store', child: Text('Visit Customer Storefront', style: TextStyle(fontFamily: 'Montserrat', fontSize: 12))),
                            const PopupMenuItem(value: 'logout', child: Text('Logout Admin Console', style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.redAccent))),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Admin Tabs Bar
                  const Expanded(
                    child: TabBar(
                      indicatorColor: Color(0xFFc9a55c),
                      indicatorWeight: 3,
                      labelColor: Color(0xFFc9a55c),
                      unselectedLabelColor: Colors.white60,
                      labelStyle: TextStyle(fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                      tabs: [
                        Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'DASHBOARD'),
                        Tab(icon: Icon(Icons.local_shipping_outlined, size: 18), text: 'ORDERS FULFILLMENT'),
                        Tab(icon: Icon(Icons.people_outline, size: 18), text: 'CUSTOMER ACCOUNTS'),
                        Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: 'CATALOG MANAGER'),
                        Tab(icon: Icon(Icons.settings_system_daydream, size: 18), text: 'SERVER SETTINGS'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // --- TAB 1: EXECUTIVE DASHBOARD ---
            _buildExecutiveDashboardView(),

            // --- TAB 2: ORDERS & COURIER FULFILLMENT ---
            _buildOrdersFulfillmentView(),

            // --- TAB 3: CUSTOMER ACCOUNTS MANAGER ---
            _buildCustomerAccountsView(),

            // --- TAB 4: PRODUCTS MANAGER (CRUD) ---
            _buildProductsManagerView(),

            // --- TAB 5: SERVER HEALTH & DIAGNOSTICS ---
            _buildServerDiagnosticsView(),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: EXECUTIVE DASHBOARD VIEW ---
  Widget _buildExecutiveDashboardView() {
    final double revenue = (_adminStats['totalRevenue'] as num?)?.toDouble() ?? 420.0;
    final int totalOrders = (_adminStats['totalOrders'] as num?)?.toInt() ?? _adminOrders.length;
    final int totalUsers = (_adminStats['totalUsers'] as num?)?.toInt() ?? _adminUsers.length;
    final int pendingOrders = (_adminStats['pendingOrders'] as num?)?.toInt() ?? 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Executive Dashboard Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5a331f))),
                  SizedBox(height: 4),
                  Text('Real-time store performance, catalog metrics, customer accounts & orders.', style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.grey)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFc9a55c),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _checkServerAndFetchData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('REFRESH DATA', style: TextStyle(fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              )
            ],
          ),
          const SizedBox(height: 24),

          // KPI Cards
          Wrap(
            spacing: 20,
            runSpacing: 16,
            children: [
              _buildModernKpiCard('TOTAL REVENUE', 'N\$ ${revenue.toStringAsFixed(2)}', '+14.2% growth', Icons.payments, Colors.green.shade700, Colors.green.shade50),
              _buildModernKpiCard('TOTAL ORDERS', '$totalOrders Orders', '100% fulfill rate', Icons.shopping_bag, Colors.blue.shade700, Colors.blue.shade50),
              _buildModernKpiCard('REGISTERED CUSTOMERS', '$totalUsers Users', 'Accounts created', Icons.people, Colors.purple.shade700, Colors.purple.shade50),
              _buildModernKpiCard('PENDING PIPELINE', '$pendingOrders In Fulfillment', 'Action required', Icons.pending_actions, Colors.orange.shade800, Colors.orange.shade50),
            ],
          ),

          const SizedBox(height: 32),

          // Courier Pipeline Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFe4ded8)),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Courier Order Pipeline (Opuwo -> Nationwide)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5a331f))),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceAround,
                  children: [
                    _buildPipelineStepCard('1. Received', _countOrdersByStatus('Order Received & Confirmed'), Icons.receipt_long, Colors.blue),
                    _buildPipelineStepCard('2. Threading in Opuwo', _countOrdersByStatus('Threading Beads in Opuwo'), Icons.brush, Colors.amber.shade800),
                    _buildPipelineStepCard('3. Packed in Velvet', _countOrdersByStatus('Packed in Signature Velvet Pouch'), Icons.card_giftcard, Colors.purple),
                    _buildPipelineStepCard('4. Dispatched Courier', _countOrdersByStatus('Dispatched via Courier'), Icons.local_shipping, Colors.teal),
                    _buildPipelineStepCard('5. Delivered', _countOrdersByStatus('Delivered'), Icons.verified, Colors.green),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Recent Activity Table
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFe4ded8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recent Store Orders & Customer Attribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5a331f))),
                    Chip(
                      label: Text('${_adminOrders.length} Orders Recorded', style: const TextStyle(fontSize: 10, fontFamily: 'Montserrat', fontWeight: FontWeight.bold, color: Color(0xFF5a331f))),
                      backgroundColor: const Color(0xFFfaf6f1),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                _adminOrders.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: Text('No orders created yet in this session.', style: TextStyle(color: Colors.grey, fontFamily: 'Montserrat'))),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 28,
                          columns: const [
                            DataColumn(label: Text('ORDER CODE', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF5a331f)))),
                            DataColumn(label: Text('CUSTOMER NAME', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF5a331f)))),
                            DataColumn(label: Text('CUSTOMER EMAIL', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF5a331f)))),
                            DataColumn(label: Text('WHATSAPP / PHONE', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF5a331f)))),
                            DataColumn(label: Text('CUSTOM NAME', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF5a331f)))),
                            DataColumn(label: Text('TOTAL', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF5a331f)))),
                            DataColumn(label: Text('STAGE STATUS', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF5a331f)))),
                          ],
                          rows: _adminOrders.take(10).map((o) {
                            return DataRow(cells: [
                              DataCell(Text(o.orderCode, style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, color: Color(0xFFc9a55c)))),
                              DataCell(Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(Text(o.customerEmail, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12))),
                              DataCell(Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 16),
                                    onPressed: () {
                                      final text = Uri.encodeComponent("Hello ${o.customerName}! Re: Your Pearls By Elly Order (${o.orderCode})");
                                      _openUrl("https://wa.me/${o.customerPhone.replaceAll(' ', '')}?text=$text");
                                    },
                                  ),
                                  Text(o.customerPhone, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12)),
                                ],
                              )),
                              DataCell(Text(o.customText.isEmpty ? 'Standard' : '"${o.customText}"', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5a331f)))),
                              DataCell(Text('N\$ ${o.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold))),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(o.status).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _getStatusColor(o.status)),
                                ),
                                child: Text(o.status, style: TextStyle(fontFamily: 'Montserrat', fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(o.status))),
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
              ],
            ),
          )
        ],
      ),
    );
  }

  int _countOrdersByStatus(String statusStr) {
    return _adminOrders.where((o) => o.status == statusStr).length;
  }

  Widget _buildModernKpiCard(String title, String value, String sub, IconData icon, Color mainColor, Color bgText) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe4ded8)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bgText, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: mainColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF5a331f), fontFamily: 'Montserrat')),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(fontSize: 10, fontFamily: 'Montserrat', fontWeight: FontWeight.w600, color: mainColor)),
        ],
      ),
    );
  }

  Widget _buildPipelineStepCard(String label, int count, IconData icon, Color color) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFfaf6f1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text('$count Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Montserrat', color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, fontFamily: 'Montserrat', color: Color(0xFF5a331f), fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // --- TAB 2: ORDERS & COURIER FULFILLMENT VIEW ---
  Widget _buildOrdersFulfillmentView() {
    List<OrderModel> filteredOrders = _adminOrders.where((o) {
      if (_orderStatusFilter == 'ALL') return true;
      return o.status == _orderStatusFilter;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['ALL', 'Order Received & Confirmed', 'Threading Beads in Opuwo', 'Packed in Signature Velvet Pouch', 'Dispatched via Courier', 'Delivered'].map((st) {
                final selected = _orderStatusFilter == st;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(st == 'ALL' ? 'ALL ORDERS (${_adminOrders.length})' : st),
                    selected: selected,
                    onSelected: (val) {
                      if (val) setState(() => _orderStatusFilter = st);
                    },
                    selectedColor: const Color(0xFF5a331f),
                    labelStyle: TextStyle(color: selected ? Colors.white : const Color(0xFF5a331f), fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: filteredOrders.isEmpty
                ? const Center(child: Text('No customer orders match this fulfillment stage.', style: TextStyle(color: Colors.grey, fontFamily: 'Montserrat')))
                : ListView.builder(
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      final statusColor = _getStatusColor(order.status);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: statusColor.withValues(alpha: 0.4))),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: const Color(0xFF5a331f), borderRadius: BorderRadius.circular(6)),
                                        child: Text(order.orderCode, style: const TextStyle(color: Color(0xFFc9a55c), fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF5a331f))),
                                    ],
                                  ),
                                  Text('N\$ ${order.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFc9a55c))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    onPressed: () {
                                      final text = Uri.encodeComponent("Hello ${order.customerName}! Update on your Pearls By Elly order ${order.orderCode}: Current status is [${order.status}].");
                                      _openUrl("https://wa.me/${order.customerPhone.replaceAll(' ', '')}?text=$text");
                                    },
                                    icon: const Icon(Icons.chat, size: 14),
                                    label: Text('WhatsApp ${order.customerPhone}', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  Chip(
                                    label: Text('Email: ${order.customerEmail}', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11, color: Colors.black87)),
                                    backgroundColor: const Color(0xFFfaf6f1),
                                  ),
                                  Chip(
                                    label: Text('Delivery: ${order.courierMethod}', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11, color: Colors.black87)),
                                    backgroundColor: const Color(0xFFfaf6f1),
                                  ),
                                  if (order.customText.isNotEmpty)
                                    Chip(
                                      avatar: const Icon(Icons.edit, size: 12, color: Color(0xFFc9a55c)),
                                      label: Text('CUSTOM NAME: "${order.customText}"', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5a331f))),
                                      backgroundColor: const Color(0xFFfaf6f1),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  const Text('Update Stage Status: ', style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5a331f))),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFfaf6f1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFe4ded8)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: ['Order Received & Confirmed', 'Threading Beads in Opuwo', 'Packed in Signature Velvet Pouch', 'Dispatched via Courier', 'Delivered'].contains(order.status)
                                              ? order.status
                                              : 'Order Received & Confirmed',
                                          isExpanded: true,
                                          style: TextStyle(fontFamily: 'Montserrat', color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                                          onChanged: (newStatus) {
                                            if (newStatus != null) {
                                              _updateOrderStatus(order.orderCode, newStatus);
                                            }
                                          },
                                          items: ['Order Received & Confirmed', 'Threading Beads in Opuwo', 'Packed in Signature Velvet Pouch', 'Dispatched via Courier', 'Delivered'].map((st) {
                                            return DropdownMenuItem(value: st, child: Text(st));
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: CUSTOMER ACCOUNTS MANAGER VIEW ---
  Widget _buildCustomerAccountsView() {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Registered Customer Accounts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF5a331f))),
                  SizedBox(height: 4),
                  Text('Registered customers, emails, phone numbers, and delivery addresses.', style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.grey)),
                ],
              ),
              Chip(
                label: Text('${_adminUsers.length} Customers Registered', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5a331f))),
                backgroundColor: Colors.white,
              )
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _adminUsers.isEmpty
                ? const Center(child: Text('No registered customer accounts found.', style: TextStyle(color: Colors.grey, fontFamily: 'Montserrat')))
                : ListView.builder(
                    itemCount: _adminUsers.length,
                    itemBuilder: (context, index) {
                      final u = _adminUsers[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFe4ded8))),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFc9a55c),
                            child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
                          ),
                          title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF5a331f))),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('📧 Email: ${u.email}', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.black87)),
                              Text('📞 Phone / WhatsApp: ${u.phone}', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.black87)),
                              Text('📍 Delivery Address: ${u.address}', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () {
                              final text = Uri.encodeComponent("Hello ${u.name}! Re: Pearls By Elly Customer Support");
                              _openUrl("https://wa.me/${u.phone.replaceAll(' ', '')}?text=$text");
                            },
                            icon: const Icon(Icons.chat, size: 14),
                            label: const Text('WhatsApp Chat', style: TextStyle(fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- TAB 4: PRODUCTS MANAGER VIEW ---
  Widget _buildProductsManagerView() {
    List<Product> filtered = _adminProducts.where((p) {
      final query = _productSearchController.text.trim().toLowerCase();
      final matchesQuery = query.isEmpty || p.name.toLowerCase().contains(query) || p.category.toLowerCase().contains(query);
      final matchesCat = _productCategoryFilter == 'ALL' || p.category == _productCategoryFilter;
      return matchesQuery && matchesCat;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFe4ded8)),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: TextField(
                    controller: _productSearchController,
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search products by name or category...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFc9a55c)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    ),
                    style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                  ),
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Category: ', style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _productCategoryFilter,
                      style: const TextStyle(fontFamily: 'Montserrat', color: Color(0xFF5a331f), fontSize: 12, fontWeight: FontWeight.bold),
                      onChanged: (val) {
                        if (val != null) setState(() => _productCategoryFilter = val);
                      },
                      items: ['ALL', 'CUSTOM NAME', 'BODY JEWELRY', 'ACCESSORIES', 'SPECIALTY'].map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                    ),
                  ],
                ),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5a331f),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showAddEditProductModal(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('ADD NEW ACCESSORY', style: TextStyle(fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Catalog List
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No catalog products match your search query.', style: TextStyle(color: Colors.grey, fontFamily: 'Montserrat')))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFe4ded8))),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  p.imageUrl,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, width: 70, height: 70, child: const Icon(Icons.image, color: Colors.grey)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFFc9a55c).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                          child: Text(p.category, style: const TextStyle(color: Color(0xFF5a331f), fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
                                        ),
                                        if (p.tag != null && p.tag!.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: const Color(0xFF5a331f), borderRadius: BorderRadius.circular(4)),
                                            child: Text(p.tag!, style: const TextStyle(color: Color(0xFFc9a55c), fontSize: 8, fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF5a331f))),
                                    const SizedBox(height: 2),
                                    Text('N\$ ${p.price.toStringAsFixed(2)} • Rating: ${p.rating}★ (${p.reviewCount} Reviews)', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.black87)),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFc9a55c), side: const BorderSide(color: Color(0xFFc9a55c))),
                                    onPressed: () => _showAddEditProductModal(existingProduct: p),
                                    icon: const Icon(Icons.edit, size: 14),
                                    label: const Text('EDIT', style: TextStyle(fontFamily: 'Montserrat', fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _confirmDeleteProductDialog(p),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProductDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Product Deletion', style: TextStyle(fontFamily: 'Serif')),
        content: Text('Are you sure you want to delete "${product.name}" from the Pearls By Elly catalog?', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontFamily: 'Montserrat'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              await _deleteProduct(product.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('DELETE PRODUCT', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- TAB 5: SERVER DIAGNOSTICS VIEW ---
  Widget _buildServerDiagnosticsView() {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Backend API Host & Diagnostics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF5a331f))),
          const SizedBox(height: 4),
          const Text('Configure backend server API connection and inspect API endpoints.', style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFe4ded8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_isServerOnline ? Icons.check_circle : Icons.warning, color: _isServerOnline ? Colors.green : Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      _isServerOnline ? 'Connected to Node.js Express MongoDB Backend API' : 'Standalone Mode (Express API Server Not Connected)',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: gBaseUrl,
                  onChanged: (val) => gBaseUrl = val,
                  decoration: const InputDecoration(
                    labelText: 'Base API Endpoint URL',
                    hintText: 'http://localhost:5000/api',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFc9a55c),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    await _checkServerAndFetchData();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_isServerOnline ? 'Connected to Express Server API!' : 'Server unreachable at $gBaseUrl')),
                    );
                  },
                  icon: const Icon(Icons.sync),
                  label: const Text('TEST & SAVE SERVER CONNECTION', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1e1e1e),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('API Endpoint Structure Explorer', style: TextStyle(color: Color(0xFFc9a55c), fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  const Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        'POST /api/users/register -> Customer Account Registration\n'
                        'POST /api/users/login    -> Customer Account Authentication\n'
                        'GET  /api/users          -> Admin Customer Accounts List\n\n'
                        'GET  /api/products       -> List all catalog items\n'
                        'POST /api/products       -> Create new catalog accessory\n'
                        'PUT  /api/products/:id   -> Update product details\n'
                        'DEL  /api/products/:id   -> Delete product\n\n'
                        'GET  /api/orders         -> List all customer orders\n'
                        'POST /api/orders         -> Register new WhatsApp order\n'
                        'PUT  /api/orders/:code/status -> Update fulfillment step\n'
                        'GET  /api/orders/track?code=... -> Customer order status lookup\n\n'
                        'GET  /api/stats          -> Revenue, total orders & active items',
                        style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12, height: 1.5),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditProductModal({Product? existingProduct}) {
    final isEdit = existingProduct != null;
    final nameCtrl = TextEditingController(text: isEdit ? existingProduct.name : '');
    final catCtrl = TextEditingController(text: isEdit ? existingProduct.category : 'ACCESSORIES');
    final priceCtrl = TextEditingController(text: isEdit ? existingProduct.price.toString() : '50');
    final imgCtrl = TextEditingController(text: isEdit ? existingProduct.imageUrl : 'https://images.unsplash.com/photo-1602751584552-8ba73aad10e1?w=600');
    final descCtrl = TextEditingController(text: isEdit ? existingProduct.description : '');
    final tagCtrl = TextEditingController(text: isEdit ? existingProduct.tag ?? '' : 'NEW');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                Icon(isEdit ? Icons.edit : Icons.add_box, color: const Color(0xFFc9a55c)),
                const SizedBox(width: 8),
                Text(isEdit ? 'Edit Product Details' : 'Add New Accessory to Catalog', style: const TextStyle(fontFamily: 'Serif', fontSize: 18, color: Color(0xFF5a331f))),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imgCtrl.text.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(child: Text('Image Preview Placeholder', style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.grey))),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder()),
                      style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: catCtrl,
                            decoration: const InputDecoration(labelText: 'Category (e.g. CUSTOM NAME)', border: OutlineInputBorder()),
                            style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Price in N\$ *', border: OutlineInputBorder()),
                            style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: imgCtrl,
                      onChanged: (_) => setModalState(() {}),
                      decoration: const InputDecoration(labelText: 'Image URL *', border: OutlineInputBorder()),
                      style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                      style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tagCtrl,
                      decoration: const InputDecoration(labelText: 'Product Tag Badge (e.g. BESTSELLER, BOHO CHIC)', border: OutlineInputBorder()),
                      style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontFamily: 'Montserrat'))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5a331f), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                onPressed: () async {
                  if (nameCtrl.text.trim().isNotEmpty) {
                    final newProd = Product(
                      id: isEdit ? existingProduct.id : DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text.trim(),
                      category: catCtrl.text.trim().toUpperCase(),
                      price: double.tryParse(priceCtrl.text.trim()) ?? 50.0,
                      imageUrl: imgCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      details: ['Handcrafted in Opuwo', 'Customizable bead accents'],
                      tag: tagCtrl.text.trim().toUpperCase(),
                    );

                    await _createNewProduct(newProd);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: Text(isEdit ? 'SAVE CHANGES' : 'CREATE PRODUCT', style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String title;
  final String price;

  const _PriceRow(this.title, this.price);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF5a331f))),
          Text(price, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFc9a55c))),
        ],
      ),
    );
  }
}

