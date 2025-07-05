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

class HistoryMatch extends StatefulWidget {
  const HistoryMatch({super.key});

  @override
  State<HistoryMatch> createState() => _HistoryMatchState();
}

class _HistoryMatchState extends State<HistoryMatch> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Calculate cumulative stats for a team up to a specific quarter
  Map<String, int> _calculateCumulativeStats(List<match_action.Action> actions, String teamId, match_action.Quarter upToQuarter) {
    int goals = 0;
    int behinds = 0;

    for (var action in actions) {
      if (action.teamID == teamId && action.quarter.index <= upToQuarter.index) {
        if (action.actionType == match_action.ActionType.goal) {
          goals++;
        } else if (action.actionType == match_action.ActionType.behind) {
          behinds++;
        }
      }
    }

    return {'goals': goals, 'behinds': behinds, 'total': goals * 6 + behinds};
  }

  // Filter matches based on search query
  Future<List<Match>> _getFilteredMatches(List<Match> matches) async {
    if (_searchQuery.isEmpty) {
      return matches;
    }

    List<Match> filteredMatches = [];
    var teamModel = TeamModel();

    for (var match in matches) {
      try {
        await teamModel.fetchTeams(match.id);

        // Check if any team name contains the search query
        bool matchFound = teamModel.items.any((team) =>
            team.name.toLowerCase().contains(_searchQuery)
        );

        if (matchFound) {
          filteredMatches.add(match);
        }
      } catch (e) {
        // If there's an error fetching teams, skip this match
        continue;
      }
    }

    return filteredMatches;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<MatchModel>(
        builder: (context, matchModel, child) {
          if (matchModel.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by team name...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

              // Match list
              Expanded(
                child: FutureBuilder<List<Match>>(
                  future: _getFilteredMatches(matchModel.items),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }

                    var filteredMatches = snapshot.data ?? [];

                    if (filteredMatches.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isEmpty ? 'No matches found' : 'No matches found for "$_searchQuery"',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filteredMatches.length,
                      itemBuilder: (context, index) {
                        var match = filteredMatches[index];
                        return _buildMatchCard(match);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMatchCard(Match match) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadMatchData(match.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard(match);
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorCard(match);
        }

        var data = snapshot.data!;
        var teams = data['teams'] as List<Team>;
        var actions = data['actions'] as List<match_action.Action>;

        return _buildCompleteMatchCard(match, teams, actions);
      },
    );
  }

  Future<Map<String, dynamic>> _loadMatchData(String matchId) async {
    var teamModel = TeamModel();
    var actionModel = match_action.ActionModel();

    // Fetch teams and actions concurrently
    await Future.wait([
      teamModel.fetchTeams(matchId),
      actionModel.fetchActions(matchId),
    ]);

    return {
      'teams': List<Team>.from(teamModel.items),
      'actions': List<match_action.Action>.from(actionModel.items),
    };
  }

  Widget _buildLoadingCard(Match match) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          _formatDate(match.matchDate),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Loading...'),
        trailing: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildErrorCard(Match match) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          _formatDate(match.matchDate),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Error loading match data'),
        onTap: () => _navigateToStats(context, match),
      ),
    );
  }


  Widget _buildCompleteMatchCard(Match match, List<Team> teams, List<match_action.Action> actions) {
    var team1 = teams[0];
    var team2 = teams[1];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _navigateToStats(context, match),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Match date
              Text(
                _formatDate(match.matchDate),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),

              // Team names
              Text(
                '${team1.name} VS ${team2.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),

              // Quarter by quarter scores
              ..._buildQuarterScores(actions, team1, team2),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildQuarterScores(List<match_action.Action> actions, Team team1, Team team2) {
    return match_action.Quarter.values.map((quarter) {
      var team1Stats = _calculateCumulativeStats(actions, team1.id, quarter);
      var team2Stats = _calculateCumulativeStats(actions, team2.id, quarter);

      String quarterLabel = quarter == match_action.Quarter.fourth ? 'Final' : 'Q${quarter.value}';

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            // Team 1 score
            Expanded(
              flex: 2,
              child: Text(
                '${team1Stats['goals']}.${team1Stats['behinds']} (${team1Stats['total']})',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),

            // Quarter label
            Expanded(
              flex: 1,
              child: Text(
                quarterLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),

            // Team 2 score
            Expanded(
              flex: 2,
              child: Text(
                '${team2Stats['goals']}.${team2Stats['behinds']} (${team2Stats['total']})',
                textAlign: TextAlign.right,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _navigateToStats(BuildContext context, Match match) async {
    // Set the current match in ActionModel and TeamModel before navigating
    var actionModel = Provider.of<match_action.ActionModel>(context, listen: false);
    var teamModel = Provider.of<TeamModel>(context, listen: false);

    // Set current match for both models
    teamModel.currentMatchId = match.id;
    await actionModel.setCurrentMatch(match.id);
    await teamModel.fetchTeams(match.id);

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ViewStats(
            matchId: match.id,
            team1: teamModel.items[0],
            team2: teamModel.items[1],
            isOnGoing: false,
            secondsElapsed: 0,
            quarterNum: 4,
          ),
        ),
      );
    }
  }
}