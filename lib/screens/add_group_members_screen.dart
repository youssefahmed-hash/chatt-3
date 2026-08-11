import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../models/group_member.dart';
import '../services/api_service.dart';

class AddGroupMembersScreen extends StatefulWidget {
  final Chat chat;

  const AddGroupMembersScreen({
    super.key,
    required this.chat,
  });

  @override
  State<AddGroupMembersScreen> createState() =>
      _AddGroupMembersScreenState();
}

class _AddGroupMembersScreenState
    extends State<AddGroupMembersScreen> {

  List<GroupMember> users = [];
  List<GroupMember> filtered = [];
  List<GroupMember> selected = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    final all = await ApiService.getUsers();

    final available = all.where((u) {
      return !widget.chat.members
          .any((m) => m.id == u.id);
    }).toList();

    setState(() {
      users = available;
      filtered = available;
      loading = false;
    });
  }

  void toggle(GroupMember member) {
    setState(() {
      if (selected.any((e) => e.id == member.id)) {
        selected.removeWhere((e) => e.id == member.id);
      } else {
        selected.add(member);
      }
    });
  }

  Future<void> addMembers() async {
    if (selected.isEmpty) return;

    final members = await ApiService.addMembers(
      conversationId: widget.chat.id!,
      members: selected.map((e) => e.id).toList(),
    );

    if (!mounted) return;

    Navigator.pop(context, members);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Members"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addMembers,
        child: const Icon(Icons.check),
      ),
      body: loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (_, i) {
          final member = filtered[i];

          final checked = selected.any(
                (e) => e.id == member.id,
          );

          return CheckboxListTile(
            value: checked,
            onChanged: (_) => toggle(member),
            title: Text(member.name),
            secondary: CircleAvatar(
              child: Text(member.name[0]),
            ),
          );
        },
      ),
    );
  }
}