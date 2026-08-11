import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/group_member.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class CreateGroupScreen extends StatefulWidget {
  final List<GroupMember> members;

  const CreateGroupScreen({
    super.key,
    required this.members,
  });


  @override
  State<CreateGroupScreen> createState() =>
      _CreateGroupScreenState();
}

class _CreateGroupScreenState
    extends State<CreateGroupScreen> {

  final TextEditingController nameController =
  TextEditingController();

  final ImagePicker _picker = ImagePicker();

  XFile? _groupImage;

  bool loading = false;


  Future<void> _pickGroupImage() async {

    final image = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image == null) return;

    print(image.path);


    setState(() {
      _groupImage = image;
    });

    print(_groupImage?.path);


  }

  Future<void> createGroup() async {
    final name = nameController.text.trim();

    if (name.isEmpty) return;

    setState(() {
      loading = true;
    });

    try {
      final group = await ApiService.createGroup(
        name: name,
        members: widget.members
            .map((e) => e.id)
            .toList(),
        image: _groupImage,
      );
      if (!mounted) return;

      Navigator.pop(context, group);
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("New Group"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(

          children: [

            const SizedBox(height: 20),

            GestureDetector(

              onTap: _pickGroupImage,

              child: CircleAvatar(

                radius: 45,

                backgroundImage: _groupImage != null
                    ? (kIsWeb
                    ? NetworkImage(_groupImage!.path)
                    : FileImage(
                  File(_groupImage!.path),
                )) as ImageProvider
                    : null,

                child: _groupImage == null
                    ? const Icon(
                  Icons.camera_alt,
                  size: 35,
                )
                    : null,
              ),
            ),

            const SizedBox(height: 25),

            TextField(

              controller: nameController,

              decoration: const InputDecoration(

                labelText: "Group Name",

                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),

            Align(
              alignment: Alignment.centerLeft,

              child: Text(

                "Members (${widget.members.length})",

                style: const TextStyle(

                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 10),

            Expanded(

              child: ListView.builder(

                itemCount: widget.members.length,

                itemBuilder: (_, i) {

                  final member = widget.members[i];

                  return ListTile(

                    leading: CircleAvatar(
                      child: Text(member.name[0]),
                    ),

                    title: Text(member.name),
                  );
                },
              ),
            ),

            SizedBox(

              width: double.infinity,

              height: 50,

              child: ElevatedButton(

                onPressed: loading
                    ? null
                    : () {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Enter group name"),
                      ),
                    );
                    return;
                  }

                  createGroup();
                },

                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("Create Group"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}