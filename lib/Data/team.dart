import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


class Team
{
  late String id;
  String name;

  Team({
    required this.name,
  });

  Team.fromJson(Map<String, dynamic> json, this.id)
      :
        name = json['name'];

  Map<String, dynamic> toJson() => {
    'name': name,
  };
}

class TeamModel extends ChangeNotifier {
  final List<Team> items = [];

  // track which match we are managing Teams for
  String? currentMatchId;

  bool loading = false;

  TeamModel({this.currentMatchId});

  CollectionReference getTeamsCollection(String matchId) {
    return FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .collection('teams');
  }

  Future add(Team item) async {
    if (currentMatchId == null) {
      throw Exception('No Match Found');
    }

    loading = true;
    update();

    await getTeamsCollection(currentMatchId!).add(item.toJson());

    await fetch();
  }

  Future updateItem(String teamId, Team item) async {
    if (currentMatchId == null) {
      throw Exception('No Match Found');
    }

    loading = true;
    update();

    await getTeamsCollection(currentMatchId!).doc(teamId).set(item.toJson());

    // refresh the db for this team
    await fetch();
  }

  Future delete(String teamId) async {
    loading = true;
    update();

    await getTeamsCollection(currentMatchId!).doc(teamId).delete();
  }



  void update() {
    notifyListeners();
  }

  Future fetch() async {
    if (currentMatchId == null) {
      throw Exception('No Match Found');
    }

    await fetchTeams(currentMatchId!);
  }

  Future fetchTeams(String matchId) async {
    //clear any existing data we have gotten previously, to avoid duplicate data
    items.clear();

    // indicate that we are loading
    loading = true;
    notifyListeners();

    // get all teams for current match
    var querySnapshot = await getTeamsCollection(matchId)
        .orderBy('name')
        .get();

    // iterate over the list and add them to the list
    for (var doc in querySnapshot.docs) {
      var team = Team.fromJson(doc.data()! as Map<String, dynamic>, doc.id);
      items.add(team);
    }

    await Future.delayed(const Duration(microseconds: 5));

    loading = false;
    update();
  }

  Team? get(String? id) {
    if (id == null) return null;
    return items.firstWhere((team) => team.id == id);
  }
}