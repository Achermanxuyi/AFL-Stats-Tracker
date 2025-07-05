import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Match
{
  late String id;
  DateTime matchDate;

  Match({required this.matchDate});

  Match.fromJson(Map<String, dynamic> json, this.id)
      :
        matchDate = (json['matchDate']as Timestamp).toDate();

  Map<String, dynamic> toJson() => {
    'matchDate': Timestamp.fromDate(matchDate)
  };

}

class MatchModel extends ChangeNotifier {
  final List<Match> items = [];

  CollectionReference matchesCollection = FirebaseFirestore.instance.collection('matches');

  bool loading = false;

  MatchModel() {
    fetch();
  }

  Future add(Match item) async {
    loading = true;
    update();

    await matchesCollection.add(item.toJson());

    // refresh the db
    await fetch();
  }

  Future updateItem(String id, Match item) async {
    loading = true;
    update();

    await matchesCollection.doc(id).set(item.toJson());

    // refresh the db
    await fetch();
  }

  Future delete(String id) async {
    loading = true;
    update();

    // refresh the db
    await fetch();
  }

  // This call tells the widgets that are listening to this model to rebuild.
  void update() {
    notifyListeners();
  }

  Future fetch() async {
    // clear any existing data we have gotten previously, to avoid duplicate data
    items.clear();

    // indicate that we are loading
    loading = true;
    notifyListeners(); //tell children to redraw, and they will see that the loading indicator is on

    // get all matches ordered by match date (most recent first)
    var querySnapshot = await matchesCollection.orderBy("matchDate", descending: true).get();

    // iterate over the matches and add them to the list
    for (var doc in querySnapshot.docs) {
      var match = Match.fromJson(doc.data()! as Map<String, dynamic>, doc.id);
      items.add(match);
    }

    //put this line in to artificially increase the load time, so we can see the loading indicator
    //comment this out when the delay becomes annoying
    await Future.delayed(const Duration(microseconds: 5));

    //we're done, no longer loading
    loading = false;
    update();
  }

  Match? get(String? id) {
    if (id == null) return null;
    return items.firstWhere((match) => match.id == id);
  }

  List<Match> getMatchesForDate(DateTime date) {
    return items.where((match) =>
    match.matchDate.year == date.year &&
        match.matchDate.month == date.month &&
        match.matchDate.day == date.day
    ).toList();
  }
}