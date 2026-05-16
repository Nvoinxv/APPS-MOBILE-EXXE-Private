import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../hooks/news_hook.dart';

class UploadNewsScreen extends StatefulWidget {
  final String token;

  const UploadNewsScreen({
    super.key,
    required this.token,
  });

  @override
  State<UploadNewsScreen> createState() => _UploadNewsScreenState();
}

class _UploadNewsScreenState extends State<UploadNewsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _imagesLinkController = TextEditingController();
  
  // Date
  DateTime? _selectedDate;
  
  // Images
  File? _image1;
  File? _image2;
  
  // Loading state
  bool _isLoading = false;
  
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _sourceController.dispose();
    _imagesLinkController.dispose();
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
          }
        });
      }
    } catch (e) {
      _showErrorDialog('Error picking image: $e');
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
      _showErrorDialog('Please select a news date');
      return;
    }

    if (_image1 == null || _image2 == null) {
      _showErrorDialog('Please select both Image 1 and Image 2');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Format date to yyyy-MM-dd
      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      
      // Call API
      final result = await News_Exclusive_Hook.UploadNewsExclusive(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        source: _sourceController.text.trim(),
        imagesLink: _imagesLinkController.text.trim(),
        newsDate: formattedDate,
        imagePath1: _image1!.path,
        imagePath2: _image2!.path,
      );

      if (result['success'] == true) {
        _showSuccessDialog('News uploaded successfully!');
        _clearForm();
      } else {
        _showErrorDialog('Failed to upload news: ${result['message'] ?? result['error']}');
      }
      
    } catch (e) {
      _showErrorDialog('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _sourceController.clear();
    _imagesLinkController.clear();
    setState(() {
      _selectedDate = null;
      _image1 = null;
      _image2 = null;
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
              Navigator.of(context).pop(); // Kembali ke home screen
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
          'Add News',
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
                    
                    // Title
                    _buildLabel('Title'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _titleController,
                      hint: 'Enter news title',
                    ),
                    const SizedBox(height: 20),

                    // Description
                    _buildLabel('Description'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _descriptionController,
                      hint: 'Enter news description',
                      maxLines: 4,
                    ),
                    const SizedBox(height: 20),

                    // Source
                    _buildLabel('Source'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _sourceController,
                      hint: 'e.g. Bloomberg, Reuters, CNN',
                    ),
                    const SizedBox(height: 20),

                    // Images Link (Optional)
                    _buildLabel('Images Link (Optional)'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _imagesLinkController,
                      hint: 'https://example.com/image.jpg',
                      isRequired: false,
                    ),
                    const SizedBox(height: 20),

                    // News Date
                    _buildLabel('News Date'),
                    const SizedBox(height: 8),
                    _buildDateField(),
                    const SizedBox(height: 20),

                    // Images Section
                    _buildSectionHeader('Images'),
                    const SizedBox(height: 16),

                    // Image 1
                    _buildLabel('Image 1 *'),
                    const SizedBox(height: 8),
                    _buildImagePicker(1, _image1, 'Image 1'),
                    const SizedBox(height: 20),

                    // Image 2
                    _buildLabel('Image 2 *'),
                    const SizedBox(height: 8),
                    _buildImagePicker(2, _image2, 'Image 2'),
                    const SizedBox(height: 20),

                    // Info Text
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A), // cardBackground
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF5FAD56).withOpacity(0.3), // greenPrimary
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFF5FAD56), // greenPrimary
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Both images are required for news upload',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
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
    bool isRequired = true,
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
      validator: isRequired
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'This field is required';
              }
              return null;
            }
          : null,
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
                        : 'Select news date',
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
}