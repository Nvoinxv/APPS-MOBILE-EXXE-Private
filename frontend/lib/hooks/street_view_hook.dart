import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/auth_storage.dart';

class Street_View_Hook {
  // Base URL diatur terpusat di auth_storage.dart (kBaseUrl / TestingUrlExternal) //
  // Gak perlu define ulang di sini //

  // ===============================
  // GET ALL STREET VIEW EXCLUSIVE //
  // ===============================
  // token parameter dihapus — AuthStorage.get() inject token otomatis dari session
  static Future<Map<String, dynamic>> GetAllStreetView() async {
    try {
      final response = await AuthStorage.get(
        '/get-news-exclusive',
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      }
      return {
        "success": false,
        "message": response.body,
      };
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  // ====================================
  // GET STREET VIEW BY TITLE EXCLUSIVE //
  // ====================================
  // token parameter dihapus — AuthStorage.get() inject token otomatis dari session
  static Future<Map<String, dynamic>> GetStreetViewByTitle({
    required String title,
  }) async {
    try {
      // Pakai queryParams biar URL-safe (handle spasi & karakter spesial di title)
      final response = await AuthStorage.get(
        '/get-title-street-view-exclusive',
        headers: {'Accept': 'application/json'},
        queryParams: {'title': title},
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      }
      return {
        "success": false,
        "message": response.body,
      };
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  // ============================
  // UPLOAD STREET VIEW EXCLUSIVE //
  // ============================
  // token parameter dihapus — AuthStorage.sendMultipart() inject token otomatis
  static Future<Map<String, dynamic>> UploadStreetView({
    required String writerName,
    required String writerRole,
    required File sampulDepan,
    required String date,
    required File fileMain,
    required String judul,
    required String deskripsi1,
    required File image1,
    required String deskripsi2,
    required File image2,
    required String deskripsi3,
    required File image3,
    required String deskripsi4,
    required File image4,
    required String aiSummary,
    required String source,
    required String userEmail,
  }) async {
    try {
      // Buat MultipartRequest — AuthStorage.sendMultipart() akan inject
      // Authorization header otomatis sebelum send
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("$kBaseUrl/upload-street-view-exclusive"),
      );

      // FORM DATA TEXT //
      request.fields["writer_name"]  = writerName;
      request.fields["writer_role"]  = writerRole;
      request.fields["Date"]         = date;
      request.fields["Judul"]        = judul;
      request.fields["Deskripsi"]    = deskripsi1;
      request.fields["Deskripsi_2"]  = deskripsi2;
      request.fields["Deskripsi_3"]  = deskripsi3;
      request.fields["Deskripsi_4"]  = deskripsi4;
      request.fields["AI_Summary"]   = aiSummary;
      request.fields["Source"]       = source;
      request.fields["user_email"]   = userEmail;

      // FILE UPLOAD //
      request.files.add(
        await http.MultipartFile.fromPath("sampul_depan", sampulDepan.path),
      );
      request.files.add(
        await http.MultipartFile.fromPath("file", fileMain.path),
      );
      request.files.add(
        await http.MultipartFile.fromPath("Image_1", image1.path),
      );
      request.files.add(
        await http.MultipartFile.fromPath("Image_2", image2.path),
      );
      request.files.add(
        await http.MultipartFile.fromPath("Image_3", image3.path),
      );
      request.files.add(
        await http.MultipartFile.fromPath("image_4", image4.path),
      );

      // Kirim lewat AuthStorage — token di-inject otomatis di dalam sendMultipart()
      final streamedResponse = await AuthStorage.sendMultipart(request);
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(responseBody),
        };
      }
      return {
        "success": false,
        "message": responseBody,
      };
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  // ==============================
  // DELETE STREET VIEW EXCLUSIVE //
  // ==============================
  // token parameter dihapus — AuthStorage.delete() inject token otomatis
  static Future<Map<String, dynamic>> DeleteStreetView({
    required String mongoId,
  }) async {
    try {
      final response = await AuthStorage.delete(
        '/delete-street-view-exclusive',
        queryParams: {'street_view_id': mongoId},
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      }
      return {
        "success": false,
        "message": response.body,
      };
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  // Helper untuk handle response (tetap dipertahankan) //
  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 200) {
      return {"success": true, "data": jsonDecode(response.body)};
    }
    return {"success": false, "message": response.body};
  }

  // ============================================
  // GET STREET VIEW + UPLOADER INFO (SQL + MONGO) //
  // ============================================
  // Endpoint ini tidak butuh token (public) — tetap pakai AuthStorage.get()
  // biar konsisten, token akan di-inject kalau ada, skip kalau tidak ada
  static Future<Map<String, dynamic>> GetStreetViewWithUploader() async {
    try {
      final response = await AuthStorage.get(
        '/get-street-view-with-uploaders-exclusive',
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      }
      return {
        "success": false,
        "message": response.body,
      };
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }
}