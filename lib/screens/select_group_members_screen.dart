import 'package:flutter/material.dart';

import '../models/group_member.dart';
import '../services/api_service.dart';
import 'create_group_screen.dart';

class SelectGroupMembersScreen extends StatefulWidget {
  const SelectGroupMembersScreen({super.key});

  @override
  State<SelectGroupMembersScreen> createState() =>
      _SelectGroupMembersScreenState();
}

class _SelectGroupMembersScreenState
    extends State<SelectGroupMembersScreen> {

  final TextEditingController searchController =
  TextEditingController();

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
    try {
      final data = await ApiService.getUsers();

      setState(() {
        users = data;
        filtered = data;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
    }
  }

  void search(String value) {
    setState(() {
      filtered = users.where((u) {
        return u.name
            .toLowerCase()
            .contains(value.toLowerCase());
      }).toList();
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

  Future<void> next() async {
    if (selected.isEmpty) return;

    final group = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGroupScreen(
          members: selected,
        ),
      ),
    );

    if (group != null && mounted) {
      Navigator.pop(context, group);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Members"),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: selected.isEmpty ? null : next,
        child: const Icon(Icons.arrow_forward),
      ),

      body: Column(
        children: [

          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              onChanged: search,
              decoration: const InputDecoration(
                hintText: "Search...",
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),

          if (loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, index) {

                  final member = filtered[index];

                  final checked = selected.any(
                        (e) => e.id == member.id,
                  );

                  return CheckboxListTile(
                    value: checked,

                    onChanged: (_) => toggle(member),

                    secondary: CircleAvatar(
                      child: Text(member.name[0]),
                    ),

                    title: Text(member.name),

                    subtitle: Text(member.email),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}