// Side drawer to edit, select and add programs

import 'package:firstapp/data_io/data_export_import.dart';
import 'package:firstapp/data_io/starter_programs.dart';
import 'package:firstapp/database/database_helper.dart';
import 'package:firstapp/database/profile.dart';
import 'package:firstapp/providers_and_settings/program_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgramsDrawer extends StatefulWidget {
  final int currentProgramId;
  final Function(Program) onProgramSelected;
  final ThemeData theme;

  const ProgramsDrawer({
    required this.currentProgramId,
    required this.onProgramSelected,
    required this.theme,
    super.key,
  });

  @override
  State<ProgramsDrawer> createState() => _ProgramsDrawerState();
}

class _ProgramsDrawerState extends State<ProgramsDrawer> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  static const _drawerHintKey = 'programs_drawer_hint_shown';

  @override
  void initState() {
    super.initState();
    _maybeShowHint();
  }

  Future<void> _maybeShowHint() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_drawerHintKey) == true) return;

    await prefs.setBool(_drawerHintKey, true);

    if (!mounted) return;

    // Show after a short delay so the drawer is fully open
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Programs', textAlign: TextAlign.center),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.touch_app, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Tap a program to switch to it')),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.delete_outline, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Hold down on a program to delete it')),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.file_download, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Import programs shared by friends or browse starter templates')),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.file_upload, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Share your programs with others')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<List<Program>> _fetchPrograms() async {
    final programMaps = await dbHelper.fetchPrograms();
    return programMaps.map((map) => Program.fromMap(map)).toList();
  }

  Future<void> _importProgram() async {
    final result = await DataExportImport.importProgram();
    if (!mounted) return;

    if (result.success && result.programId != null) {
      final newProgram = await dbHelper.fetchProgramById(result.programId!);
      widget.onProgramSelected(newProgram);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${newProgram.programTitle}" imported!')),
        );
        setState(() {}); // refresh the list
      }
    } else if (!result.cancelled && result.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: ${result.errorMessage}')),
      );
    }
  }

  Future<void> _exportProgram(int programId, BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await DataExportImport.exportProgram(programId, sharePositionOrigin: origin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _showStarterPrograms() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Starter Programs',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Add a pre-built program to get started quickly. You can customize it after.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            ...StarterPrograms.templates.map((template) => ListTile(
              leading: const Icon(Icons.fitness_center),
              title: Text(template.title),
              subtitle: Text('${template.daysPerWeek} days/week — ${template.description}'),
              onTap: () async {
                Navigator.pop(context); // close bottom sheet
                final result = await StarterPrograms.addProgram(template);
                if (!mounted) return;

                if (result.success && result.programId != null) {
                  final newProgram = await dbHelper.fetchProgramById(result.programId!);
                  widget.onProgramSelected(newProgram);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"${template.title}" added!')),
                    );
                    setState(() {});
                  }
                } else if (result.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: ${result.errorMessage}')),
                  );
                }
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Drawer(
        backgroundColor: widget.theme.colorScheme.surface,
        child: FutureBuilder<List<Program>>(
          future: _fetchPrograms(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Center(child: Text('Error loading programs'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No programs found'));
            }

            final programs = snapshot.data!;
            return Column(
              children: [
                 DrawerHeader(
                  decoration: BoxDecoration(
                    color: widget.theme.colorScheme.surface,
                  ),

                  child: Center(
                    child: Text(
                      'Your Programs',
                      style: TextStyle(
                        color: widget.theme.colorScheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: programs.length,
                    itemBuilder: (context, index) {
                      final program = programs[index];
                      return ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                program.programTitle,
                                style: TextStyle(
                                  color: widget.theme.colorScheme.onSurface
                                ),
                              ),
                            ),
                            if (program.programID == widget.currentProgramId)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Builder(
                                    builder: (btnContext) => IconButton(
                                      icon: Icon(
                                        Icons.file_upload_outlined,
                                        color: widget.theme.colorScheme.onSurface,
                                        size: 20,
                                      ),
                                      tooltip: 'Share this program',
                                      onPressed: () => _exportProgram(program.programID, btnContext),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      color: widget.theme.colorScheme.onSurface,
                                      size: 20
                                    ),
                                    onPressed: () => _showEditProgramDialog(context, program),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        selected: program.programID == widget.currentProgramId,
                        selectedTileColor: widget.theme.colorScheme.outline,
                        onTap: () {
                          widget.onProgramSelected(program);
                          Navigator.pop(context);
                        },
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext dialogContext) {
                              return AlertDialog(
                                title: const Text('Delete This Program?'),
                                content: const Text('Do you want to delete this program?'),
                                actions: [
                                  TextButton(
                                    child: const Text('No, go back'),
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop();
                                    },
                                  ),
                                  TextButton(
                                    child: const Text(
                                      'Delete Program',
                                      style: TextStyle(
                                        color: Colors.red,
                                      )
                                    ),
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop();
                                      context.read<Profile>().deleteProgram(programs[index].programID);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),

                Divider(color: widget.theme.colorScheme.outline),

                ListTile(
                  leading: Icon(
                    Icons.add,
                    color: widget.theme.colorScheme.onSurface
                  ),
                  title: Text(
                    'Create New Program',
                    style: TextStyle(color: widget.theme.colorScheme.onSurface),
                  ),
                  onTap: () {
                    showCreateProgramDialog(context);
                  },
                ),

                ListTile(
                  leading: Icon(
                    Icons.download,
                    color: widget.theme.colorScheme.onSurface,
                  ),
                  title: Text(
                    'Import Program',
                    style: TextStyle(color: widget.theme.colorScheme.onSurface),
                  ),
                  onTap: _importProgram,
                ),

                ListTile(
                  leading: Icon(
                    Icons.library_books,
                    color: widget.theme.colorScheme.onSurface,
                  ),
                  title: Text(
                    'Starter Programs',
                    style: TextStyle(color: widget.theme.colorScheme.onSurface),
                  ),
                  onTap: _showStarterPrograms,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showEditProgramDialog(BuildContext context, Program program) {
    final programNameController = TextEditingController(text: program.programTitle);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Program'),
        content: TextField(
          controller: programNameController,
          selectAllOnFocus: true,
          decoration: const InputDecoration(hintText: 'Enter new program name'),
        ),
        actions: [

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),

          TextButton(
            onPressed: () async {
              if (programNameController.text.isNotEmpty) {
                final updatedProgram = program.copyWith(
                  newTitle: programNameController.text
                );

                // Update program in database
                await dbHelper.updateProgram(updatedProgram);

                // If editing current program, update the selection
                if (program.programID == widget.currentProgramId) {
                  widget.onProgramSelected(updatedProgram);
                }

                if (context.mounted){
                  Navigator.pop(context);
                }

              }
            },
            child: const Text('Save'),
          ),


        ],
      ),
    );
  }

  void showCreateProgramDialog(BuildContext context) {
    final programNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Program'),

        content: TextField(
          controller: programNameController,
          autofocus: true,
          selectAllOnFocus: true,
          decoration: const InputDecoration(hintText: 'Enter program name'),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),

          TextButton(
            onPressed: () async {
              if (programNameController.text.isNotEmpty) {
                final id = await dbHelper.insertProgram(
                  programNameController.text,
                );

                final newProgram = Program(
                  programID: id,
                  programTitle: programNameController.text,
                );

                widget.onProgramSelected(newProgram);

                if (context.mounted){
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
