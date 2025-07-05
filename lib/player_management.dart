import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'Data/team.dart';
import 'Data/player.dart';

import 'stats_recorder.dart';

class PlayerManagement extends StatefulWidget {
  final String matchId;
  final Team team1;
  final Team team2;

  const PlayerManagement({
    super.key,
    required this.matchId,
    required this.team1,
    required this.team2,
  });

  @override
  State<PlayerManagement> createState() => _PlayerManagementState();
}

class _PlayerManagementState extends State<PlayerManagement> {
  String? _expandedTeamId; // Track which team is expanded
  Player? _selectedPlayer;
  late PlayerModel playerModel;
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isAddingPlayer = false;
  String? _currentEditingTeamId; // Track which team is being edited

  // Store players for both teams
  List<Player> _team1Players = [];
  List<Player> _team2Players = [];

  // Controllers for player editor
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    playerModel = Provider.of<PlayerModel>(context, listen: false);
    // Use addPostFrameCallback to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBothTeams();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  // Load players for both teams
  Future<void> _loadBothTeams() async {
    try {
      // Load team 1 players
      await playerModel.setCurrentTeamAndMatch(widget.matchId, widget.team1.id);
      _team1Players = List.from(playerModel.items);

      // Load team 2 players
      await playerModel.setCurrentTeamAndMatch(widget.matchId, widget.team2.id);
      _team2Players = List.from(playerModel.items);

      // Only call setState if the widget is still mounted
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading teams: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading teams: $e')),
        );
      }
    }
  }

  // Convert base64 string to Image widget
  Widget _buildProfileImage(String? profileURL, double radius) {
    if (profileURL == null || profileURL.trim().isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.grey[300],
        radius: radius,
        child: Icon(
          Icons.person,
          size: radius * 1.2,
          color: Colors.grey[600],
        ),
      );
    }

    try {
      // Check if it's a base64 string
      if (profileURL.startsWith('data:image') || profileURL.length > 100) {
        // Extract base64 data if it includes data URL prefix
        String base64String = profileURL;
        if (profileURL.startsWith('data:image')) {
          base64String = profileURL.split(',')[1];
        }

        Uint8List imageBytes = base64Decode(base64String);
        return CircleAvatar(
          backgroundImage: MemoryImage(imageBytes),
          radius: radius,
        );
      } else {
        // If it's a short string, treat it as invalid and show default
        return CircleAvatar(
          backgroundColor: Colors.grey[300],
          radius: radius,
          child: Icon(
            Icons.person,
            size: radius * 1.2,
            color: Colors.grey[600],
          ),
        );
      }
    } catch (e) {
      // If base64 decoding fails, use default icon
      return CircleAvatar(
        backgroundColor: Colors.grey[300],
        radius: radius,
        child: Icon(
          Icons.person,
          size: radius * 1.2,
          color: Colors.grey[600],
        ),
      );
    }
  }

  // Convert image file to base64 string
  Future<String?> _convertImageToBase64(File imageFile) async {
    try {
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64String = base64Encode(imageBytes);
      return base64String;
    } catch (e) {
      print('Error converting image to base64: $e');
      return null;
    }
  }

  // Pick image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 80,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  // Show image picker options
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Validate player number
  bool _validatePlayerNumber(int number, String teamId, String? currentPlayerId) {
    if (number <= 0) return false;

    List<Player> teamPlayers = teamId == widget.team1.id ? _team1Players : _team2Players;

    // Check if number already exists (exclude current player if editing)
    return !teamPlayers.any((player) =>
    player.number == number && player.id != currentPlayerId);
  }

  // Start adding new player
  void _startAddingPlayer(String teamId) {
    setState(() {
      _isAddingPlayer = true;
      _selectedPlayer = null;
      _selectedImage = null;
      _currentEditingTeamId = teamId; // Store the team ID being edited
      _nameController.clear();
      _numberController.clear();
    });
  }

  // Start editing existing player
  void _startEditingPlayer(Player player) {
    // Find which team this player belongs to
    String teamId;
    if (_team1Players.any((p) => p.id == player.id)) {
      teamId = widget.team1.id;
    } else {
      teamId = widget.team2.id;
    }

    setState(() {
      _selectedPlayer = player;
      _isAddingPlayer = false;
      _selectedImage = null;
      _currentEditingTeamId = teamId; // Store the team ID being edited
      _nameController.text = player.name;
      _numberController.text = player.number.toString();
    });
  }

  // Save player (add or update)
  Future<void> _savePlayer() async {
    final name = _nameController.text.trim();
    final numberText = _numberController.text.trim();

    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Player name cannot be empty')),
        );
      }
      return;
    }

    final number = int.tryParse(numberText);
    if (number == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid number')),
        );
      }
      return;
    }

    // Use the stored team ID instead of playerModel.currentTeamId
    if (_currentEditingTeamId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No team selected')),
        );
      }
      return;
    }

    // Validate player number
    if (!_validatePlayerNumber(number, _currentEditingTeamId!, _selectedPlayer?.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Player number must be greater than 0 and unique within the team')),
        );
      }
      return;
    }

    try {
      // Set the correct team context for the operation
      await playerModel.setCurrentTeamAndMatch(widget.matchId, _currentEditingTeamId!);

      String? base64Image;
      if (_selectedImage != null) {
        base64Image = await _convertImageToBase64(_selectedImage!);
      }

      if (_isAddingPlayer) {
        // Add new player
        Player newPlayer = Player(
          number: number,
          name: name,
          profileURL: base64Image,
        );
        await playerModel.add(newPlayer);
      } else if (_selectedPlayer != null) {
        // Update existing player
        _selectedPlayer!.name = name;
        _selectedPlayer!.number = number;
        if (base64Image != null) {
          _selectedPlayer!.profileURL = base64Image;
        }
        await playerModel.updateItem(_selectedPlayer!.id, _selectedPlayer!);
      }

      // Reload teams data
      await _loadBothTeams();

      // Reset state
      if (mounted) {
        setState(() {
          _selectedPlayer = null;
          _isAddingPlayer = false;
          _selectedImage = null;
          _currentEditingTeamId = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isAddingPlayer ? 'Player added successfully' : 'Player updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving player: $e')),
        );
      }
    }
  }

  // Cancel editing
  void _cancelEditing() {
    setState(() {
      _selectedPlayer = null;
      _isAddingPlayer = false;
      _selectedImage = null;
      _currentEditingTeamId = null;
      _nameController.clear();
      _numberController.clear();
    });
  }

  // validate count of player in each team then start the match (navigate to StatsRecorder)
  void _startMatch() {
    if (_team1Players.length >= 2 && _team2Players.length >= 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StatsRecorder(
            matchId: widget.matchId,
            team1: widget.team1,
            team2: widget.team2,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 players are required for each team')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Player Management",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.lightBlueAccent,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: (_selectedPlayer != null || _isAddingPlayer)
              ? _buildPlayerEditor()
              : Column(
            children: [
              _buildTeamSection(
                widget.team1,
                _team1Players,
                _expandedTeamId == widget.team1.id,
                    () => _toggleTeamExpansion(widget.team1.id),
              ),
              const SizedBox(height: 20),
              _buildTeamSection(
                widget.team2,
                _team2Players,
                _expandedTeamId == widget.team2.id,
                    () => _toggleTeamExpansion(widget.team2.id),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to StateRecorder
                      _startMatch();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Start Match',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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

  // Toggle team expansion (only one team can be expanded at a time)
  void _toggleTeamExpansion(String teamId) {
    setState(() {
      _expandedTeamId = _expandedTeamId == teamId ? null : teamId;
    });
  }

  Widget _buildTeamSection(Team team, List<Player> players, bool expanded, VoidCallback toggle) {
    final displayPlayers = expanded ? players : players.take(2).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: toggle,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    team.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Show players with swipe-to-delete functionality
          ...displayPlayers.map((player) => Dismissible(
            key: Key(player.id), // Unique key for each player
            direction: DismissDirection.horizontal, // Allow swiping left or right
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20.0),
              color: Colors.red,
              child: const Row(
                children: [
                  Icon(
                    Icons.delete,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20.0),
              color: Colors.red,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.delete,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            confirmDismiss: (direction) async {
              // Show confirmation dialog before deleting
              return await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Confirm Delete"),
                    content: Text("Are you sure you want to delete player '${player.name}' (#${player.number})?"),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text(
                          "Delete",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
            onDismissed: (direction) async {
              try {
                // Determine which team this player belongs to and set the correct context
                String teamId;
                if (_team1Players.any((p) => p.id == player.id)) {
                  teamId = widget.team1.id;
                } else {
                  teamId = widget.team2.id;
                }

                // Set the correct team context for the delete operation
                await playerModel.setCurrentTeamAndMatch(widget.matchId, teamId);

                // Delete the player from the database
                await playerModel.delete(player.id);

                // Reload both teams data to refresh the UI
                await _loadBothTeams();

                //  confirm deletion
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Player '${player.name}' (#${player.number}) deleted"),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                // Handle any errors during deletion
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error deleting player: $e"),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );

                  // Reload teams to ensure UI is in sync with database
                  await _loadBothTeams();
                }
              }
            },
            child: ListTile(
              onTap: () => _startEditingPlayer(player),
              leading: _buildProfileImage(player.profileURL, 25),
              title: Text('${player.number} - ${player.name}'),
              contentPadding: EdgeInsets.zero,
            ),
          )),
          // Show add player button only when expanded
          if (expanded) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _startAddingPlayer(team.id),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Add Player',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerEditor() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Card(
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                _isAddingPlayer ? 'Add New Player' : 'Edit Player',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _showImagePickerOptions,
                child: Stack(
                  children: [
                    // Show selected image if available, otherwise show current profile
                    _selectedImage != null
                        ? CircleAvatar(
                      backgroundImage: FileImage(_selectedImage!),
                      radius: 40,
                    )
                        : _buildProfileImage(_selectedPlayer?.profileURL, 40),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.lightBlueAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Player Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _numberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Player Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _savePlayer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: Text(
                        _isAddingPlayer ? 'Add Player' : 'Save Changes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: TextButton(
                      onPressed: _cancelEditing,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}