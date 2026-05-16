import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../hooks/quant_investing_hook.dart';

class UploadQuantScreen extends StatefulWidget {
  final String token;
  
  const UploadQuantScreen({
    Key? key,
    required this.token,
  }) : super(key: key);

  @override
  State<UploadQuantScreen> createState() => _UploadQuantScreenState();
}

class _UploadQuantScreenState extends State<UploadQuantScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers - Basic Info
  final TextEditingController _judulPairController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _linkTradingViewController = TextEditingController();
  
  // Controllers - Section 1
  final TextEditingController _judul1Controller = TextEditingController();
  final TextEditingController _deskripsi1Controller = TextEditingController();
  
  // Controllers - Section 2
  final TextEditingController _judul2Controller = TextEditingController();
  final TextEditingController _deskripsi2Controller = TextEditingController();
  
  // Controllers - Section 3
  final TextEditingController _judul3Controller = TextEditingController();
  final TextEditingController _deskripsi3Controller = TextEditingController();
  
  // Controllers - Section 4
  final TextEditingController _judul4Controller = TextEditingController();
  final TextEditingController _deskripsi4Controller = TextEditingController();
  
  // ✅ ADDED: Missing fields from hook
  final TextEditingController _aiSummaryController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  
  // Images
  File? _imageSampul;
  File? _imageChart;
  
  // Loading state
  bool _isLoading = false;
  
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _judulPairController.dispose();
    _nameController.dispose();
    _linkTradingViewController.dispose();
    _judul1Controller.dispose();
    _deskripsi1Controller.dispose();
    _judul2Controller.dispose();
    _deskripsi2Controller.dispose();
    _judul3Controller.dispose();
    _deskripsi3Controller.dispose();
    _judul4Controller.dispose();
    _deskripsi4Controller.dispose();
    _aiSummaryController.dispose(); // ✅ ADDED
    _sourceController.dispose(); // ✅ ADDED
    super.dispose();
  }

  // Pick Image
  Future<void> _pickImage(String imageType) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          if (imageType == 'sampul') {
            _imageSampul = File(image.path);
          } else if (imageType == 'chart') {
            _imageChart = File(image.path);
          }
        });
      }
    } catch (e) {
      _showErrorDialog('Error picking image: $e');
    }
  }

  // Submit
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_imageSampul == null || _imageChart == null) {
      _showErrorDialog('Please select both Cover Image and Chart Image');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ Call API with ALL required fields
      final result = await Quant_Exclusive_Hook.UploadQuantExclusiveData(
        judulPair: _judulPairController.text.trim(),
        name: _nameController.text.trim(),
        linkTradingView: _linkTradingViewController.text.trim(),
        imageSampulPath: _imageSampul!.path,
        imageChartPath: _imageChart!.path,
        judul1: _judul1Controller.text.trim(),
        deskripsi1: _deskripsi1Controller.text.trim(),
        judul2: _judul2Controller.text.trim(),
        deskripsi2: _deskripsi2Controller.text.trim(),
        judul3: _judul3Controller.text.trim(),
        deskripsi3: _deskripsi3Controller.text.trim(),
        judul4: _judul4Controller.text.trim(),
        deskripsi4: _deskripsi4Controller.text.trim(),
        AI_Summary: _aiSummaryController.text.trim(), // ✅ ADDED
        Source: _sourceController.text.trim(), // ✅ ADDED
      );

      if (result['success'] == true) {
        _showSuccessDialog('Quant uploaded successfully!');
        _clearForm();
      } else {
        _showErrorDialog('Failed to upload: ${result['message'] ?? result['error']}');
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
    _judulPairController.clear();
    _nameController.clear();
    _linkTradingViewController.clear();
    _judul1Controller.clear();
    _deskripsi1Controller.clear();
    _judul2Controller.clear();
    _deskripsi2Controller.clear();
    _judul3Controller.clear();
    _deskripsi3Controller.clear();
    _judul4Controller.clear();
    _deskripsi4Controller.clear();
    _aiSummaryController.clear(); // ✅ ADDED
    _sourceController.clear(); // ✅ ADDED
    setState(() {
      _imageSampul = null;
      _imageChart = null;
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
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
              style: TextStyle(color: Color(0xFFBEFF00)),
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
        backgroundColor: const Color(0xFF2C2C2C),
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
              style: TextStyle(color: Color(0xFFBEFF00)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2C2C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Add Quant Outlook',
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
                color: Color(0xFFBEFF00),
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
                    
                    // Judul Pair
                    _buildLabel('Trading Pair Title'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _judulPairController,
                      hint: 'e.g. BTC/USDT Market Analysis',
                    ),
                    const SizedBox(height: 20),

                    // Analyst Name
                    _buildLabel('Analyst Name'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'e.g. John Doe, Trading Analyst',
                    ),
                    const SizedBox(height: 20),

                    // TradingView Link
                    _buildLabel('TradingView Link'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _linkTradingViewController,
                      hint: 'https://www.tradingview.com/chart/...',
                    ),
                    const SizedBox(height: 20),

                    // ✅ ADDED: AI Summary Field
                    _buildLabel('AI Summary'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _aiSummaryController,
                      hint: 'Enter AI-generated summary of the analysis...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // ✅ ADDED: Source Field
                    _buildLabel('Source'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _sourceController,
                      hint: 'e.g. TradingView, Bloomberg, Internal Analysis',
                    ),
                    const SizedBox(height: 20),

                    // Images Section
                    _buildSectionHeader('Images'),
                    const SizedBox(height: 16),

                    // Cover Image
                    _buildLabel('Cover Image *'),
                    const SizedBox(height: 8),
                    _buildImagePicker('sampul', _imageSampul),
                    const SizedBox(height: 20),

                    // Chart Image
                    _buildLabel('Chart Image *'),
                    const SizedBox(height: 8),
                    _buildImagePicker('chart', _imageChart),
                    const SizedBox(height: 20),

                    // Content Sections
                    _buildSectionHeader('Content Sections'),
                    const SizedBox(height: 16),

                    // Section 1
                    _buildContentSection(
                      sectionNumber: 1,
                      judulController: _judul1Controller,
                      deskripsiController: _deskripsi1Controller,
                    ),
                    const SizedBox(height: 20),

                    // Section 2
                    _buildContentSection(
                      sectionNumber: 2,
                      judulController: _judul2Controller,
                      deskripsiController: _deskripsi2Controller,
                    ),
                    const SizedBox(height: 20),

                    // Section 3
                    _buildContentSection(
                      sectionNumber: 3,
                      judulController: _judul3Controller,
                      deskripsiController: _deskripsi3Controller,
                    ),
                    const SizedBox(height: 20),

                    // Section 4
                    _buildContentSection(
                      sectionNumber: 4,
                      judulController: _judul4Controller,
                      deskripsiController: _deskripsi4Controller,
                    ),
                    const SizedBox(height: 20),

                    // Info Text
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFBEFF00).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: const Color(0xFFBEFF00),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'All fields and images are required. Make sure all 4 content sections, AI Summary, and Source are properly filled.',
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
                              backgroundColor: const Color(0xFFBEFF00),
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
                                color: Color(0xFF3C3C3C),
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
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: const Color(0xFFBEFF00),
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
        hintStyle: const TextStyle(color: Color(0xFF666666)),
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
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

  Widget _buildContentSection({
    required int sectionNumber,
    required TextEditingController judulController,
    required TextEditingController deskripsiController,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF3C3C3C),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFBEFF00),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Section $sectionNumber',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLabel('Title'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: judulController,
            hint: 'e.g. Quant Overview, Technical Analysis',
          ),
          const SizedBox(height: 16),
          _buildLabel('Description'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: deskripsiController,
            hint: 'Enter detailed description for this section...',
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker(String imageType, File? imageFile) {
    String label = imageType == 'sampul' ? 'Cover Image' : 'Chart Image';
    IconData icon = imageType == 'sampul' ? Icons.image_outlined : Icons.show_chart;
    
    return InkWell(
      onTap: () => _pickImage(imageType),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: imageFile != null 
                ? const Color(0xFFBEFF00).withOpacity(0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: imageFile != null 
                  ? const Color(0xFFBEFF00)
                  : const Color(0xFF666666),
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
                          : const Color(0xFF666666),
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (imageFile != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Selected',
                      style: TextStyle(
                        color: const Color(0xFFBEFF00),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (imageFile != null)
              Icon(
                Icons.check_circle,
                color: const Color(0xFFBEFF00),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}