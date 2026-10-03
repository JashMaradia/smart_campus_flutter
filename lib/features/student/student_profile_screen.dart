import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/validators.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/domain/campus_repository.dart';
import 'package:smart_campus/features/auth/auth_provider.dart';
import 'package:smart_campus/features/shared/settings_screen.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});

  Future<void> _pickPhoto(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;
    final repo = context.read<CampusRepository>();
    final auth = context.read<AuthProvider>();
    try {
      final file = await ImagePicker()
          .pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 80);
      if (file == null) return;
      final saved = await persistFile(file.path, 'photos');
      final s = auth.student!;
      await repo.updateStudentSelf(s.id!, phone: s.phone, address: s.address, photoPath: saved);
      await auth.reload();
      if (context.mounted) showSnack(context, 'Profile photo updated');
    } catch (e) {
      if (context.mounted) {
        showSnack(context, 'Could not update the photo. Check app permissions. ($e)', error: true);
      }
    }
  }

  Future<void> _edit(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final repo = context.read<CampusRepository>();
    final s = auth.student!;
    final form = GlobalKey<FormState>();
    final phone = TextEditingController(text: s.phone);
    final address = TextEditingController(text: s.address);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit contact details'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              AppTextField(
                controller: phone,
                label: 'Phone',
                icon: Icons.phone_outlined,
                keyboard: TextInputType.phone,
                maxLength: 10,
                formatters: [FilteringTextInputFormatter.digitsOnly],
                validator: Validators.phone,
              ),
              const SizedBox(height: 12),
              AppTextField(
                  controller: address, label: 'Address', icon: Icons.home_outlined, maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final p = phone.text.trim();
    final a = address.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      phone.dispose();
      address.dispose();
    });
    if (ok != true) return;
    await repo.updateStudentSelf(s.id!, phone: p, address: a);
    await auth.reload();
    if (context.mounted) showSnack(context, 'Profile updated');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AuthProvider>().student!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: MaxWidth(
        width: 640,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                children: [
                  Stack(
                    children: [
                      UserAvatar(
                          name: s.name,
                          photoPath: s.photoPath,
                          radius: 54,
                          heroTag: 'profile-photo'),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IconButton.filled(
                          tooltip: 'Change photo',
                          onPressed: () => _pickPhoto(context),
                          icon: const Icon(Icons.photo_camera_outlined, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(s.name,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  Text(s.studentId, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const SectionHeader('Details'),
            AppCard(
              child: Column(
                children: [
                  InfoRow('Name', s.name, icon: Icons.person_outline),
                  InfoRow('Student ID', s.studentId, icon: Icons.badge_outlined),
                  InfoRow('Email', s.email, icon: Icons.mail_outline),
                  InfoRow('Phone', s.phone, icon: Icons.phone_outlined),
                  InfoRow('Course', s.program, icon: Icons.school_outlined),
                  InfoRow('Semester', '${s.semester}', icon: Icons.layers_outlined),
                  InfoRow('Department', s.department, icon: Icons.apartment_outlined),
                  InfoRow('Address', s.address, icon: Icons.home_outlined),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text('You can edit your phone number, address and photo. Other details are managed by the college.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit contact details'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => showChangePasswordDialog(context),
              icon: const Icon(Icons.lock_reset),
              label: const Text('Change password'),
            ),
          ],
        ),
      ),
    );
  }
}
