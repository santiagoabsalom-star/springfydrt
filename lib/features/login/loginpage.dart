import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:springfydrt/features/login/api/login.dart';
import 'package:springfydrt/features/navigation/presentation/pages/main_page.dart';
import 'package:path/path.dart' as p;

import '../../core/log.dart';
import '../../core/network/api_connect.dart';
import 'api/dto.dart';
import 'api/token.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _saveOnFile(LoginRequest loginReq) async {
    try {
      Directory dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, "loginInfo.json"));
      const encoder = JsonEncoder.withIndent("  ");

      final jsonString = encoder.convert(loginReq.toJson());
      await file.writeAsString(jsonString);
    } catch (e) {
      Log.d("Error saving login info: $e");
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final request = LoginRequest(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    try {
      final response = await login(request).timeout(const Duration(seconds: 15));

      if (response.httpCode == 200 && response.token != null) {
        await _saveOnFile(request);
        await TokenStorage.saveLogin(
          token: response.token!,
          username: response.username ?? "",
          id: response.id ?? 0,
        );

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainPage()),
          );
        }
      } else {
        setState(() {
          _errorMessage = response.message ?? response.response ?? "Credenciales incorrectas";
        });
      }
    } on SocketException {
      setState(() => _errorMessage = "No se pudo conectar con el servidor. Verifica tu conexión.");
    } on TimeoutException {
      setState(() => _errorMessage = "El servidor tardó demasiado en responder.");
    } on FormatException {
      setState(() => _errorMessage = "Error en el formato de respuesta del servidor.");
    } catch (e) {
      setState(() => _errorMessage = "Ocurrió un error inesperado. Inténtalo de nuevo.");
      Log.d("Login error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [

          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.primary,
                  colorScheme.tertiary,
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          IconButton(onPressed: () async {
            await parameditDialog();
          }, icon:const Icon(Icons.info, size: 30),),
          SafeArea(
            child: Center(
              
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Hero(
                          tag: 'app_logo',
                          child: Image(
                            image: AssetImage('assets/icon.png'),
                            height: 100,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Springfy',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 48),
                        
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Card(
                            elevation: 16,
                            shadowColor: Colors.black26,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'INICIAR SESIÓN',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: colorScheme.primary,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    
                                    // Username Field
                                    TextFormField(
                                      controller: _usernameController,
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        labelText: 'Usuario',
                                        prefixIcon: const Icon(Icons.person_outline),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                                        ),
                                        filled: true,
                                        fillColor: colorScheme.surfaceVariant.withOpacity(0.1),
                                      ),
                                      validator: (value) => (value == null || value.trim().isEmpty) 
                                          ? "El usuario es obligatorio" : null,
                                      enabled: !_isLoading,
                                    ),
                                    const SizedBox(height: 20),
                                    
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _handleLogin(),
                                      decoration: InputDecoration(
                                        labelText: 'Contraseña',
                                        prefixIcon: const Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                          icon: Icon(_obscurePassword 
                                            ? Icons.visibility_outlined 
                                            : Icons.visibility_off_outlined),
                                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                                        ),
                                        filled: true,
                                        fillColor: colorScheme.surfaceVariant.withOpacity(0.1),
                                      ),
                                      validator: (value) => (value == null || value.trim().isEmpty) 
                                          ? "La contraseña es obligatoria" : null,
                                      enabled: !_isLoading,
                                    ),
                                    
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      transitionBuilder: (child, animation) => FadeTransition(
                                        opacity: animation,
                                        child: SizeTransition(sizeFactor: animation, child: child),
                                      ),
                                      child: _errorMessage != null
                                          ? Container(
                                              key: ValueKey(_errorMessage),
                                              padding: const EdgeInsets.only(top: 20),
                                              child: Text(
                                                _errorMessage!,
                                                style: TextStyle(
                                                  color: colorScheme.error,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            )
                                          : const SizedBox(key: ValueKey('none')),
                                    ),
                                    
                                    const SizedBox(height: 40),
                                    
                                    SizedBox(

                                      width: double.infinity,
                                      height: 56,
                                      child:

                                        ElevatedButton(
                                        onPressed: _isLoading ? null : _handleLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: colorScheme.primary,
                                          foregroundColor: colorScheme.onPrimary,
                                          elevation: 4,
                                          shadowColor: colorScheme.primary.withOpacity(0.4),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 24,
                                                width: 24,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text(
                                                'ENTRAR',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                      ),


                                      )

                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  static ValueNotifier<String?> selectedValue=ValueNotifier<String?>(ApiConnect.baseUrl);
  Future<void> parameditDialog() {
    final TextEditingController ipController = TextEditingController(text: ApiConnect.baseUrl);


    const presets = [
      'http://springfy.tplinkdns.com:3051',
      'http://192.168.0.104:3050',
    ];

    return showDialog<String?>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Configuración de API",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Presets rápidos",
                  style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder(
                  valueListenable: selectedValue,
                  builder: (_, sValue, __) {
                    final dropdownValue = presets.contains(sValue) ? sValue : null;

                    return DropdownButtonFormField<String>(
                      value: dropdownValue,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      hint: const Text("Selecciona un preset"),
                      items: const [
                        DropdownMenuItem(
                          value: 'http://springfy.tplinkdns.com:3051',
                          child: Text("Ip externa"),
                        ),
                        DropdownMenuItem(
                          value: 'http://192.168.0.104:3050',
                          child: Text("Ip Local"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          selectedValue.value = value;
                          ipController.text = value;
                          ApiConnect.baseUrl = value;
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  "IP Manual",
                  style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ipController,
                  decoration: InputDecoration(
                    hintText: "http://tu-ip:puerto",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.link),
                  ),
                  onChanged: (value) {
                    ApiConnect.baseUrl = value;

                    selectedValue.value = value;

                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("ACEPTAR"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
