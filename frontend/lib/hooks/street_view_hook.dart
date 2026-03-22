import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class Street_View_Hook {
    // Ini gw pakai local host dulu //
    // Belum production mode //
    static const String baseUrl = "http://127.0.0.1:8080";

    // ===============================
    // GET ALL STREET VIEW EXCLUSIVE //
    // ===============================
    static Future<Map<String, dynamic>> GetAllStreetView({
        required String token, // ✅ TAMBAH PARAMETER TOKEN
    }) async {
        try {
            final response = await http.get(
                Uri.parse("$baseUrl/get-news-exclusive"),
                headers: {
                    "Authorization": "Bearer $token", // ✅ KIRIM TOKEN
                    "Accept": "application/json",
                },
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

    // ==================================
    // GET STREET VIEW BY TITLE EXCLUSIVE //
    // ==================================
    static Future<Map<String, dynamic>> GetStreetViewByTitle({
        required String token,
        required String title,
    }) async {
        try {
            final response = await http.get(
                Uri.parse(
                    "$baseUrl/get-title-street-view-exclusive?title=$title",
                ),
                headers: {
                    "Authorization": "Bearer $token", // ✅ KIRIM TOKEN
                    "Accept": "application/json",
                },
            );

            if (response.statusCode == 200) {
                return {
                    "success": true,
                    "data": jsonDecode(response.body),
                };
            } else {
                return {
                    "success": false,
                    "message": response.body,
                };
            }
        } catch (e) {
            return {
                "success": false,
                "error": e.toString(),
            };
        }
    }

    // UPLOAD STREET VIEW EXCLUSIVE //
    static Future<Map<String, dynamic>> UploadStreetView({
        required String token,
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
            final request = http.MultipartRequest(
                "POST",
                Uri.parse("$baseUrl/upload-street-view-exclusive"),
            );

            // ===============================
            // ADD JWT HEADER
            // ===============================
            request.headers.addAll({
                "Authorization": "Bearer $token",
                "Accept": "application/json",
            });

            // FORM DATA TEXT //
            request.fields["writer_name"] = writerName;
            request.fields["writer_role"] = writerRole;
            request.fields["Date"] = date;
            request.fields["Judul"] = judul;
            request.fields["Deskripsi"] = deskripsi1;
            request.fields["Deskripsi_2"] = deskripsi2;
            request.fields["Deskripsi_3"] = deskripsi3;
            request.fields["Deskripsi_4"] = deskripsi4;
            request.fields["AI_Summary"] = aiSummary;
            request.fields["Source"] = source;
            request.fields["user_email"] = userEmail;

            // FILE UPLOAD //
            request.files.add(
                await http.MultipartFile.fromPath(
                    "sampul_depan",
                    sampulDepan.path,
                ),
            );

            request.files.add(
                await http.MultipartFile.fromPath(
                    "file",
                    fileMain.path,
                ),
            );

            request.files.add(
                await http.MultipartFile.fromPath(
                    "Image_1",
                    image1.path,
                ),
            );

            request.files.add(
                await http.MultipartFile.fromPath(
                    "Image_2",
                    image2.path,
                ),
            );

            request.files.add(
                await http.MultipartFile.fromPath(
                    "Image_3",
                    image3.path,
                ),
            );

            request.files.add(
                await http.MultipartFile.fromPath(
                    "image_4",
                    image4.path,
                ),
            );

            final streamedResponse = await request.send();
            final responseBody =
                await streamedResponse.stream.bytesToString();

            if (streamedResponse.statusCode == 200) {
                return {
                    "success": true,
                    "data": jsonDecode(responseBody),
                };
            } else {
                return {
                    "success": false,
                    "message": responseBody,
                };
            }
        } catch (e) {
            return {
                "success": false,
                "error": e.toString(),
            };
        }
    }
    // DELETE STREET VIEW EXCLUSIVE //
    // DELETE STREET VIEW EXCLUSIVE //
    static Future<Map<String, dynamic>> DeleteStreetView({
        required String token,
        required String mongoId,
    }) async {
        try {
            final response = await http.delete(
                Uri.parse(
                    "$baseUrl/delete-street-view-exclusive?street_view_id=$mongoId",
                ), 
                // PERBAIKAN DI SINI: Ganti ( ) menjadi { }
                headers: {
                    "Authorization": "Bearer $token",
                },
            );

            if (response.statusCode == 200) {
                return {
                    "success": true,
                    "data": jsonDecode(response.body),
                };
            } else {
                return {
                    "success": false,
                    "message": response.body,
                };
            }
        } catch (e) {
            return {
                "success": false,
                "error": e.toString(),
            };
        }
    }

    // Helper untuk handle response
    static Map<String, dynamic> _handleResponse(http.Response response) {
        if (response.statusCode == 200) {
            return {"success": true, "data": jsonDecode(response.body)};
        }
        return {"success": false, "message": response.body};
    }


    // GET STREET VIEW + UPLOADER INFO (SQL + MONGO) //
    static Future<Map<String, dynamic>> GetStreetViewWithUploader() async {
        try {
            final response = await http.get(
                Uri.parse(
                    "$baseUrl/get-street-view-with-uploaders-exclusive",
                ),
            );

            if (response.statusCode == 200) {
                return {
                    "success": true,
                    "data": jsonDecode(response.body),
                };
            } else {
                return {
                    "success": false,
                    "message": response.body,
                };
            }
        } catch (e) {
            return {
                "success": false,
                "error": e.toString(),
            };
        }
    }
}
