import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Player
{
  late String id;
  int number;
  String name;
  String? profileURL;

  Player({
    required this.number,
    required this.name,
    this.profileURL
  });

  Player.fromJson(Map<String, dynamic> json, this.id)
      :
        number = json['number'],
        name = json['name'],
        profileURL = json['profileURL'];

  Map<String, dynamic> toJson() => {
    'number': number,
    'name': name,
    'profileURL': profileURL,
  };
}

class PlayerModel extends ChangeNotifier {
  final List<Player> items = [];

  String? currentMatchId;
  String? currentTeamId;

  bool loading = false;

  PlayerModel({this.currentMatchId, this.currentTeamId});

  CollectionReference getPlayersCollection(String matchId, String teamId) {
    return FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .collection('teams')
        .doc(teamId)
        .collection('players');
  }

  Future add(Player item) async {
    if (currentMatchId == null || currentTeamId == null) {
      throw Exception('No Match or Team Found');
    }

    loading = true;
    update();

    await getPlayersCollection(currentMatchId!, currentTeamId!).add(item.toJson());
  }

  Future updateItem(String playerId, Player item) async {
    if (currentMatchId == null || currentTeamId == null) {
      throw Exception('No Match or Team Found');
    }

    loading = true;
    update();

    await getPlayersCollection(currentMatchId!, currentTeamId!).doc(playerId).set(item.toJson());

    //refresh the db for this match and team
    await fetch();
  }

  Future delete(String playerId) async {
    if (currentMatchId == null || currentTeamId == null) {
      throw Exception('No Match or Team Found');
    }

    loading = true;
    update();

    await getPlayersCollection(currentMatchId!, currentTeamId!).doc(playerId).delete();

    await fetch();
  }

  void update() {
    notifyListeners();
  }

  Future fetch() async {
    if (currentMatchId == null || currentTeamId == null) {
      throw Exception('No Match or Team Found');
    }

    await fetchPlayers(currentMatchId!, currentTeamId!);
  }

  Future fetchPlayers(String matchId, String teamId) async {
    items.clear();

    loading = true;
    notifyListeners();

    var querySnapshot = await getPlayersCollection(matchId, teamId)
        .orderBy('number', descending: false)
        .get();

    for (var doc in querySnapshot.docs) {
      var player = Player.fromJson(doc.data()! as Map<String, dynamic>, doc.id);
      items.add(player);
    }

    await Future.delayed(const Duration(microseconds: 5));

    loading = false;
    update();
  }

  Future setCurrentTeamAndMatch(String matchId, String teamId) async {
    currentMatchId = matchId;
    currentTeamId = teamId;
    await fetchPlayers(matchId, teamId);
  }

  Player? get(String? id) {
    if (id == null) return null;
    return items.firstWhere((player) => player.id == id);
  }

}