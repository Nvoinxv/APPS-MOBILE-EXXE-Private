import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../style/apps_colors_trade_ideas.dart';
import '../hooks/trade_ideas_hook.dart';

class Upload_trade_ideas extends StatefulWidget {
  final String token;
  
  const Upload_trade_ideas({
    Key? key,
    required this.token,
  }) : super(key: key);

  @override
  State<Upload_trade_ideas> createState() => _Upload_trade_ideas_state();
}

class _Upload_trade_ideas_state extends State<Upload_trade_ideas> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _Trade_ideas_Controller = TextEditingController();
  final TextEditingController _Tipe_trade_Controller = TextEditingController();
  final TextEditingController _EntryController = TextEditingController();
  final TextEditingController _StopLossController = TextEditingController();
  final TextEditingController _TargetController = TextEditingController();
  final TextEditingController _StatusController = TextEditingController();
  
  // Date
  DateTime? _selectedDate;
  
  // Loading state
  bool _isLoading = false;
  
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _Trade_ideas_Controller.dispose();
    _Tipe_trade_Controller.dispose();
    _EntryController.dispose();
    _StopLossController.dispose();
    _TargetController.dispose();
    _StatusController.dispose();
    super.dispose();
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
            colorScheme: ColorScheme.dark(
              primary: TradeIdeasColorStyle.greenNeon,
              onPrimary: Colors.black,
              surface: TradeIdeasColorStyle.cardBackground,
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

    setState(() {
      _isLoading = true;
    });

    try {
      // Format date
      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      
      // TODO: Call API here
      // Simulasi sukses (hapus ini saat production)
      await Future.delayed(const Duration(seconds: 2));
      _showSuccessDialog('Trade ideas uploaded successfully!');
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
    _Trade_ideas_Controller.clear();
    _Tipe_trade_Controller.clear();
    _EntryController.clear();
    _StopLossController.clear();
    _TargetController.clear();
    _StatusController.clear();
    setState(() {
      _selectedDate = null;
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TradeIdeasColorStyle.cardBackground,
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
            child: Text(
              'OK',
              style: TextStyle(color: TradeIdeasColorStyle.greenNeon),
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
        backgroundColor: TradeIdeasColorStyle.cardBackground,
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
            child: Text(
              'OK',
              style: TextStyle(color: TradeIdeasColorStyle.greenNeon),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TradeIdeasColorStyle.backgroundColor,
      appBar: AppBar(
        backgroundColor: TradeIdeasColorStyle.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Add Trade Ideas',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: TradeIdeasColorStyle.greenNeon,
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
                    _buildSectionHeader('Trade Information'),
                    const SizedBox(height: 16),
                    
                    // Trade Ideas
                    _buildLabel('Trade Ideas'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _Trade_ideas_Controller,
                      hint: 'e.g. BTC/USDT Long Position',
                    ),
                    const SizedBox(height: 20),

                    // Tipe Trade
                    _buildLabel('Trade Type'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _Tipe_trade_Controller,
                      hint: 'e.g. Swing Trade, Day Trade',
                    ),
                    const SizedBox(height: 20),

                    // Date
                    _buildLabel('Date'),
                    const SizedBox(height: 8),
                    _buildDateField(),
                    const SizedBox(height: 20),

                    // Entry Details Section
                    _buildSectionHeader('Entry Details'),
                    const SizedBox(height: 16),

                    // Entry
                    _buildLabel('Entry Price/Zone'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _EntryController,
                      hint: 'Enter entry price or zone details...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // StopLoss
                    _buildLabel('Stop Loss'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _StopLossController,
                      hint: 'Enter stop loss price or strategy...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // Target
                    _buildLabel('Target Price/Zone'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _TargetController,
                      hint: 'Enter target price or zone details...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // Status
                    _buildLabel('Status'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _StatusController,
                      hint: 'e.g. Active, Pending, Closed',
                    ),
                    const SizedBox(height: 20),

                    // Info Text
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TradeIdeasColorStyle.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: TradeIdeasColorStyle.greenNeon.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: TradeIdeasColorStyle.greenNeon,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'All fields are required. Make sure to provide complete trade information including entry, stop loss, and target details.',
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
                              backgroundColor: TradeIdeasColorStyle.greenNeon,
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
                              side: BorderSide(
                                color: TradeIdeasColorStyle.searchBorder,
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
            color: TradeIdeasColorStyle.greenNeon,
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
        hintStyle: TextStyle(color: TradeIdeasColorStyle.searchPlaceholder),
        filled: true,
        fillColor: TradeIdeasColorStyle.cardBackground,
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
          color: TradeIdeasColorStyle.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _selectedDate != null 
                ? TradeIdeasColorStyle.greenNeon.withOpacity(0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: _selectedDate != null 
                  ? TradeIdeasColorStyle.greenNeon
                  : TradeIdeasColorStyle.searchPlaceholder,
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
                        : 'Select date...',
                    style: TextStyle(
                      color: _selectedDate != null
                          ? Colors.white
                          : TradeIdeasColorStyle.searchPlaceholder,
                      fontSize: 16,
                    ),
                  ),
                  if (_selectedDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Selected',
                      style: TextStyle(
                        color: TradeIdeasColorStyle.greenNeon,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_selectedDate != null)
              Icon(
                Icons.check_circle,
                color: TradeIdeasColorStyle.greenNeon,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}