import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../providers/profile_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}


class _EditProfileScreenState extends State<EditProfileScreen> {

  late TextEditingController nameController;
  late TextEditingController bioController;


  @override
  void initState() {
    super.initState();

    final profile =
        context.read<ProfileProvider>().profile;

    nameController = TextEditingController(
      text: profile?.name ?? '',
    );

    bioController = TextEditingController(
      text: profile?.bio ?? '',
    );
  }


  @override
  void dispose() {
    nameController.dispose();
    bioController.dispose();
    super.dispose();
  }


  Future<void> _save() async {

    await context.read<ProfileProvider>().updateProfile(
      name: nameController.text,
      bio: bioController.text,
    );


    if (!mounted) return;

    Navigator.pop(context);
  }



  @override
  Widget build(BuildContext context) {

    final loading =
        context.watch<ProfileProvider>().loading;

    final l10n = AppLocalizations.of(context);

    return Scaffold(

      appBar: AppBar(
        title: Text(l10n.editProfile),
      ),


      body: Padding(

        padding: const EdgeInsets.all(20),

        child: Column(

          children: [

            TextField(
              controller: nameController,

              decoration: InputDecoration(
                labelText: l10n.name,
              ),
            ),


            const SizedBox(height: 20),


            TextField(
              controller: bioController,

              maxLines: 3,

              decoration: InputDecoration(
                labelText: l10n.bio,
              ),
            ),


            const SizedBox(height: 30),


            SizedBox(
              width: double.infinity,

              child: ElevatedButton(

                onPressed: loading ? null : _save,

                child: loading
                    ? const CircularProgressIndicator()
                    : Text(l10n.save),

              ),
            ),

          ],
        ),
      ),
    );
  }
}