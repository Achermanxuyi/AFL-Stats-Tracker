import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'Data/match.dart';
import 'Data/team.dart';
import 'Data/player.dart';
import 'Data/action.dart' as match_action;

import 'stats_viewer.dart';
import 'main.dart';

class StatsRecorder extends StatefulWidget {
  final String matchId;
  final Team team1;
  final Team team2;

  const StatsRecorder({
    super.key,
    required this.matchId,
    required this.team1,
    required this.team2,
  });

  @override
  State<StatsRecorder> createState() => _StatsRecorderState();
}

class _StatsRecorderState extends State<StatsRecorder> {
  late match_action.ActionModel actionModel;
  late PlayerModel playerModel;

  int currentQuarter = 1;
  late Timer _timer;
  int _secondsElapsed = 0;

  String selectedTeamId = '';
  Player? selectedPlayer;
  int selectedPlayerIndex = 0;
  match_action.Action? lastAction;

  // Store players for both teams
  List<Player> _team1Players = [];
  List<Player> _team2Players = [];

  @override
  void initState() {
    super.initState();
    actionModel = Provider.of<match_action.ActionModel>(context, listen: false);
    playerModel = Provider.of<PlayerModel>(context, listen: false);
    _startTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlayers();
      actionModel.setCurrentMatch(widget.matchId);
    });

    selectedTeamId = widget.team1.id;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _secondsElapsed++;
      });
    });
  }

  // Load players for both teams
  Future<void> _loadPlayers() async {
    try {
      // Load team 1 players
      await playerModel.setCurrentTeamAndMatch(widget.matchId, widget.team1.id);
      _team1Players = List.from(playerModel.items);

      // Load team 2 players
      await playerModel.setCurrentTeamAndMatch(widget.matchId, widget.team2.id);
      _team2Players = List.from(playerModel.items);

      _updateSelectedPlayer();

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

  // load team stats
  Future<String> _loadTeamStats(String teamId) async {
    int numGoals = actionModel.getActions(teamID: teamId, actionType: match_action.ActionType.goal).length;
    int numBehinds =  actionModel.getActions(teamID: teamId, actionType: match_action.ActionType.behind).length;
    int total = numGoals * 6 + numBehinds;

    return "$numGoals . $numBehinds . ($total)";
  }

  String _formatTime(int totalSeconds) {
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _recordAction(match_action.ActionType actionType) async {
    if (selectedPlayer == null) return;

    final action = match_action.Action(
      timestamp: _formatTime(_secondsElapsed),
      teamID: selectedTeamId,
      teamName: selectedTeamId == widget.team1.id ? widget.team1.name : widget.team2.name,
      playerID: selectedPlayer!.id,
      playerName: selectedPlayer!.name,
      quarter: match_action.Quarter.values[currentQuarter - 1],
      actionType: actionType,
    );

    await actionModel.add(action);
  }

  void _undoLastAction() async {
    if (actionModel.items.isEmpty) return;

    final lastAction = actionModel.items.last;
    await actionModel.delete(lastAction.id);
  }

  void _updateSelectedPlayer() {
    List<Player> currentPlayers = selectedTeamId == widget.team1.id
        ? _team1Players
        : _team2Players;

    if (currentPlayers.isNotEmpty && selectedPlayerIndex < currentPlayers.length) {
      selectedPlayer = currentPlayers[selectedPlayerIndex];
    } else if (currentPlayers.isNotEmpty) {
      selectedPlayerIndex = 0;
      selectedPlayer = currentPlayers[0];
    } else {
      selectedPlayer = null;
    }
  }

  // team selection
  Widget teamSelection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedTeamId = widget.team1.id;
                  selectedPlayerIndex = 0;
                  _updateSelectedPlayer();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selectedTeamId == widget.team1.id
                      ? Colors.lightBlueAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  widget.team1.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: selectedTeamId == widget.team1.id
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedTeamId = widget.team2.id;
                  selectedPlayerIndex = 0;
                  _updateSelectedPlayer();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selectedTeamId == widget.team2.id
                      ? Colors.lightBlueAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  widget.team2.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: selectedTeamId == widget.team2.id
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

  // Team Stats Widget
  Widget teamStats() {
    return FutureBuilder<List<String>>(
      future: Future.wait([
        _loadTeamStats(widget.team1.id),
        _loadTeamStats(widget.team2.id),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('Loading...', style: TextStyle(fontSize: 16)),
              Text('Loading...', style: TextStyle(fontSize: 16)),
            ],
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                snapshot.data![0],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const Text(
                'VS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Text(
                snapshot.data![1],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // player selection with number picker
  Widget playerSelection() {
    List<Player> currentPlayers = selectedTeamId == widget.team1.id
        ? _team1Players
        : _team2Players;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Player Profile
          _buildProfileImage(selectedPlayer?.profileURL, 30),

          const SizedBox(width: 16),

          // Player Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedPlayer?.name ?? 'No Player',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Player #${selectedPlayer?.number ?? '?'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Number Picker
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    if (selectedPlayerIndex < currentPlayers.length) {
                      setState(() {
                        selectedPlayerIndex++;
                        _updateSelectedPlayer();
                      });
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 30,
                    decoration: BoxDecoration(
                      color: selectedPlayerIndex < currentPlayers.length
                          ? Colors.grey[200]
                          : Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      color: selectedPlayerIndex < currentPlayers.length
                          ? Colors.black
                          : Colors.grey,
                    ),
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.symmetric(
                      horizontal: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${selectedPlayer?.number ?? '?'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (selectedPlayerIndex > 0) {
                      setState(() {
                        selectedPlayerIndex--;
                        _updateSelectedPlayer();
                      });
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 30,
                    decoration: BoxDecoration(
                      color: selectedPlayerIndex > 0
                          ? Colors.grey[200]
                          : Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: selectedPlayerIndex > 0
                          ? Colors.black
                          : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getButtonText(match_action.ActionType actionType) {
    switch (actionType) {
      case match_action.ActionType.kick:
        return 'Kick';
      case match_action.ActionType.handball:
        return 'Handball';
      case match_action.ActionType.mark:
        return 'Mark';
      case match_action.ActionType.tackle:
        return 'Tackle';
      case match_action.ActionType.goal:
        return 'Goal';
      case match_action.ActionType.behind:
        return 'Behind';
    }
  }

  bool _isActionEnabled(match_action.ActionType actionType) {
    if (selectedPlayer == null) return false;

    // get most recent action
    lastAction = actionModel.items.isNotEmpty ? actionModel.items.last : null;

    switch (actionType) {
      case match_action.ActionType.goal:
        return lastAction?.actionType == match_action.ActionType.kick;
      case match_action.ActionType.behind:
        return lastAction?.actionType == match_action.ActionType.kick ||
            lastAction?.actionType == match_action.ActionType.handball;
      default:
        return true;
    }
  }

  Color _getButtonColor(match_action.ActionType actionType) {
    switch (actionType) {
      case match_action.ActionType.goal:
      case match_action.ActionType.behind:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  // for goal and behind, give smaller size
  bool _isSmallButton(match_action.ActionType actionType) {
    return actionType == match_action.ActionType.goal ||
          actionType == match_action.ActionType.behind;
  }

  Widget _buildActionButton(match_action.ActionType actionType) {
    bool isEnabled = _isActionEnabled(actionType);
    bool isSmall = _isSmallButton(actionType);
    Color buttonColor = isEnabled ? _getButtonColor(actionType) : Colors.grey;

    if (isSmall) {
      return SizedBox(
        width: 100,
        child: ElevatedButton(
          onPressed: isEnabled ? () => _recordAction(actionType) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(_getButtonText(actionType), style: const TextStyle(fontSize: 14)),
        ),
      );
    } else {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ElevatedButton(
            onPressed: isEnabled ? () => _recordAction(actionType) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
            ),
            child: Text(_getButtonText(actionType), style: const TextStyle(fontSize: 16)),
          ),
        ),
      );
    }
  }

  // Build undo button with last action details
  Widget _buildUndoButton() {
    if (actionModel.items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Text(
          'No actions to undo',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final lastAction = actionModel.items.last;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _undoLastAction,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.undo, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'UNDO LAST ACTION',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lastAction.teamName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getButtonText(lastAction.actionType).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${lastAction.playerName} (#${selectedPlayer?.number})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        lastAction.timestamp,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Action recording buttons
  Widget actionButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          // First row: Kick, Handball
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(match_action.ActionType.kick),
              _buildActionButton(match_action.ActionType.handball),
            ],
          ),

          const SizedBox(height: 8),

          // Second row: Mark, Tackle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(match_action.ActionType.mark),
              _buildActionButton(match_action.ActionType.tackle),
            ],
          ),

          const SizedBox(height: 12),

          // Third row: Goal, Behind (smaller buttons)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(match_action.ActionType.goal),
              const SizedBox(width: 16),
              _buildActionButton(match_action.ActionType.behind),
            ],
          ),

          const SizedBox(height: 16),

          // Undo button - big button with last action details
          _buildUndoButton(),
        ],
      ),
    );
  }

  Widget viewStatsButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () {
          // Navigate to ViewStats
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ViewStats(
                matchId: widget.matchId,
                team1: widget.team1,
                team2: widget.team2,
                isOnGoing: true,
                secondsElapsed: _secondsElapsed,
                quarterNum: currentQuarter,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightBlueAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'View Stats',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Stats Recorder",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatTime(_secondsElapsed), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('$currentQuarter/4 Quarter', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton(
                    onPressed: () {
                      if (currentQuarter < 4) {
                        setState(() => currentQuarter++);
                      } else if (currentQuarter == 4) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) {
                            return const AFLStatsApp();
                          }
                        ));
                      }
                    },
                    child: const Text('Next'),
                  ),
                ],
              ),

              teamSelection(),

              teamStats(),

              playerSelection(),

              actionButtons(),

              const SizedBox(height: 16),

              viewStatsButton(),
            ],
          ),
        ),
      ),
    );
  }
}
