import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'Data/match.dart';
import 'Data/team.dart';
import 'Data/player.dart';
import 'Data/action.dart' as match_action;

import 'stats_recorder.dart';


class CompareStats extends StatefulWidget {
  final String matchId;
  final Team team1;
  final Team team2;
  final bool isOnGoing;
  final int secondsElapsed;
  final int quarterNum;

  const CompareStats({
    super.key,
    required this.matchId,
    required this.team1,
    required this.team2,
    required this.isOnGoing,
    required this.secondsElapsed,
    required this.quarterNum,
  });

  @override
  State<CompareStats> createState() => _CompareStatsState();
}

class _CompareStatsState extends State<CompareStats> {
  late match_action.ActionModel actionModel;
  late PlayerModel playerModel;

  late Timer _timer;
  late int _currentSecondsElapsed;

  // Store players for both teams
  List<Player> _team1Players = [];
  List<Player> _team2Players = [];

  String selectedTeam1Id = '';
  Player? selectedPlayer1;

  String selectedTeam2Id = '';
  Player? selectedPlayer2;

  // Changed to nullable to "All"
  match_action.Quarter? selectedQuarter = match_action.Quarter.first;

  @override
  void initState() {
    super.initState();
    actionModel = Provider.of<match_action.ActionModel>(context, listen: false);
    playerModel = Provider.of<PlayerModel>(context, listen: false);
    _currentSecondsElapsed = widget.secondsElapsed;

    // Start timer only if match is ongoing
    if (widget.isOnGoing) {
      _startTimer();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      actionModel.setCurrentMatch(widget.matchId);
      _loadPlayers();
    });


    selectedTeam1Id = widget.team1.id;
    selectedTeam2Id = widget.team2.id;
  }

  @override
  void dispose() {
    if (widget.isOnGoing) {
      _timer.cancel();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentSecondsElapsed++;
        });
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  // Get quarter number from enum
  int _getQuarterNumber(match_action.Quarter quarter) {
    return quarter.value;
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

      // Set initial player selections
      if (_team1Players.isNotEmpty) {
        selectedPlayer1 = _team1Players.first;
      }
      if (_team2Players.isNotEmpty) {
        selectedPlayer2 = _team2Players.first;
      }

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

  Widget shareButton() {
    return IconButton(
      onPressed: () => _shareActions(),
      icon: const Icon(Icons.share),
      tooltip: 'Share Actions',
    );
  }

  void _shareActions() {
    String shareText = 'Match Actions:\n\n';
    shareText += '${widget.team1.name} vs ${widget.team2.name}\n';
    // shareText += selectedQuarter == null ? 'Quarter: All\n\n' : 'Quarter: ${_getQuarterNumber(selectedQuarter!)}\n\n';

    List<match_action.Action> quarterActions = actionModel.getActions(quarter: selectedQuarter);
    for (var action in quarterActions) {
      shareText += '${action.timestamp} - ${action.teamName} - ${action.playerName} - ${action.actionType.name} - ${action.quarter}\n';
    }

    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Actions copied to clipboard')),
    );
  }

  Widget quarterSelection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          // individual quarters
          ...match_action.Quarter.values.map((quarter) {
            int quarterNum = _getQuarterNumber(quarter);
            bool isEnabled = !widget.isOnGoing || quarterNum <= widget.quarterNum;

            return Expanded(
              child: GestureDetector(
                onTap: isEnabled ? () {
                  setState(() => selectedQuarter = quarter);
                } : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cannot select future quarters for ongoing match')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selectedQuarter == quarter ? Colors.lightBlueAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Center(
                    child: Text(
                      'Q$quarterNum',
                      style: TextStyle(
                        color: isEnabled ?
                        (selectedQuarter == quarter ? Colors.white : Colors.black) :
                        Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
          // All Quarter
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => selectedQuarter = null);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selectedQuarter == null ? Colors.lightBlueAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: Text(
                    'All',
                    style: TextStyle(
                      color: selectedQuarter == null ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
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

  Widget teamSelection(String selectedTeamId, Function(String) onTeamChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedTeamId,
          isExpanded: true,
          items: [
            DropdownMenuItem(
              value: widget.team1.id,
              child: Text(
                widget.team1.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            DropdownMenuItem(
              value: widget.team2.id,
              child: Text(
                widget.team2.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
          onChanged: (String? newValue) {
            if (newValue != null) {
              onTeamChanged(newValue);
            }
          },
        ),
      ),
    );
  }

  Widget playerSelection(String teamId, Player? selectedPlayer, Function(Player) onPlayerChanged) {
    List<Player> players = teamId == widget.team1.id ? _team1Players : _team2Players;

    if (players.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[100],
        ),
        child: const Text(
          'No players available',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Player>(
          value: selectedPlayer,
          isExpanded: true,
          items: players.map((Player player) {
            return DropdownMenuItem<Player>(
              value: player,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${player.name} (#${player.number})',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (Player? newValue) {
            if (newValue != null) {
              onPlayerChanged(newValue);
            }
          },
        ),
      ),
    );
  }

  Widget selectionPanel({
    required String selectedTeamId,
    required Player? selectedPlayer,
    required Function(String) onTeamChanged,
    required Function(Player) onPlayerChanged,
  }) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Team:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          teamSelection(selectedTeamId, onTeamChanged),
          const SizedBox(height: 12),
          Text(
            'Player:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          playerSelection(selectedTeamId, selectedPlayer, onPlayerChanged),
        ],
      ),
    );
  }

  String _loadPlayerStats(String playerId) {
    int numGoals = actionModel.getActions(playerID: playerId, quarter: selectedQuarter, actionType: match_action.ActionType.goal).length;
    int numBehinds = actionModel.getActions(playerID: playerId, quarter: selectedQuarter, actionType: match_action.ActionType.behind).length;
    int total = numGoals * 6 + numBehinds;

    return "$numGoals . $numBehinds . ($total)";
  }

  int _loadPlayerActionCount(String playerId, match_action.ActionType actionType) {
    return actionModel.getActions(playerID: playerId, quarter: selectedQuarter, actionType: actionType).length;
  }

  Widget playerStatsWidget(Player? player) {
    if (player == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No player selected',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    String basicStats = _loadPlayerStats(player.id);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          // Player header
          Row(
            children: [
              _buildProfileImage(player.profileURL, 25),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '#${player.number}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Basic stats (Goals . Behinds . Total)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.lightBlueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  basicStats,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.lightBlueAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Detailed action stats
          Column(
            children: match_action.ActionType.values.map((actionType) {
              int count = _loadPlayerActionCount(player.id, actionType);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      actionType.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count.toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget backToMatch() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: () {
          // Navigate to StatsCompare
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightBlueAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        ),
        child: const Text('Back to Match'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Compare Stats",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.lightBlueAccent,
        actions: [shareButton()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Match info and quarter selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      _formatTime(_currentSecondsElapsed),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                  Text(
                      '${widget.quarterNum}/4 Quarter',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
              quarterSelection(),

              // Selection panels
              Expanded(
                child: Column(
                  children: [
                    // Player selection row
                    Row(
                      children: [
                        Expanded(
                          child: selectionPanel(
                            selectedTeamId: selectedTeam1Id,
                            selectedPlayer: selectedPlayer1,
                            onTeamChanged: (String teamId) {
                              setState(() {
                                selectedTeam1Id = teamId;
                                List<Player> players = teamId == widget.team1.id ? _team1Players : _team2Players;
                                selectedPlayer1 = players.isNotEmpty ? players.first : null;
                              });
                            },
                            onPlayerChanged: (Player player) {
                              setState(() {
                                selectedPlayer1 = player;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: selectionPanel(
                            selectedTeamId: selectedTeam2Id,
                            selectedPlayer: selectedPlayer2,
                            onTeamChanged: (String teamId) {
                              setState(() {
                                selectedTeam2Id = teamId;
                                List<Player> players = teamId == widget.team1.id ? _team1Players : _team2Players;
                                selectedPlayer2 = players.isNotEmpty ? players.first : null;
                              });
                            },
                            onPlayerChanged: (Player player) {
                              setState(() {
                                selectedPlayer2 = player;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Player stats comparison
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: playerStatsWidget(selectedPlayer1)),
                          const SizedBox(width: 16),
                          Expanded(child: playerStatsWidget(selectedPlayer2)),
                        ],
                      ),
                    ),
                    if (widget.isOnGoing) backToMatch(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}