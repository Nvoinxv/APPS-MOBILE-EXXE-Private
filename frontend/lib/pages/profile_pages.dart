import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../hooks/otp_hook.dart';
import '../hooks/update_profile_hook.dart';

class ProfilePage extends StatefulWidget {
  final String token;
  final String username;
  final String email;
  final String role;

  const ProfilePage({
    super.key,
    required this.token,
    required this.username,
    required this.email,
    required this.role,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _formKey            = GlobalKey<FormState>();
  final _nameController     = TextEditingController();
  final _descController     = TextEditingController();
  final _birthYearController = TextEditingController();

  File?   _profileImageFile;
  String? _profileImageUrl;

  bool _isLoadingProfile  = true;
  bool _isUploadingImage  = false;
  bool _isEditing         = false;
  bool _isSaving          = false;

  static const _bg          = Color(0xFF0A0A0A);
  static const _surface     = Color(0xFF0F1A0F);
  static const _card        = Color(0xFF111C11);
  static const _border      = Color(0xFF1E3A1E);
  static const _green       = Color(0xFF5FAD56);
  static const _greenDim    = Color(0xFF2D5A2D);
  static const _greenGlow   = Color(0xFF3D7A35);
  static const _textPrimary = Colors.white;
  static const _textSec     = Color(0xFFB0BEB0);
  static const _textMuted   = Color(0xFF4A6B4A);

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.username;

    _fadeController  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
    _fetchProfileFromServer();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _birthYearController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileFromServer() async {
    setState(() => _isLoadingProfile = true);
    // FIX: hapus token: widget.token — token diambil otomatis dari storage
    final serverData = await getProfileHook();
    if (serverData != null) {
      _applyProfileData(serverData);
    } else {
      final localData = await SendOtpHook.getUserData();
      if (localData != null) _applyProfileData(localData);
    }
    if (mounted) setState(() => _isLoadingProfile = false);
  }

  void _applyProfileData(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      _nameController.text      = (data['display_name'] ?? '').toString().trim().isNotEmpty
          ? data['display_name'].toString()
          : widget.username;
      _descController.text      = data['description']       ?? '';
      _birthYearController.text = data['birth_year']        ?? '';
      _profileImageUrl          = data['profile_image_url'];
    });
  }

  Future<void> _resetToServerData() async {
    // FIX: hapus token: widget.token
    final serverData = await getProfileHook();
    if (serverData != null) {
      _applyProfileData(serverData);
    } else {
      final localData = await SendOtpHook.getUserData();
      if (localData != null) _applyProfileData(localData);
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (!_isEditing) return;
    HapticFeedback.lightImpact();

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _profileImageFile = file;
      _isUploadingImage = true;
    });

    try {
      // FIX: hapus token: widget.token, tambah imageFile: file yang hilang
      final imageUrl = await uploadProfileImageHook(
        imageFile: file,
      );
      setState(() {
        _profileImageUrl  = imageUrl;
        _isUploadingImage = false;
      });
      _showSnackBar('Foto profile berhasil diupload');
    } catch (e) {
      setState(() {
        _profileImageFile = null;
        _isUploadingImage = false;
      });
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);
    try {
      await updateProfileHook(
        displayName: _nameController.text.trim(),
        description: _descController.text.trim(),
        birthYear:   _birthYearController.text.trim(),
      );
      setState(() {
        _isSaving  = false;
        _isEditing = false;
      });
      _showSnackBar('Profile berhasil diperbarui');
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline, color: _green, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message,
              style: const TextStyle(color: _textPrimary, fontSize: 13))),
        ]),
        backgroundColor: _card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message,
              style: const TextStyle(color: _textPrimary, fontSize: 13))),
        ]),
        backgroundColor: const Color(0xFF1A0F0F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(),
                if (_isLoadingProfile)
                  const SliverFillRemaining(
                    child: Center(
                      child: SizedBox(
                        width: 32, height: 32,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: _green),
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const SizedBox(height: 32),
                            _buildAvatarSection(),
                            const SizedBox(height: 32),
                            _buildInfoCard(),
                            const SizedBox(height: 16),
                            _buildFieldsCard(),
                            const SizedBox(height: 24),
                            if (_isEditing) _buildSaveButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: _bg,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      elevation: 0,
      expandedHeight: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border, width: 1),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textSec, size: 16),
        ),
      ),
      title: const Text('Profile',
          style: TextStyle(
            color: _textPrimary, fontSize: 17,
            fontWeight: FontWeight.w600, letterSpacing: 0.4,
          )),
      centerTitle: true,
      actions: [
        if (!_isLoadingProfile)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (_isEditing) {
                setState(() => _isEditing = false);
                _resetToServerData();
              } else {
                setState(() => _isEditing = true);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _isEditing ? _greenDim : _card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _isEditing ? _green : _border, width: 1),
              ),
              child: Center(
                child: Text(
                  _isEditing ? 'Cancel' : 'Edit',
                  style: TextStyle(
                    color: _isEditing ? _green : _textSec,
                    fontSize: 13, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withOpacity(0.05)),
      ),
    );
  }

  Widget _buildAvatarSection() {
    final initials = (_nameController.text.isNotEmpty
            ? _nameController.text[0]
            : widget.username.isNotEmpty ? widget.username[0] : 'U')
        .toUpperCase();

    return Column(
      children: [
        GestureDetector(
          onTap: _isEditing ? _pickAndUploadImage : null,
          child: Stack(
            children: [
              Container(
                width: 104, height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_green, _greenDim],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(color: _green.withOpacity(0.30),
                        blurRadius: 24, spreadRadius: 2),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: _card),
                  child: ClipOval(child: _buildAvatarContent(initials)),
                ),
              ),
              if (_isUploadingImage)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.55),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 28, height: 28,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: _green),
                      ),
                    ),
                  ),
                ),
              if (_isEditing && !_isUploadingImage)
                Positioned(
                  bottom: 2, right: 2,
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _green,
                      border: Border.all(color: _bg, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 15, color: Colors.black),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _nameController.text.isNotEmpty ? _nameController.text : widget.username,
          style: const TextStyle(
            color: _textPrimary, fontSize: 22,
            fontWeight: FontWeight.bold, letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(widget.email,
            style: const TextStyle(color: _textSec, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _greenDim.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _greenDim, width: 1),
          ),
          child: Text(widget.role,
              style: const TextStyle(
                color: _green, fontSize: 11,
                fontWeight: FontWeight.w600, letterSpacing: 1.2,
              )),
        ),
      ],
    );
  }

  Widget _buildAvatarContent(String initials) {
    if (_profileImageFile != null) {
      return Image.file(_profileImageFile!, fit: BoxFit.cover);
    }
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return Image.network(
        _profileImageUrl!, fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Center(
            child: SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2, color: _green,
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _initialsWidget(initials),
      );
    }
    return _initialsWidget(initials);
  }

  Widget _initialsWidget(String initials) => Center(
        child: Text(initials,
            style: const TextStyle(
              color: _green, fontWeight: FontWeight.bold,
              fontSize: 36, letterSpacing: -1,
            )));

  Widget _buildInfoCard() {
    return _GlassCard(
      child: Column(
        children: [
          _InfoRow(icon: Icons.mail_outline_rounded,
              label: 'Email', value: widget.email),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.white.withOpacity(0.05),
          ),
          _InfoRow(
            icon: Icons.verified_user_outlined,
            label: 'Account Role',
            value: widget.role,
            valueColor: _green,
          ),
        ],
      ),
    );
  }

  Widget _buildFieldsCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text('PERSONAL INFORMATION',
                style: TextStyle(
                  color: _green.withOpacity(0.9), fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 1.4,
                )),
          ),
          _buildField(
            controller: _nameController,
            label: 'Display Name', hint: 'Enter your name',
            icon: Icons.person_outline_rounded, enabled: _isEditing,
            validator: (v) =>
                v == null || v.isEmpty ? 'Name cannot be empty' : null,
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _descController,
            label: 'Bio / Description',
            hint: 'Tell something about yourself...',
            icon: Icons.notes_rounded, enabled: _isEditing, maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _birthYearController,
            label: 'Birth Year', hint: 'e.g. 1998',
            icon: Icons.cake_outlined, enabled: _isEditing,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            validator: (v) {
              if (v == null || v.isEmpty) return null;
              final year = int.tryParse(v);
              if (year == null || year < 1900 || year > DateTime.now().year) {
                return 'Enter a valid birth year';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _saveProfile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isSaving ? [_greenDim, _greenDim] : [_green, _greenGlow],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _isSaving ? [] : [
            BoxShadow(color: _green.withOpacity(0.35),
                blurRadius: 18, offset: const Offset(0, 6)),
          ],
        ),
        child: Center(
          child: _isSaving
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.black),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, color: Colors.black, size: 20),
                    SizedBox(width: 8),
                    Text('Save Changes',
                        style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold,
                          fontSize: 15, letterSpacing: 0.3,
                        )),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool enabled,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              color: _textSec, fontSize: 12,
              fontWeight: FontWeight.w500, letterSpacing: 0.3,
            )),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(color: _textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _textMuted, fontSize: 14),
            prefixIcon: Icon(icon, size: 18,
                color: enabled ? _green : _textMuted),
            filled: true,
            fillColor: enabled ? _surface : const Color(0xFF0C0C0C),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _green, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.05), width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFFF5252), width: 1),
            ),
            errorStyle:
                const TextStyle(color: Color(0xFFFF5252), fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111C11),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A1E), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5FAD56).withOpacity(0.04),
            blurRadius: 20, spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A1A),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFF5FAD56)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                    color: Color(0xFF4A6B4A), fontSize: 11,
                    fontWeight: FontWeight.w500, letterSpacing: 0.3,
                  )),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                    color: valueColor ?? Colors.white,
                    fontSize: 14, fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}