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

import 'stats_compare.dart';

enum ViewMode { summary, detail }

class ViewStats extends StatefulWidget {
  final String matchId;
  final Team team1;
  final Team team2;
  final bool isOnGoing;
  final int secondsElapsed;
  final int quarterNum;

  const ViewStats({
    super.key,
    required this.matchId,
    required this.team1,
    required this.team2,
    required this.isOnGoing,
    required this.secondsElapsed,
    required this.quarterNum,
  });

  @override
  State<ViewStats> createState() => _ViewStatsState();
}

class _ViewStatsState extends State<ViewStats> {
  late match_action.ActionModel actionModel;
  late PlayerModel playerModel;

  late Timer _timer;
  late int _currentSecondsElapsed;

  // Store players for both teams
  List<Player> _team1Players = [];
  List<Player> _team2Players = [];

  // Store actions
  List<match_action.Action> _allActions = [];

  // Changed to nullable to "All"
  match_action.Quarter? selectedQuarter = match_action.Quarter.first;
  ViewMode selectedMode = ViewMode.summary;

  // Detail view filters
  String? selectedTeamFilter;
  String playerNumberFilter = '';
  String playerNameFilter = '';

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

    // Safe after build: update provider state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      actionModel.setCurrentMatch(widget.matchId);
      actionModel.setCurrentMatch(widget.matchId);
      _loadPlayers();
      _loadActions();
    });
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

  Future<void> _loadActions() async {
    try {
      // load actions
      await actionModel.setCurrentMatch(widget.matchId);
      _allActions = List.from(actionModel.items);

      // Only call setState if the widget is still mounted
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading actions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading actions: $e')),
        );
      }
    }
  }

  // load team stats - updated to handle null quarter (All)
  String _loadTeamStats(String teamId) {
    int numGoals = actionModel.getActions(teamID: teamId, quarter: selectedQuarter, actionType: match_action.ActionType.goal).length;
    int numBehinds = actionModel.getActions(teamID: teamId, quarter: selectedQuarter, actionType: match_action.ActionType.behind).length;
    int total = numGoals * 6 + numBehinds;

    return "$numGoals . $numBehinds . ($total)";
  }

  // load team action count - updated to handle null quarter (All)
  int _loadTeamActionCount(String teamId, match_action.ActionType actionType) {
    return actionModel.getActions(teamID: teamId, quarter: selectedQuarter, actionType: actionType).length;
  }

  // load player stats - updated to handle null quarter (All)
  String _loadPlayerStats(String playerId) {
    int numGoals = actionModel.getActions(playerID: playerId, quarter: selectedQuarter, actionType: match_action.ActionType.goal).length;
    int numBehinds = actionModel.getActions(playerID: playerId, quarter: selectedQuarter, actionType: match_action.ActionType.behind).length;
    int total = numGoals * 6 + numBehinds;

    return "$numGoals . $numBehinds . ($total)";
  }

  // load player action count - updated to handle null quarter (All)
  int _loadPlayerActionCount(String playerId, match_action.ActionType actionType) {
    return actionModel.getActions(playerID: playerId, quarter: selectedQuarter, actionType: actionType).length;
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

  Widget modeSelection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedMode = ViewMode.summary),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selectedMode == ViewMode.summary ? Colors.lightBlueAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: Text(
                    'Summary',
                    style: TextStyle(
                      color: selectedMode == ViewMode.summary ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedMode = ViewMode.detail),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selectedMode == ViewMode.detail ? Colors.lightBlueAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: Text(
                    'Detail',
                    style: TextStyle(
                      color: selectedMode == ViewMode.detail ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
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

  Widget summaryView() {
    if (selectedMode != ViewMode.summary) return const SizedBox.shrink();

    return Expanded(
      child: Column(
        children: [
          teamStats(),
          addToCompare(),
        ],
      ),
    );
  }

  Widget teamStats() {
    return Expanded(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Team Statistics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // Team 1 Stats
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            widget.team1.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _loadTeamStats(widget.team1.id),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          ...match_action.ActionType.values.map((actionType) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    actionType.name.toUpperCase(),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  Text(
                                    _loadTeamActionCount(widget.team1.id, actionType).toString(),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
                // Team 2 Stats
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            widget.team2.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _loadTeamStats(widget.team2.id),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          ...match_action.ActionType.values.map((actionType) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    actionType.name.toUpperCase(),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  Text(
                                    _loadTeamActionCount(widget.team2.id, actionType).toString(),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
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

  Widget detailView() {
    if (selectedMode != ViewMode.detail) return const SizedBox.shrink();

    return Expanded(
      child: Column(
        children: [
          _buildFilters(),
          Expanded(child: playerStats()),
          addToCompare(),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Team filter
            Row(
              children: [
                const Text('Team: '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: selectedTeamFilter,
                  hint: const Text('All Teams'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Teams'),
                    ),
                    DropdownMenuItem<String>(
                      value: widget.team1.id,
                      child: Text(widget.team1.name),
                    ),
                    DropdownMenuItem<String>(
                      value: widget.team2.id,
                      child: Text(widget.team2.name),
                    ),
                  ],
                  onChanged: (value) => setState(() => selectedTeamFilter = value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Player number filter
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search by Player Number',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (value) => setState(() => playerNumberFilter = value),
            ),
            const SizedBox(height: 8),
            // Player name filter
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search by Player Name',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (value) => setState(() => playerNameFilter = value),
            ),
          ],
        ),
      ),
    );
  }

  // Fixed filtering method - now synchronous and doesn't call async methods during build
  List<Player> _getFilteredPlayers() {
    List<Player> filteredPlayers = [..._team1Players, ..._team2Players];

    // Apply team filter
    if (selectedTeamFilter != null) {
      if (selectedTeamFilter == widget.team1.id) {
        filteredPlayers = List<Player>.from(_team1Players);
      } else if (selectedTeamFilter == widget.team2.id) {
        filteredPlayers = List<Player>.from(_team2Players);
      }
    }

    // Apply number filter
    if (playerNumberFilter.isNotEmpty) {
      filteredPlayers = filteredPlayers.where((player) =>
          player.number.toString().contains(playerNumberFilter)).toList();
    }

    // Apply name filter
    if (playerNameFilter.isNotEmpty) {
      filteredPlayers = filteredPlayers.where((player) =>
          player.name.toLowerCase().contains(playerNameFilter.toLowerCase())).toList();
    }

    return filteredPlayers;
  }

  Widget playerStats() {
    // Check if players are still loading
    if (_team1Players.isEmpty && _team2Players.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredPlayers = _getFilteredPlayers();

    return ListView.builder(
      itemCount: filteredPlayers.length,
      itemBuilder: (context, index) {
        final player = filteredPlayers[index];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildProfileImage(player.profileURL, 25),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${player.name} (#${player.number})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: ${_loadPlayerStats(player.id)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: match_action.ActionType.values.map((actionType) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${actionType.name.toUpperCase()}: ',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            _loadPlayerActionCount(player.id, actionType).toString(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget addToCompare() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: () {
          // Navigate to StatsCompare
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CompareStats(
                matchId: widget.matchId,
                team1: widget.team1,
                team2: widget.team2,
                isOnGoing: widget.isOnGoing,
                secondsElapsed: _currentSecondsElapsed,
                quarterNum: widget.quarterNum,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightBlueAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        ),
        child: const Text('Add to Compare'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "View Stats",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [shareButton()],
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
              modeSelection(),
              quarterSelection(),
              selectedMode == ViewMode.summary ? summaryView() : detailView(),
            ],
          ),
        ),
      ),
    );
  }
}