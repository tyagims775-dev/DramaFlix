import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    runApp(const DramaFlixApp(firebaseReady: true));
  } catch (e) {
    runApp(const DramaFlixApp(firebaseReady: false));
  }
}

class DramaFlixApp extends StatelessWidget {
  final bool firebaseReady;
  const DramaFlixApp({super.key, required this.firebaseReady});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DramaFlix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF100E12),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB52645),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: firebaseReady
          ? const HomeScreen()
          : const FirebaseSetupScreen(),
    );
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('DramaFlix setup')),
        body: const Padding(
          padding: EdgeInsets.all(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 58),
              SizedBox(height: 16),
              Text('Firebase abhi connect nahi hai',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text(
                'Firebase project banayein, Android app register karein, '
                'google-services.json ko android/app/ mein rakhein, '
                'Gradle mein Google Services plugin configure karein, '
                'phir app dobara build karein.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  String category = 'All';
  Set<String> saved = {};

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => saved = (p.getStringList('watchlist') ?? []).toSet());
  }

  Future<void> _toggleSaved(String id) async {
    final next = {...saved};
    next.contains(id) ? next.remove(id) : next.add(id);
    final p = await SharedPreferences.getInstance();
    await p.setStringList('watchlist', next.toList());
    if (mounted) setState(() => saved = next);
  }

  @override
  Widget build(BuildContext context) {
    final isWatchlist = tab == 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DramaFlix', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Admin panel',
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const AdminLoginScreen())),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('shows').orderBy('updatedAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Shows load nahi ho rahe. Firestore rules aur setup check karein.'),
            ));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          final filtered = docs.where((d) {
            final data = d.data();
            final cat = (data['category'] ?? 'Other').toString();
            final matchesCategory = category == 'All' || cat == category;
            final matchesTab = !isWatchlist || saved.contains(d.id);
            return matchesCategory && matchesTab;
          }).toList();
          final categories = <String>{'All', ...docs.map((d) => (d.data()['category'] ?? 'Other').toString())};
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (!isWatchlist) _hero(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Text(isWatchlist ? 'MY WATCHLIST' : 'CATEGORIES',
                    style: const TextStyle(color: Color(0xFFE8B5BF), letterSpacing: 1.4, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: categories.map((c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(c), selected: category == c,
                      onSelected: (_) => setState(() => category = c)),
                  )).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Text(isWatchlist ? 'SAVED SHOWS' : 'LATEST MICRO-DRAMAS',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Abhi shows nahi hain. Admin panel se pehla show add karein.'),
                ),
              ...filtered.map((doc) {
                final d = doc.data();
                return Card(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  color: const Color(0xFF1B181E),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Container(
                      width: 62, height: 80,
                      decoration: BoxDecoration(
                        color: Color((d['color'] as num?)?.toInt() ?? 0xFF8E2035),
                        borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.movie_outlined, size: 32),
                    ),
                    title: Text((d['title'] ?? 'Untitled show').toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${d['category'] ?? 'Other'}\n${d['tagline'] ?? ''}'),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: Icon(saved.contains(doc.id) ? Icons.bookmark : Icons.bookmark_border),
                      onPressed: () => _toggleSaved(doc.id),
                    ),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ShowScreen(showId: doc.id, data: d))),
                  ),
                );
              }),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.local_movies_outlined), selectedIcon: Icon(Icons.local_movies), label: 'Shows'),
          NavigationDestination(icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: 'Watchlist'),
        ],
      ),
    );
  }

  Widget _hero() => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    height: 185,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(colors: [Color(0xFF8E2035), Color(0xFF171219)])),
    child: const Padding(
      padding: EdgeInsets.all(20),
      child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DRAMAFLIX ORIGINAL', style: TextStyle(letterSpacing: 1.4, color: Color(0xFFFFD5DD))),
          SizedBox(height: 8),
          Text('Your next obsession.', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          Text('Short episodes. Big twists.'),
        ],
      ),
    ),
  );
}

class ShowScreen extends StatelessWidget {
  final String showId;
  final Map<String, dynamic> data;
  const ShowScreen({super.key, required this.showId, required this.data});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text((data['title'] ?? 'Show').toString())),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('shows').doc(showId)
        .collection('episodes').orderBy('episodeNumber').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Episodes load nahi hue.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final eps = snapshot.data!.docs;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text((data['category'] ?? '').toString().toUpperCase(),
            style: const TextStyle(color: Color(0xFFE8B5BF), letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text((data['title'] ?? '').toString(),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text((data['tagline'] ?? '').toString()),
          const SizedBox(height: 24),
          const Text('EPISODES', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (eps.isEmpty) const Padding(
            padding: EdgeInsets.only(top: 18),
            child: Text('Is show ke episodes abhi publish nahi hue.'),
          ),
          ...eps.map((e) {
            final ep = e.data();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.play_circle_outline, size: 38),
                title: Text('Episode ${ep['episodeNumber'] ?? ''}: ${ep['title'] ?? ''}'),
                subtitle: Text('${ep['duration'] ?? ''} ${ep['description'] ?? ''}'),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PlayerScreen(title: (ep['title'] ?? 'Episode').toString(),
                    videoUrl: (ep['videoUrl'] ?? '').toString()))),
              ),
            );
          }),
        ]);
      },
    ),
  );
}

class PlayerScreen extends StatefulWidget {
  final String title;
  final String videoUrl;
  const PlayerScreen({super.key, required this.title, required this.videoUrl});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final VideoPlayerController controller;
  String? error;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) { if (mounted) setState(() {}); })
        .catchError((Object _) { if (mounted) setState(() => error = 'Video load nahi hua. URL ya internet check karein.'); });
  }

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    backgroundColor: Colors.black,
    body: Center(
      child: error != null ? Padding(padding: const EdgeInsets.all(24), child: Text(error!))
      : !controller.value.isInitialized ? const CircularProgressIndicator()
      : AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: Column(children: [
            Expanded(child: Center(child: AspectRatio(
              aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller)))),
            VideoProgressIndicator(controller, allowScrubbing: true, padding: const EdgeInsets.all(14)),
            IconButton.filled(
              iconSize: 40,
              onPressed: () => setState(() => controller.value.isPlaying ? controller.pause() : controller.play()),
              icon: Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow)),
            const SizedBox(height: 18),
          ]),
        ),
    ),
  );
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? message;

  Future<void> login() async {
    setState(() { busy = true; message = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(), password: password.text);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
    } on FirebaseAuthException catch (e) {
      setState(() => message = e.message ?? 'Login fail hua.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Admin login')),
    body: ListView(padding: const EdgeInsets.all(22), children: [
      const Icon(Icons.admin_panel_settings, size: 56),
      const SizedBox(height: 14),
      const Text('Sirf app owner ke liye', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 18),
      TextField(controller: email, keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Admin email', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: password, obscureText: true,
        decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
      const SizedBox(height: 16),
      if (message != null) Text(message!, style: const TextStyle(color: Colors.redAccent)),
      FilledButton(onPressed: busy ? null : login,
        child: Text(busy ? 'Login ho raha hai...' : 'Login')),
      const SizedBox(height: 12),
      const Text('Admin account Firebase Console mein manually create karein. App mein signup option nahi hai.',
        style: TextStyle(color: Colors.white60, fontSize: 12)),
    ]),
  );
}

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [IconButton(
          tooltip: 'Logout', icon: const Icon(Icons.logout),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) Navigator.pop(context);
          })],
      ),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Content management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Logged in: ${user?.email ?? 'unknown'}', style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 20),
        FilledButton.icon(
          icon: const Icon(Icons.add_to_photos),
          label: const Text('Naya show add karein'),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddShowScreen())),
        ),
        const SizedBox(height: 12),
        const Text('Shows', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('shows').orderBy('updatedAt', descending: true).snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return const Text('Firestore access denied. Security rules check karein.');
            if (!snap.hasData) return const LinearProgressIndicator();
            if (snap.data!.docs.isEmpty) return const Padding(
              padding: EdgeInsets.all(16), child: Text('Abhi koi show nahi. Add show se shuru karein.'));
            return Column(children: snap.data!.docs.map((d) => Card(
              child: ListTile(
                title: Text((d.data()['title'] ?? 'Untitled').toString()),
                subtitle: Text((d.data()['category'] ?? '').toString()),
                trailing: IconButton(
                  tooltip: 'Delete show',
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                      title: const Text('Show delete karein?'),
                      content: const Text('Isse show record delete hoga. Episodes aur uploaded files alag se delete karne pad sakte hain.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                      ],
                    ));
                    if (ok == true) await d.reference.delete();
                  },
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ManageEpisodesScreen(showId: d.id, showTitle: (d.data()['title'] ?? '').toString()))),
              ),
            )).toList());
          },
        ),
      ]),
    );
  }
}

class AddShowScreen extends StatefulWidget {
  const AddShowScreen({super.key});
  @override
  State<AddShowScreen> createState() => _AddShowScreenState();
}

class _AddShowScreenState extends State<AddShowScreen> {
  final title = TextEditingController();
  final tagline = TextEditingController();
  final category = TextEditingController(text: 'Revenge Thriller');
  bool busy = false;
  String? message;

  Future<void> save() async {
    if (title.text.trim().isEmpty) { setState(() => message = 'Show title zaroori hai.'); return; }
    setState(() { busy = true; message = null; });
    try {
      await FirebaseFirestore.instance.collection('shows').add({
        'title': title.text.trim(),
        'tagline': tagline.text.trim(),
        'category': category.text.trim().isEmpty ? 'Other' : category.text.trim(),
        'color': 0xFF8E2035,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => message = 'Save fail hua. Firebase rules check karein.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() { title.dispose(); tagline.dispose(); category.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add show')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      TextField(controller: title, decoration: const InputDecoration(labelText: 'Show title', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: tagline, decoration: const InputDecoration(labelText: 'Tagline / short description', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: category, decoration: const InputDecoration(labelText: 'Category', helperText: 'e.g. Revenge Thriller, Romance', border: OutlineInputBorder())),
      const SizedBox(height: 16),
      if (message != null) Text(message!, style: const TextStyle(color: Colors.redAccent)),
      FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'Saving...' : 'Save show')),
    ]),
  );
}

class ManageEpisodesScreen extends StatelessWidget {
  final String showId;
  final String showTitle;
  const ManageEpisodesScreen({super.key, required this.showId, required this.showTitle});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(showTitle, maxLines: 1, overflow: TextOverflow.ellipsis)),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => AddEpisodeScreen(showId: showId))),
      icon: const Icon(Icons.upload_file), label: const Text('Upload episode')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('shows').doc(showId)
        .collection('episodes').orderBy('episodeNumber').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('Episodes load nahi hue.'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (snap.data!.docs.isEmpty) return const Center(child: Text('Abhi episodes nahi. Upload episode dabayein.'));
        return ListView(children: snap.data!.docs.map((d) => ListTile(
          leading: const Icon(Icons.video_library_outlined),
          title: Text('${d.data()['episodeNumber'] ?? ''}. ${d.data()['title'] ?? ''}'),
          subtitle: Text((d.data()['duration'] ?? '').toString()),
          trailing: IconButton(icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final data = d.data();
              final path = data['storagePath']?.toString();
              if (path != null && path.isNotEmpty) {
                try { await FirebaseStorage.instance.ref(path).delete(); } catch (_) {}
              }
              await d.reference.delete();
            }),
        )).toList());
      },
    ),
  );
}

class AddEpisodeScreen extends StatefulWidget {
  final String showId;
  const AddEpisodeScreen({super.key, required this.showId});
  @override
  State<AddEpisodeScreen> createState() => _AddEpisodeScreenState();
}

class _AddEpisodeScreenState extends State<AddEpisodeScreen> {
  final title = TextEditingController();
  final number = TextEditingController(text: '1');
  final duration = TextEditingController(text: '5 min');
  final description = TextEditingController();
  PlatformFile? picked;
  bool uploading = false;
  double progress = 0;
  String? message;

  Future<void> chooseVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video, allowMultiple: false, withData: false);
    if (result == null || result.files.isEmpty) return;
    setState(() { picked = result.files.single; message = null; });
  }

  Future<void> upload() async {
    if (title.text.trim().isEmpty || picked == null || picked!.path == null) {
      setState(() => message = 'Episode title aur video file select karein.');
      return;
    }
    final n = int.tryParse(number.text.trim());
    if (n == null || n < 1) { setState(() => message = 'Episode number 1 ya usse bada hona chahiye.'); return; }

    setState(() { uploading = true; progress = 0; message = null; });
    try {
      final file = File(picked!.path!);
      final safeName = picked!.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path = 'videos/${widget.showId}/ep_${n}_${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final ref = FirebaseStorage.instance.ref(path);
      final task = ref.putFile(file, SettableMetadata(contentType: _contentType(safeName)));
      task.snapshotEvents.listen((event) {
        if (!mounted || event.totalBytes == 0) return;
        setState(() => progress = event.bytesTransferred / event.totalBytes);
      });
      await task;
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('shows').doc(widget.showId)
        .collection('episodes').add({
          'title': title.text.trim(),
          'episodeNumber': n,
          'duration': duration.text.trim(),
          'description': description.text.trim(),
          'videoUrl': url,
          'storagePath': path,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': FirebaseAuth.instance.currentUser?.uid,
        });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => message = 'Upload fail hua. Firebase Storage billing, rules, internet aur app config check karein.');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  String _contentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.m3u8')) return 'application/vnd.apple.mpegurl';
    return 'video/mp4';
  }

  @override
  void dispose() {
    title.dispose(); number.dispose(); duration.dispose(); description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Upload episode')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Video aapke Android phone se Firebase Storage par upload hoga.',
        style: TextStyle(color: Colors.white70)),
      const SizedBox(height: 16),
      TextField(controller: title, decoration: const InputDecoration(labelText: 'Episode title', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: number, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Episode number', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: duration, decoration: const InputDecoration(labelText: 'Duration', hintText: '5 min', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: description, maxLines: 2,
        decoration: const InputDecoration(labelText: 'Short description (optional)', border: OutlineInputBorder())),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: uploading ? null : chooseVideo,
        icon: const Icon(Icons.video_file),
        label: Text(picked == null ? 'Phone se video select karein' : picked!.name),
      ),
      if (uploading) ...[
        const SizedBox(height: 16),
        LinearProgressIndicator(value: progress),
        const SizedBox(height: 6),
        Text('Uploading ${(progress * 100).toStringAsFixed(0)}%'),
      ],
      if (message != null) Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(message!, style: const TextStyle(color: Colors.redAccent))),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: uploading ? null : upload,
        icon: const Icon(Icons.cloud_upload),
        label: Text(uploading ? 'Upload ho raha hai...' : 'Upload aur publish karein'),
      ),
      const SizedBox(height: 12),
      const Text('Tip: Bade video files ko mobile data ke bajaye Wi-Fi par upload karein.',
        style: TextStyle(color: Colors.white54, fontSize: 12)),
    ]),
  );
}
