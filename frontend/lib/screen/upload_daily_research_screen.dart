import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../hooks/login_hook.dart';
import 'package:frontend/hooks/daily_research_hook.dart';


class UploadDailyResearch extends StatefulWidget {
  final String token;
  
  const UploadDailyResearch({
    Key? key,
    required this.token,
  }) : super(key: key);

  @override
  State<UploadDailyResearch> createState() => _UploadDailyResearchState();
}

class _UploadDailyResearchState extends State<UploadDailyResearch> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _subJudulController = TextEditingController();
  final TextEditingController _isi1Controller = TextEditingController();
  final TextEditingController _isi2Controller = TextEditingController();
  final TextEditingController _isi3Controller = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  
  // Date
  DateTime? _selectedDate;
  
  // Images
  File? _image1;
  File? _image2;
  File? _image3;
  
  // Video
  File? _video;
  
  // Loading state
  bool _isLoading = false;
  
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _judulController.dispose();
    _subJudulController.dispose();
    _isi1Controller.dispose();
    _isi2Controller.dispose();
    _isi3Controller.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  // Pick Image
  Future<void> _pickImage(int imageNumber) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          switch (imageNumber) {
            case 1:
              _image1 = File(image.path);
              break;
            case 2:
              _image2 = File(image.path);
              break;
            case 3:
              _image3 = File(image.path);
              break;
          }
        });
      }
    } catch (e) {
      _showErrorDialog('Error picking image: $e');
    }
  }

  // Pick Video
  Future<void> _pickVideo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
      );
      
      if (result != null) {
        setState(() {
          _video = File(result.files.single.path!);
        });
      }
    } catch (e) {
      _showErrorDialog('Error picking video: $e');
    }
  }

  // Pick Date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF5FAD56), // greenPrimary
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A1A), // cardBackground
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Submit
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      _showErrorDialog('Please select a date');
      return;
    }

    if (_image1 == null) {
      _showErrorDialog('Please select at least Image 1');
      return;
    }

    if (_video == null) {
      _showErrorDialog('Please select a video');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Format date
      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      
      // Simulasi sukses (hapus ini saat production)
      await Future.delayed(const Duration(seconds: 2));
      _showSuccessDialog('Daily research uploaded successfully!');
      _clearForm();
      
    } catch (e) {
      _showErrorDialog('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearForm() {
    _judulController.clear();
    _subJudulController.clear();
    _isi1Controller.clear();
    _isi2Controller.clear();
    _isi3Controller.clear();
    _sourceController.clear();
    setState(() {
      _selectedDate = null;
      _image1 = null;
      _image2 = null;
      _image3 = null;
      _video = null;
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Error',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF5FAD56)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Success',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // Kembali ke screen sebelumnya
            },
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF5FAD56)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // backgroundColor
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A), // cardBackground
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Add Item',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF5FAD56), // greenPrimary
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information Section
                    _buildSectionHeader('Basic Information'),
                    const SizedBox(height: 16),
                    
                    // Judul
                    _buildLabel('Judul'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _judulController,
                      hint: 'Enter judul',
                    ),
                    const SizedBox(height: 20),

                    // Sub Judul
                    _buildLabel('Sub Judul'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _subJudulController,
                      hint: 'Enter sub judul',
                    ),
                    const SizedBox(height: 20),

                    // Date
                    _buildLabel('Date'),
                    const SizedBox(height: 8),
                    _buildDateField(),
                    const SizedBox(height: 20),

                    // Content Section
                    _buildSectionHeader('Content'),
                    const SizedBox(height: 16),

                    // ISI 1
                    _buildLabel('ISI 1'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _isi1Controller,
                      hint: 'Enter content 1',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // Image 1
                    _buildLabel('Image 1'),
                    const SizedBox(height: 8),
                    _buildImagePicker(1, _image1, 'Image 1'),
                    const SizedBox(height: 20),

                    // Isi 2
                    _buildLabel('Isi 2'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _isi2Controller,
                      hint: 'Enter content 2',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // Image 2
                    _buildLabel('Image 2'),
                    const SizedBox(height: 8),
                    _buildImagePicker(2, _image2, 'Image 2'),
                    const SizedBox(height: 20),

                    // Isi 3
                    _buildLabel('Isi 3'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _isi3Controller,
                      hint: 'Enter content 3',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // Image 3
                    _buildLabel('Image 3'),
                    const SizedBox(height: 8),
                    _buildImagePicker(3, _image3, 'Image 3'),
                    const SizedBox(height: 20),

                    // Source
                    _buildLabel('Source'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _sourceController,
                      hint: 'Enter source',
                    ),
                    const SizedBox(height: 20),

                    // Media Section
                    _buildSectionHeader('Media'),
                    const SizedBox(height: 16),

                    // Video
                    _buildLabel('Video'),
                    const SizedBox(height: 8),
                    _buildVideoPicker(),
                    const SizedBox(height: 30),

                    // Buttons
                    Row(
                      children: [
                        // Submit Button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5FAD56), // greenPrimary
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Submit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Cancel Button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: Color(0xFF2A2A2A), // cardBorder
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Color(0xFF5FAD56), // greenPrimary
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF888888)), // sourceText
        filled: true,
        fillColor: const Color(0xFF1A1A1A), // cardBackground
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'This field is required';
        }
        return null;
      },
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A), // cardBackground
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _selectedDate != null 
                ? const Color(0xFF5FAD56).withOpacity(0.3) // greenPrimary
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: _selectedDate != null
                  ? const Color(0xFF5FAD56) // greenPrimary
                  : const Color(0xFF888888), // sourceText
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedDate != null
                        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                        : 'Select date',
                    style: TextStyle(
                      color: _selectedDate != null
                          ? Colors.white
                          : const Color(0xFF888888), // sourceText
                      fontSize: 16,
                    ),
                  ),
                  if (_selectedDate != null) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Selected',
                      style: TextStyle(
                        color: Color(0xFF5FAD56), // greenPrimary
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_selectedDate != null)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF5FAD56), // greenPrimary
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(int imageNumber, File? imageFile, String label) {
    return InkWell(
      onTap: () => _pickImage(imageNumber),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A), // cardBackground
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: imageFile != null 
                ? const Color(0xFF5FAD56).withOpacity(0.3) // greenPrimary
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.image_outlined,
              color: imageFile != null
                  ? const Color(0xFF5FAD56) // greenPrimary
                  : const Color(0xFF888888), // sourceText
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    imageFile != null
                        ? imageFile.path.split('/').last
                        : 'Choose $label...',
                    style: TextStyle(
                      color: imageFile != null
                          ? Colors.white
                          : const Color(0xFF888888), // sourceText
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (imageFile != null) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Selected',
                      style: TextStyle(
                        color: Color(0xFF5FAD56), // greenPrimary
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (imageFile != null)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF5FAD56), // greenPrimary
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPicker() {
    return InkWell(
      onTap: _pickVideo,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A), // cardBackground
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _video != null 
                ? const Color(0xFF5FAD56).withOpacity(0.3) // greenPrimary
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.videocam_outlined,
              color: _video != null
                  ? const Color(0xFF5FAD56) // greenPrimary
                  : const Color(0xFF888888), // sourceText
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _video != null
                        ? _video!.path.split('/').last
                        : 'Choose a video...',
                    style: TextStyle(
                      color: _video != null
                          ? Colors.white
                          : const Color(0xFF888888), // sourceText
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_video != null) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Selected',
                      style: TextStyle(
                        color: Color(0xFF5FAD56), // greenPrimary
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_video != null)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF5FAD56), // greenPrimary
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}