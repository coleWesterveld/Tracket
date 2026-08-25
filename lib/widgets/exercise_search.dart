import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'custom_exercise_form.dart';
import 'app_message.dart';

// TODO: the add custom exercise should maybe pop conditionally, default to true
// the current functionality in the analytics page is stupid
// also, try adding a new exercise in analytics -- it says no history for ""this execise" which I think is just my default value
// I think this is an async await DB read/write logic error, so think of a good way to set everything up for good UX and then implement
class ExerciseSearchWidget extends StatefulWidget {
  const ExerciseSearchWidget({
    super.key,
    this.onExerciseSelected,
    this.onDismiss,
    required this.theme,
  });

  /// Called when an exercise is selected.
  ///
  /// Awaited before the search closes, so a caller that writes to the database
  /// finishes while its own screen is still up. Throwing is fine: the search
  /// closes either way, and the caller owns telling the user it failed.
  final Future<void> Function(Map<String, dynamic> exercise)? onExerciseSelected;

  /// Called when the user leaves the search, either by backing out or once a
  /// selection has been fully handled.
  ///
  /// This is the ONLY thing that closes the search. It is deliberately not
  /// wired to the search field's focus: focus comes and goes for reasons that
  /// have nothing to do with wanting to leave (the return key, the keyboard
  /// being put away, a field on another screen taking focus), and closing the
  /// page on any of those tore the results list down mid-tap.
  final VoidCallback? onDismiss;

  final ThemeData theme;

  @override
  State<ExerciseSearchWidget> createState() => _ExerciseSearchWidgetState();
}

class _ExerciseSearchWidgetState extends State<ExerciseSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

  String _searchQuery = "";
  List<Map<String, dynamic>> _exercises = [];
  bool _showCustomMaker = false;

  /// True from the moment a row is tapped until the caller is done with it.
  /// Stops a second tap landing while the first is still being written, which
  /// is how the same exercise ended up added twice.
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    _loadExercisesFromDatabase();

    // Automatically focus the search field when the widget appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadExercisesFromDatabase() async {
    final exercises = await dbHelper.fetchExercisesWithIds();
    if (!mounted) return;
    setState(() => _exercises = exercises);
  }

  /// Hands [exercise] to the caller, waits for it to be dealt with, then leaves.
  Future<void> _select(Map<String, dynamic> exercise) async {
    if (_selecting) return;
    setState(() => _selecting = true);

    try {
      await widget.onExerciseSelected?.call(exercise);
    } finally {
      if (mounted) {
        _searchFocus.unfocus();
        widget.onDismiss?.call();
      }
    }
  }

  void _dismiss() {
    _searchFocus.unfocus();
    widget.onDismiss?.call();
  }

  Future<void> _deleteExercise(int exerciseId) async {
    try {
      await dbHelper.deleteExercise(exerciseId);
      // Reload exercises after deletion
      await _loadExercisesFromDatabase();
    } catch (e) {
      //debugPrint('Error deleting exercise: $e');
      if (mounted) {
        showAppMessage(context, 'Error deleting exercise: $e', isError: true);
      }
    }
  }

  void _showDeleteExerciseDialog(Map<String, dynamic> exercise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Exercise"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Are you sure you want to delete ${exercise['exercise_title']}?"),
            const SizedBox(height: 12),
            Text(
              "This will also delete:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: widget.theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 4),
            Text("• All workout history for this exercise",
                style: TextStyle(color: widget.theme.colorScheme.error)),
            Text("• All goals for this exercise",
                style: TextStyle(color: widget.theme.colorScheme.error)),
            Text("• All planned sets in programs",
                style: TextStyle(color: widget.theme.colorScheme.error)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteExercise(exercise['id']);
            },
            child: Text(
              "Delete",
              style: TextStyle(color: widget.theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenSearch(List<Map<String, dynamic>> filteredExercises) {
    return _showCustomMaker ? CustomExerciseForm(
      height: MediaQuery.of(context).size.height-MediaQuery.of(context).viewInsets.bottom,
      exit: ()=> setState(() {
        _showCustomMaker=false;

      }),
      onDone: (exercise) => _select(exercise),

      theme: widget.theme,
    ):
    GestureDetector(
      // Tapping the backdrop puts the keyboard away, the same gesture every
      // other page in the app uses. Leaving is the back arrow's job: closing
      // the whole search on a stray tap reads as "it lost my selection".
      onTap: () => _searchFocus.unfocus(),
      child: Material(
        child: Container(
          color: Colors.black.withOpacity(0.8),
          child: Column(
            children: [
              // Search bar row with back arrow.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _dismiss,
                    ),
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        showCursor: true,
                        cursorColor: Colors.white,
                        controller: _searchController,
                        focusNode: _searchFocus,
                        onChanged: (query) {
                          setState(() {
                            _searchQuery = query;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "Search exercise",
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      )

                    ),
                  ],
                ),
              ),
              // Expanded list view for exercises.
              Expanded(
                child: ListView.builder(
                  itemCount: filteredExercises.length,
                  itemBuilder: (context, index) {
                    final exercise = filteredExercises[index];
                    return ListTile(
                      title: Text(
                        exercise['exercise_title'],
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        final modifiedExercise = Map<String, dynamic>.from(exercise);

                        // Rename 'id' to 'exercise_id'
                        // this is remnant of old bad naming convention that should prolly be solved at the root at some point
                        modifiedExercise['exercise_id'] = modifiedExercise.remove('id');

                        _select(modifiedExercise);
                      },

                      onLongPress: () {
                        _showDeleteExerciseDialog(exercise);
                      },
                    );
                  },
                ),
              ),
              // Footer button: always visible at the bottom.
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ButtonTheme(
                    minWidth: double.infinity,
                    child: ElevatedButton(
                      style: ButtonStyle(
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        backgroundColor: WidgetStateProperty.all(const Color(0xFF007aff)),
                      ),
                      onPressed: () {
                        // Prevent the outer GestureDetector from handling this tap.
                        // Call your custom logic to show a modal or add a new exercise.
                        setState(()=>_showCustomMaker = true);
                      },
                      child: const Text(
                        'Add New Exercise',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Filter exercises based on the search query.
    List<Map<String, dynamic>> filteredExercises = _exercises
        .where((exercise) => exercise['exercise_title']
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();

    // While a selection is being written the list must not take another tap.
    return AbsorbPointer(
      absorbing: _selecting,
      child: _buildFullScreenSearch(filteredExercises),
    );
  }
}
