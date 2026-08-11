import 'dart:async';
import '../services/socket_service.dart';
import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/group_member.dart';
import '../services/session.dart';
import 'add_group_members_screen.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import 'package:image_picker/image_picker.dart';

class GroupInfoScreen extends StatefulWidget {
  final Chat chat ;

  const GroupInfoScreen({super.key, required this.chat});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {

  StreamSubscription<GroupMembersUpdatedEvent>? _membersSub;

  StreamSubscription<GroupAdminsUpdatedEvent>? _adminsSub;

  StreamSubscription<GroupUpdatedEvent>? _groupUpdatedSub;
  final ImagePicker _picker = ImagePicker();
  Future<void> _changeGroupImage() async {

    if (!widget.chat.admins.contains(Session.userId)) {
      return;
    }

    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;

    try {

      final imagePath =
      await ApiService.updateGroupImage(
        conversationId: widget.chat.id!,
        image: image,
      );

      setState(() {
        widget.chat.groupImage = imagePath;
      });

      setState(() {
        widget.chat.groupImage =
        "${ApiConfig.baseUrl}/uploads/groups/${image.name}";
      });

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  Future<void> _editGroupName() async {
    final controller = TextEditingController(
      text: widget.chat.name,
    );

    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Group Name"),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(
            hintText: "Group name",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                controller.text.trim(),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      await ApiService.updateGroupName(
        conversationId: widget.chat.id!,
        name: name,
      );

      setState(() {
        widget.chat.name= name;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Group name updated"),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    _adminsSub =
        SocketService.instance.onGroupAdminsUpdated.listen((event){

          if(event.conversationId!=widget.chat.id)return;

          setState((){

            widget.chat.admins
              ..clear()
              ..addAll(event.admins);

          });

        });

    _groupUpdatedSub =
        SocketService.instance.onGroupUpdated.listen((event) {

          if (event.conversationId != widget.chat.id) return;

          setState(() {

            widget.chat.name = event.groupName;

            if (event.groupImage != null) {
              widget.chat.groupImage = event.groupImage;
            }

          });

        });

    _membersSub =
        SocketService.instance.onGroupMembersUpdated.listen((event) {

          if (event.conversationId != widget.chat.id) return;

          setState(() {
            widget.chat.members
              ..clear()
              ..addAll(
                event.members.map(
                      (e) => GroupMember.fromJson(e),
                ),
              );
          });
        });
  }

  @override
  void dispose() {
    _membersSub?.cancel();
    _adminsSub?.cancel();
    _groupUpdatedSub?.cancel();

    // controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUserAdmin = widget.chat.admins.contains(Session.userId);
    return Scaffold(
      appBar: AppBar(title: const Text("Group Info")),
      body: ListView(
        children: [
          const SizedBox(height: 25),
          GestureDetector(
            onTap: _changeGroupImage,
            child: CircleAvatar(
              radius: 55,
              backgroundColor: Colors.grey.shade300,

              backgroundImage: widget.chat.groupImage != null &&
                  widget.chat.groupImage!.isNotEmpty
                  ? NetworkImage(
                "${ApiConfig.baseUrl}${widget.chat.groupImage}",
              )
                  : null,

              child: widget.chat.groupImage == null ||
                  widget.chat.groupImage!.isEmpty
                  ? Text(
                widget.chat.name[0].toUpperCase(),
                style: const TextStyle(fontSize: 30),
              )
                  : null,
            ),
          ),
          const SizedBox(height: 20),

          ListTile(
            title: Center(
              child: Text(
                widget.chat.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            subtitle: Center(
              child: Text(
                "${widget.chat.members.length} participants",
              ),
            ),
            trailing: isCurrentUserAdmin
                ? IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editGroupName,
            )
                : null,
          ),

          const Divider(),
          if (isCurrentUserAdmin)
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text("Add Members"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 18),
              onTap: () async {
                final List<GroupMember>? members =
                    await Navigator.push<List<GroupMember>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddGroupMembersScreen(chat: widget.chat),
                      ),
                    );
                if (members == null) return;
                setState(() {
                  widget.chat.members = members;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Members added successfully")),
                );
              },
            ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Members",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
          ...widget.chat.members.map((member) {
            final bool memberIsAdmin = widget.chat.admins.contains(member.id);
            final isCreator = widget.chat.createdBy == Session.userId;
            final memberIsCreator = member.id == widget.chat.createdBy;
            return ListTile(
              leading: CircleAvatar(child: Text(member.name[0].toUpperCase())),
              title: Text(member.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [

                  if (memberIsAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Admin",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  if (

                  // منشئ الجروب
                  (isCreator &&
                      member.id != Session.userId)

                      ||

                      // أدمن عادي
                      (!isCreator &&
                          isCurrentUserAdmin &&
                          !memberIsAdmin &&
                          !memberIsCreator &&
                          member.id != Session.userId)

                  )
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        switch (value) {
                          case 'remove':

                            await ApiService.removeMember(
                              conversationId: widget.chat.id!,
                              memberId: member.id,
                            );

                            break;

                          case 'make_admin':

                            await ApiService.makeAdmin(

                              conversationId: widget.chat.id!,

                              memberId: member.id,

                            );

                            break;

                          case 'remove_admin':

                            final admins = await ApiService.removeAdmin(
                              conversationId: widget.chat.id!,
                              memberId: member.id,
                            );

                            setState(() {
                              widget.chat.admins
                                ..clear()
                                ..addAll(admins);
                            });

                            break;
                        }
                      },

                      itemBuilder: (_) => [

                        const PopupMenuItem(
                          value: 'remove',
                          child: Text("Remove Member"),
                        ),

                        if (!memberIsAdmin)
                          const PopupMenuItem(
                            value: 'make_admin',
                            child: Text("Make Admin"),
                          ),

                        if (memberIsAdmin && isCreator)
                          const PopupMenuItem(
                            value: 'remove_admin',
                            child: Text("Remove Admin"),
                          ),
                      ],
                    ),
                ],
              ),
            );
          }),
          if (isCurrentUserAdmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text("You are an admin"),
            ),
          const Divider(),

          ListTile(

            leading: const Icon(
              Icons.exit_to_app,
              color: Colors.red,
            ),

            title: const Text(
              "Leave Group",
              style: TextStyle(
                color: Colors.red,
              ),
            ),

            onTap: () async {

              final leave = await showDialog<bool>(

                context: context,

                builder: (_) => AlertDialog(

                  title: const Text("Leave Group"),

                  content: const Text(
                    "Are you sure you want to leave this group?",
                  ),

                  actions: [

                    TextButton(

                      onPressed: () {

                        Navigator.pop(context,false);

                      },

                      child: const Text("Cancel"),

                    ),

                    TextButton(

                      onPressed: () {

                        Navigator.pop(context,true);

                      },

                      child: const Text(
                        "Leave",
                        style: TextStyle(color: Colors.red),
                      ),

                    ),

                  ],

                ),

              );

              if (leave != true) return;

              await ApiService.leaveGroup(
                conversationId: widget.chat.id!,
              );

              if (!mounted) return;

              Navigator.pop(context, true);
            },

          ),
        ],
      ),
    );
  }
}
