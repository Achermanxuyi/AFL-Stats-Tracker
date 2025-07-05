import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'Data/team.dart';
import 'Data/match.dart';
import 'Data/player.dart';

import 'player_management.dart';


class TeamManagement extends StatefulWidget {
  const TeamManagement({super.key});

  @override
  State<TeamManagement> createState() => _TeamManagementState();
}

class _TeamManagementState extends State<TeamManagement> {
  final TextEditingController _team1Controller = TextEditingController();
  final TextEditingController _team2Controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;

  @override
  void dispose() {
    _team1Controller.dispose();
    _team2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Team Management",
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team 1 input
                _buildTeamInput(
                  title: 'Team 1',
                  controller: _team1Controller,
                  hintText: 'Enter Team 1 Name',
                ),

                const SizedBox(height: 40),

                // Team 2 input
                _buildTeamInput(
                  title: 'Team 2',
                  controller: _team2Controller,
                  hintText: 'Enter Team 2 Name',
                ),

                const SizedBox(height: 40),

                // save button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Consumer3<MatchModel, TeamModel, PlayerModel>(
                    builder: (context, matchModel, teamModel, playerModel, child) {
                      return ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () => _createMatchAndTeams(matchModel, teamModel, playerModel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 3,
                        ),
                        child: _isSaving
                            ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('Saving...'),
                          ],
                        )
                            : const Text(
                          'Save Teams & Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamInput({
    required String title,
    required TextEditingController controller,
    required String hintText
  }) {
    return Container(
      padding: const EdgeInsets.all(20.0),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
              controller: controller,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                hintText: hintText,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a team name';
                }
                return null;
              }
          )
        ],
      ),
    );
  }

  Future<void> _createMatchAndTeams(MatchModel matchModel, TeamModel teamModel, PlayerModel playerModel) async {
    if (!_formKey.currentState!.validate()) {
      return ;
    }

    // check if team names are different
    if (_team1Controller.text.trim().toLowerCase() == _team2Controller.text.trim().toLowerCase()) {
      _showErrorDialog('Team names must be different');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      Match newMatch = Match(matchDate: DateTime.now());
      await matchModel.add(newMatch);
      String matchId = ' ';
      if (matchModel.items.isNotEmpty) {
        matchId = matchModel.items.first.id;
      }

      // debug info
      if (matchId.isEmpty) {
        throw Exception('Failed to create match');
      }
      teamModel.currentMatchId = matchId;

      Team team1 = Team(name: _team1Controller.text.trim());
      await teamModel.add(team1);
      Team team2 = Team(name: _team2Controller.text.trim());
      await teamModel.add(team2);


      final actualTeam1 = teamModel.items.firstWhere((t) => t.name == _team1Controller.text.trim(), orElse: () => throw Exception('Team1 not found'));
      final actualTeam2 = teamModel.items.firstWhere((t) => t.name == _team2Controller.text.trim(), orElse: () => throw Exception('Team2 not found'));

      await _addDefaultPlayer(playerModel, matchId, actualTeam1.id);
      await _addDefaultPlayer(playerModel, matchId, actualTeam2.id);


      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerManagement(
              matchId: matchId,
              team1: actualTeam1,
              team2: actualTeam2,
            ),
          ),
        );
      }
    } catch(e) {
      _showErrorDialog('Failed to save teams: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _addDefaultPlayer(PlayerModel playerModel, String matchId, String teamId) async {
    playerModel.currentMatchId = matchId;
    playerModel.currentTeamId = teamId;

    Player player = Player(number: 0, name: 'player name', profileURL: ' ');

    await playerModel.add(player);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
