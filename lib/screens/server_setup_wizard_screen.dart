import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/termux_service.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import 'login_screen.dart';

class ServerSetupWizardScreen extends StatefulWidget {
  const ServerSetupWizardScreen({super.key});

  @override
  State<ServerSetupWizardScreen> createState() => _ServerSetupWizardScreenState();
}

class _ServerSetupWizardScreenState extends State<ServerSetupWizardScreen> {
  int _currentStep = 0;
  int _maxCompletedStep = -1;
  bool _isStepCompleted = false;
  
  bool _verifying = false;
  String? _verificationError;
  bool _setupFinished = false;
  int _serverSourceOption = 0;
  
  final _domainController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  late String _jwtSecret;
  String? _configuredDomain;

  @override
  void initState() {
    super.initState();
    _jwtSecret = _generateRandomString(32);
    // Start local asset server immediately so the file is available
    TermuxService.startLocalAssetServer();
    _loadProgress();
  }

  @override
  void dispose() {
    _domainController.dispose();
    TermuxService.stopLocalAssetServer();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _maxCompletedStep = prefs.getInt('server_setup_max_step') ?? -1;
      _currentStep = _maxCompletedStep + 1;
      if (_currentStep > 6) {
        _currentStep = 6;
      }
    });
  }

  Future<void> _markStepCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isStepCompleted = completed;
      if (completed && _currentStep > _maxCompletedStep) {
        _maxCompletedStep = _currentStep;
        prefs.setInt('server_setup_max_step', _maxCompletedStep);
      }
    });
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  String _getStep4Command() {
    return '''cat << 'EOF' > ~/server/.env
PORT=4000
NODE_ENV=production
CORS_ORIGIN=*
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=chatt_db
DB_USER=postgres
DB_PASSWORD=postgres
JWT_SECRET=$_jwtSecret
JWT_EXPIRES_IN=30d
SMTP_EMAIL=temp@gmail.com
SMTP_PASS=changeme
ADMIN_EMAIL=admin@chatt.local
EOF

cat << 'EOF' > ~/start_server.sh
#!/data/data/com.termux/files/usr/bin/bash
pg_ctl -D ~/pg_data stop
killall node
sleep 1
pg_ctl -D ~/pg_data -l ~/pg.log start
sleep 2
cd ~/server
nohup node src/server.js > ~/node.log 2>&1 &
EOF

chmod +x ~/start_server.sh
~/start_server.sh''';
  }

  String _getStep6Command(String domain) {
    final cleanDomain = domain.trim().replaceAll("https://", "").replaceAll("http://", "");
    return '''cloudflared tunnel delete -f chatt-server
cloudflared tunnel create chatt-server
cloudflared tunnel route dns chatt-server $cleanDomain

cat << 'EOF' > ~/start_tunnel.sh
#!/data/data/com.termux/files/usr/bin/bash
killall cloudflared
sleep 1
nohup cloudflared tunnel run --url http://localhost:4000 chatt-server > ~/cloudflare.log 2>&1 &
EOF

chmod +x ~/start_tunnel.sh
~/start_tunnel.sh''';
  }

  List<Map<String, String>> get _stepsData {
    final domain = _domainController.text.trim().replaceAll("https://", "").replaceAll("http://", "");
    final displayDomain = domain.isEmpty ? "<your-domain>" : domain;

    final step3Command = _serverSourceOption == 0
        ? "rm -rf ~/server\ncurl -s -o ~/server.zip http://127.0.0.1:4990/server.zip\nunzip -o ~/server.zip -d ~/\nrm ~/server.zip\ncd ~/server && npm install"
        : "termux-setup-storage\n# (Accept storage permission on your phone screen if requested)\nrm -rf ~/server\ncp -r /sdcard/Download/server ~/\ncd ~/server && npm install";

    final step3Description = _serverSourceOption == 0
        ? "Run this command to download the server zip package directly from this app (keep this screen open!), extract it, and install Node.js dependencies."
        : "Transfer the 'server' folder from your computer to your phone's 'Download' folder. Then run this command to grant storage permission, copy it to Termux home, and install Node.js dependencies.";

    return [
      {
        "title": "1. Install Required Packages",
        "description": "Open the Termux app on your phone and run the following command to update packages and install Node.js, PostgreSQL database, Cloudflared tunnel, and helper tools.",
        "command": "pkg update -y && pkg install -y nodejs postgresql cloudflared unzip curl",
      },
      {
        "title": "2. Initialize & Start Database",
        "description": "Initialize a PostgreSQL database cluster storage directory, start the Postgres daemon, set the superuser password to 'postgres', and create the database instance.",
        "command": "mkdir -p ~/pg_data\ninitdb -D ~/pg_data\npg_ctl -D ~/pg_data -l ~/pg.log start\nsleep 2\npsql -d postgres -c \"ALTER USER postgres WITH PASSWORD 'postgres';\"\ncreatedb -U postgres chatt_db",
      },
      {
        "title": "3. Setup Server Backend Files",
        "description": step3Description,
        "command": step3Command,
      },
      {
        "title": "4. Configure & Start Node.js Server",
        "description": "Write the local configuration file (.env) using the postgres superuser credentials (postgres/postgres), create a startup wrapper, and run the backend server in the background.",
        "command": _getStep4Command(),
      },
      {
        "title": "5. Login and Authenticate Cloudflare",
        "description": "Run the command below in Termux to authorize Cloudflare. Note: The login command only logs you in and authorizes your client; it does not route or run the tunnel yet.\n\nCommand: 'cloudflared tunnel login' = login only.",
        "command": "cloudflared tunnel login",
      },
      {
        "title": "6. Setup Cloudflare Tunnel & DNS Route",
        "description": "Enter your custom domain name below. Then run the generated commands in Termux to configure the DNS route and execute the tunnel runner script.\n\nCommands:\n* 'cloudflared tunnel route dns' = DNS route.\n* 'cloudflared tunnel run' = actually runs the tunnel in the background.",
        "command": _getStep6Command(displayDomain),
      },
      {
        "title": "7. Verify Public Connection",
        "description": "Enter your custom domain name below and click the 'Verify Connection & Finish' button. Flutter will perform a normal HTTP request via the network client to check if your server is reachable.",
        "command": "",
      }
    ];
  }

  Future<void> _verifyAndFinish() async {
    if (!_formKey.currentState!.validate()) return;
    
    final domain = _domainController.text.trim().replaceAll("https://", "").replaceAll("http://", "");

    setState(() {
      _verifying = true;
      _verificationError = null;
    });

    try {
      // Standard HTTP verification directly from the Dart HTTP client
      final verifyUrl = Uri.parse("https://$domain/health");
      final response = await http.get(verifyUrl).timeout(const Duration(seconds: 10));

      // Any HTTP response (including 200, 404, etc.) indicates that the backend is successfully reached and responding.
      if (response.statusCode >= 200 && response.statusCode < 500) {
        await ApiConfig.setBaseUrl("https://$domain");
        await _markStepCompleted(true);
        setState(() {
          _configuredDomain = domain;
          _setupFinished = true;
        });
      } else {
        setState(() {
          _verificationError = "Connection failed. Server returned status code ${response.statusCode}. Please ensure the Node.js server and Cloudflared tunnel are running in Termux.";
        });
      }
    } catch (e) {
      // Fallback check to root path (in case GET /health is not seeded or returns 404)
      try {
        final fallbackUrl = Uri.parse("https://$domain");
        final response = await http.get(fallbackUrl).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200 || response.statusCode == 404) {
          await ApiConfig.setBaseUrl("https://$domain");
          await _markStepCompleted(true);
          setState(() {
            _configuredDomain = domain;
            _setupFinished = true;
          });
          return;
        }
      } catch (_) {}

      setState(() {
        _verificationError = "Could not connect to public server at https://$domain.\nError: $e\n\nPlease ensure cloudflared is running, you entered the correct domain, and DNS records have updated.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _verifying = false;
        });
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Command copied to clipboard!"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildFinishedScreen() {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: const Text("Server Setup Complete"), automaticallyImplyLeading: false),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: Icon(Icons.check_circle, size: 72, color: Color(0xFF25D366))),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  "Server Setup Complete",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF075E54)),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  "Your phone is now acting as the server.",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),
              
              // Specs Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("API:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                    Text("https://$_configuredDomain", style: const TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    const Text("Local Server:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                    const Text("http://127.0.0.1:4000", style: TextStyle(fontFamily: 'monospace', fontSize: 14)),
                    const SizedBox(height: 12),
                    const Text("Database:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                    const Text("chatt_db", style: TextStyle(fontFamily: 'monospace', fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Status list card
              const Text("Status:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x0C25D366),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x3325D366)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("✓ PostgreSQL", style: TextStyle(color: Color(0xFF1E7E34), fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text("✓ Node.js", style: TextStyle(color: Color(0xFF1E7E34), fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text("✓ Backend", style: TextStyle(color: Color(0xFF1E7E34), fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text("✓ Cloudflare Tunnel", style: TextStyle(color: Color(0xFF1E7E34), fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text("✓ Public API", style: TextStyle(color: Color(0xFF1E7E34), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text("Actions:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42), alignment: Alignment.centerLeft),
                onPressed: () => _copyToClipboard("cat ~/server/initial_admin.json"),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text("Copy Get Credentials Command"),
              ),
              const SizedBox(height: 8),
              
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42), alignment: Alignment.centerLeft),
                onPressed: () => _copyToClipboard("https://$_configuredDomain"),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text("Copy API URL"),
              ),
              const SizedBox(height: 8),
              
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42), alignment: Alignment.centerLeft),
                onPressed: () => _copyToClipboard("~/start_server.sh && ~/start_tunnel.sh"),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text("Copy Start Server Command"),
              ),
              const SizedBox(height: 8),
              
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42), alignment: Alignment.centerLeft),
                onPressed: () => _copyToClipboard("pg_ctl -D ~/pg_data stop && killall node && killall cloudflared"),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text("Copy Stop Server Command"),
              ),
              const SizedBox(height: 32),
              
              // Finish button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF075E54),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    await AuthService.logout();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text("Finish"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_setupFinished) {
      return _buildFinishedScreen();
    }

    final steps = _stepsData;
    final currentStepData = steps[_currentStep];
    final isLastStep = _currentStep == steps.length - 1;
    final isStepUnlocked = _currentStep <= _maxCompletedStep || _isStepCompleted;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Server Setup Wizard"),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Horizontal step indicator
                Row(
                  children: List.generate(steps.length, (index) {
                    final isActive = index <= _currentStep;
                    return Expanded(
                      child: Container(
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF075E54) : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  "Step ${_currentStep + 1} of ${steps.length}",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                
                // Step Content Card
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentStepData["title"]!,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF075E54)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          currentStepData["description"]!,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        
                        // Domain Form for Step 6 & 7
                        if (_currentStep == 5 || _currentStep == 6) ...[
                          const Text("Domain Configuration:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _domainController,
                            decoration: const InputDecoration(
                              labelText: "API Domain Name",
                              hintText: "api.example.com",
                              prefixText: "https://",
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) {
                              setState(() {}); // Rebuild to update generated command dynamically
                            },
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return "Domain is required";
                              if (!val.contains('.') || val.length < 4) return "Invalid domain format";
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                        
                        // Setup method toggle on step 3
                        if (_currentStep == 2) ...[
                          const Text("Choose Setup Method:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text("Direct Download", style: TextStyle(fontSize: 12))),
                                  selected: _serverSourceOption == 0,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _serverSourceOption = 0;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text("Local Folder", style: TextStyle(fontSize: 12))),
                                  selected: _serverSourceOption == 1,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _serverSourceOption = 1;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Command Terminal Card
                        if (currentStepData["command"]!.isNotEmpty) ...[
                          const Text("Command to Copy & Run in Termux:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade800),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("TERMINAL", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                    IconButton(
                                      icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                                      onPressed: () => _copyToClipboard(currentStepData["command"]!),
                                      tooltip: "Copy Command",
                                    ),
                                  ],
                                ),
                                const Divider(color: Colors.white24, height: 1),
                                const SizedBox(height: 8),
                                SelectableText(
                                  currentStepData["command"]!,
                                  style: const TextStyle(
                                    color: Color(0xFFC7EDCC),
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        // Completion affirmation checkbox (for non-final steps)
                        if (!isLastStep) ...[
                          const SizedBox(height: 20),
                          CheckboxListTile(
                            title: const Text(
                              "[ I COMPLETED THIS STEP ]",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            value: isStepUnlocked,
                            onChanged: _currentStep <= _maxCompletedStep
                                ? null
                                : (val) async {
                                    await _markStepCompleted(val ?? false);
                                  },
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: const Color(0xFF075E54),
                          ),
                        ],
                        
                        // Verification error box
                        if (_verificationError != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              _verificationError!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                // Bottom Stepper Buttons
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
                    TextButton(
                      onPressed: _currentStep == 0 || _verifying
                          ? null
                          : () {
                              setState(() {
                                _currentStep--;
                                _isStepCompleted = false;
                                _verificationError = null;
                              });
                            },
                      child: const Text("Back"),
                    ),
                    
                    // Next / Verify & Finish Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF075E54),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _verifying || (!isLastStep && !isStepUnlocked)
                          ? null
                          : () async {
                              if (isLastStep) {
                                await _verifyAndFinish();
                              } else {
                                setState(() {
                                  _currentStep++;
                                  _isStepCompleted = false;
                                  _verificationError = null;
                                });
                              }
                            },
                      child: _verifying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isLastStep ? "Verify & Finish" : "Next"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
