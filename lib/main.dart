import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

/// ================= BASE URL API =================
String get baseUrl {
  return dotenv.env['BASE_API'] ?? 'http://videokuy.test/api/';
}

String get mediaBaseUrl {
  return baseUrl;
}

/// True jika server mengembalikan JSON info/router (bukan hasil CRUD sungguhan).
/// Deploy Railway Anda saat ini membalas ini untuk semua path termasuk upload/get.
bool isPlaceholderApiInfo(dynamic json) {
  return json is Map && json["endpoints"] is List;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Video App",
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const VideoGalleryPage(),
    );
  }
}

/// ================= HOME =================

class VideoGalleryPage extends StatefulWidget {
  const VideoGalleryPage({super.key});

  @override
  State<VideoGalleryPage> createState() => _VideoGalleryPageState();
}

class _VideoGalleryPageState extends State<VideoGalleryPage> {
  List videos = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetch();
  }

  Future fetch() async {
    setState(() => loading = true);

    try {
      final res = await http.get(Uri.parse("${baseUrl}get_data.php"));

      if (res.statusCode == 200) {
        final jsonData = json.decode(res.body);
        print("Response: $jsonData");

        setState(() {
          if (isPlaceholderApiInfo(jsonData)) {
            debugPrint(
              "get_data: server mengembalikan stub (bukan daftar video). "
              "Pastikan file PHP CRUD ter-deploy di Railway.",
            );
            videos = [];
          } else if (jsonData["success"] == true && jsonData["data"] != null) {
            videos = jsonData["data"];
          } else {
            videos = [];
          }
        });
      }
    } catch (e) {
      debugPrint("GET ERROR: $e");
    }

    setState(() => loading = false);
  }

  String imageUrl(String fileName) {
    if (fileName.isEmpty) return "";

    // Jika sudah berupa URL lengkap (Cloudinary), gunakan langsung
    if (fileName.startsWith("http://") || fileName.startsWith("https://")) {
      return fileName;
    }

    // Karena file thumbnail disimpan di folder "../thumbnail/"
    // dan API di Railway, kita gunakan path langsung
    return "${mediaBaseUrl}thumbnail/$fileName";
  }

  String videoUrl(String fileName) {
    if (fileName.isEmpty) return "";

    // Jika sudah berupa URL lengkap (Cloudinary), gunakan langsung
    if (fileName.startsWith("http://") || fileName.startsWith("https://")) {
      return fileName;
    }

    // Karena file video disimpan di folder "../video/"
    return "${mediaBaseUrl}video/$fileName";
  }

  Future<void> showVideoActionPopup(Map video) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pilih Aksi"),
        content: Text(
          "Video: ${video["title"]}",
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, "edit"),
            child: const Text("Edit"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, "delete"),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Hapus"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
        ],
      ),
    );

    if (!mounted || selected == null) return;

    if (selected == "edit") {
      final res = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditPage(video: video)),
      );
      if (res == true) fetch();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Hapus"),
        content: const Text('Yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await deleteVideo(video["id"].toString());
    }
  }

  Future<void> deleteVideo(String id) async {
    try {
      final res = await http.post(
        Uri.parse("${baseUrl}delete_data.php"),
        body: {"id": id},
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final response = json.decode(res.body);
        if (isPlaceholderApiInfo(response)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Server hanya membalas info API (stub), bukan delete_data.php sungguhan.",
              ),
              backgroundColor: Colors.red,
            ),
          );
        } else if (response["success"] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Data berhasil dihapus"),
              backgroundColor: Colors.green,
            ),
          );
          fetch();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response["message"] ?? "Gagal menghapus"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal menghapus data: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f2f5),
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: const Text(
          "🎬 Galeri Video",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: fetch,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 16),
                  Text("Memuat video..."),
                ],
              ),
            )
          : videos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Belum ada video",
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tekan tombol + untuk menambahkan video",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: videos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemBuilder: (context, i) {
                final v = videos[i];
                final thumbUrl = imageUrl(v["thumbnail"]);
                final videoUrlPath = videoUrl(v["video"]);

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerPage(
                          url: videoUrlPath,
                          title: v["title"],
                        ),
                      ),
                    );
                  },
                  onLongPress: () => showVideoActionPopup(v),
                  child: Hero(
                    tag: v["video"],
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 10,
                            color: Colors.black.withOpacity(0.1),
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Image.network(
                                      thumbUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                color: Colors.grey.shade300,
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.broken_image,
                                                    size: 40,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.4),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        size: 40,
                                        color: Colors.indigo,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.videocam,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            "Video",
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    v["title"],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Tap to play",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UploadPage()),
          );

          if (res == true) {
            fetch();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text("Tambah Video"),
        elevation: 2,
      ),
    );
  }
}

/// ================= UPLOAD =================

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final title = TextEditingController();

  PlatformFile? thumb;
  PlatformFile? video;

  bool loading = false;

  Future pickThumb() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null) {
      setState(() {
        thumb = result.files.first;
      });
    }
  }

  Future pickVideo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      withData: true,
    );

    if (result != null) {
      setState(() {
        video = result.files.first;
      });
    }
  }

  Future upload() async {
    if (title.text.isEmpty || thumb == null || video == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lengkapi semua data"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      var req = http.MultipartRequest(
        "POST",
        Uri.parse("${baseUrl}add_data.php"),
      );

      req.fields["title"] = title.text;

      req.files.add(
        http.MultipartFile.fromBytes(
          "thumbnail",
          thumb!.bytes!,
          filename: thumb!.name,
        ),
      );

      req.files.add(
        http.MultipartFile.fromBytes(
          "video",
          video!.bytes!,
          filename: video!.name,
        ),
      );

      var res = await req.send();
      var responseData = await res.stream.bytesToString();
      // Cek jika responseData bukan JSON (misal error HTML)
      if (responseData.trim().startsWith('<')) {
        debugPrint("UPLOAD ERROR: Server mengembalikan HTML, bukan JSON.\n$responseData");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload gagal: Server error atau endpoint salah. Cek koneksi dan API upload_data.php."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => loading = false);
        return;
      }
      var responseJson = json.decode(responseData);

      if (!mounted) return;

      print("Upload response: $responseJson"); // Debug

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (isPlaceholderApiInfo(responseJson)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Server belum menjalankan upload_data.php (hanya balasan \"API aktif\"). "
                "Data tidak tersimpan di database.",
              ),
              backgroundColor: Colors.red,
            ),
          );
        } else if (responseJson["success"] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Upload berhasil"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseJson["message"] ?? "Upload gagal"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload gagal (${res.statusCode})"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("UPLOAD ERROR: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Upload gagal: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Video"), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.indigo.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Pastikan file yang diupload sesuai format yang didukung",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: title,
              decoration: InputDecoration(
                labelText: "Judul Video",
                hintText: "Masukkan judul video",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Thumbnail",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.image,
                  color: thumb != null ? Colors.green : Colors.grey,
                ),
                title: Text(
                  thumb?.name ?? "Pilih Thumbnail",
                  style: TextStyle(
                    fontSize: 14,
                    color: thumb != null ? Colors.black87 : Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: ElevatedButton.icon(
                  onPressed: pickThumb,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text("Pilih"),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "File Video",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.video_file,
                  color: video != null ? Colors.green : Colors.grey,
                ),
                title: Text(
                  video?.name ?? "Pilih Video",
                  style: TextStyle(
                    fontSize: 14,
                    color: video != null ? Colors.black87 : Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: ElevatedButton.icon(
                  onPressed: pickVideo,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text("Pilih"),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : upload,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        "UPLOAD VIDEO",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// ================= EDIT =================

class EditPage extends StatefulWidget {
  final Map video;

  const EditPage({super.key, required this.video});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late final TextEditingController title;
  PlatformFile? thumb;
  PlatformFile? video;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(
      text: (widget.video["title"] ?? "").toString(),
    );
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future pickThumb() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null) {
      setState(() {
        thumb = result.files.first;
      });
    }
  }

  Future pickVideo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      withData: true,
    );

    if (result != null) {
      setState(() {
        video = result.files.first;
      });
    }
  }

  Future update() async {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Judul video wajib diisi"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final req = http.MultipartRequest(
        "POST",
        Uri.parse("${baseUrl}update_data.php"),
      );

      req.fields["id"] = widget.video["id"].toString();
      req.fields["title"] = title.text.trim();

      if (thumb != null) {
        req.files.add(
          http.MultipartFile.fromBytes(
            "thumbnail",
            thumb!.bytes!,
            filename: thumb!.name,
          ),
        );
      }

      if (video != null) {
        req.files.add(
          http.MultipartFile.fromBytes(
            "video",
            video!.bytes!,
            filename: video!.name,
          ),
        );
      }

      final res = await req.send();
      var responseData = await res.stream.bytesToString();
      var responseJson = json.decode(responseData);

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (isPlaceholderApiInfo(responseJson)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Server belum menjalankan update_data.php sungguhan — tidak ada perubahan di DB.",
              ),
              backgroundColor: Colors.red,
            ),
          );
        } else if (responseJson["success"] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Data berhasil diupdate"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseJson["message"] ?? "Gagal update"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal update data: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Video"), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: title,
              decoration: InputDecoration(
                labelText: "Judul Video",
                hintText: "Masukkan judul video",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.image,
                  color: thumb != null ? Colors.green : Colors.grey,
                ),
                title: Text(
                  thumb?.name ?? "Ganti Thumbnail (opsional)",
                  style: TextStyle(
                    fontSize: 14,
                    color: thumb != null ? Colors.black87 : Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: ElevatedButton.icon(
                  onPressed: pickThumb,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text("Pilih"),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.video_file,
                  color: video != null ? Colors.green : Colors.grey,
                ),
                title: Text(
                  video?.name ?? "Ganti Video (opsional)",
                  style: TextStyle(
                    fontSize: 14,
                    color: video != null ? Colors.black87 : Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: ElevatedButton.icon(
                  onPressed: pickVideo,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text("Pilih"),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : update,
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        "SIMPAN PERUBAHAN",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ================= PLAYER =================

class PlayerPage extends StatefulWidget {
  final String url;
  final String title;

  const PlayerPage({super.key, required this.url, required this.title});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late VideoPlayerController controller;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() {
          isInitialized = true;
        });
        controller.play();
      }).catchError((error) {
        print("Error initializing video: $error");
        setState(() {
          isInitialized = true;
        });
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Center(
            child: isInitialized
                ? controller.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 50, color: Colors.red),
                          SizedBox(height: 16),
                          Text(
                            "Gagal memuat video",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,  
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        "Memuat video...",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
          ),
          if (controller.value.isInitialized)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    controller.value.isPlaying
                        ? controller.pause()
                        : controller.play();
                  });
                },
                child: Icon(
                  controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 30,
                ),
              ),
            ),
        ],
      ),
    );
  }
}