import 'package:flutter/material.dart';

import '../models/group_member.dart';
import '../services/api_service.dart';
import 'create_group_screen.dart';

class GroupMembersScreen extends StatefulWidget {
  const GroupMembersScreen({super.key});

  @override
  State<GroupMembersScreen> createState() =>
      _GroupMembersScreenState();
}

class _GroupMembersScreenState
    extends State<GroupMembersScreen> {

  final TextEditingController searchController =
  TextEditingController();

  List<GroupMember> users = [];
  List<GroupMember> filteredUsers = [];

  final List<GroupMember> selected = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    final result = await ApiService.getUsers();

    setState(() {
      users = result;
      filteredUsers = result;
      loading = false;
    });
  }

  void search(String value) {
    setState(() {
      filteredUsers = users.where((u) {
        return u.name
            .toLowerCase()
            .contains(value.toLowerCase());
      }).toList();
    });
  }

  void toggle(GroupMember user) {
    setState(() {
      if (selected.contains(user)) {
        selected.remove(user);
      } else {
        selected.add(user);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "New Group (${selected.length})",
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: selected.isEmpty
            ? null
            : () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateGroupScreen(
                members: selected,
              ),
            ),
          );
        },
        child: const Icon(Icons.arrow_forward),
      ),

      body: loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : Column(
        children: [

          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: searchController,
              onChanged: search,
              decoration: const InputDecoration(
                hintText: "Search...",
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (_, i) {

                final user = filteredUsers[i];

                final checked =
                selected.contains(user);

                return CheckboxListTile(

                  value: checked,

                  onChanged: (_) =>
                      toggle(user),

                  title: Text(user.name),

                  secondary: CircleAvatar(
                    child: Text(
                      user.name[0],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}