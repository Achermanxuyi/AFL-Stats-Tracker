import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum ActionType {
  kick,
  handball,
  mark,
  tackle,
  goal,
  behind;

  // Convert enum to string for Firestore
  String get value => name;

  // Create enum from string
  static ActionType fromString(String value) =>
      ActionType.values.firstWhere(
            (e) => e.name == value,
        orElse: () => throw ArgumentError('Invalid ActionType: $value'),
      );
}

enum Quarter {
  first,
  second,
  third,
  fourth;

  // Convert enum to int for Firestore
  int get value => index + 1;

  // Create enum from int
  static Quarter fromInt(int value) =>
      Quarter.values.firstWhere(
            (e) => e.index == value - 1,
        orElse: () => throw ArgumentError('Invalid Quarter: $value'),
      );
}

class Action {
  late String id;
  String timestamp;
  String teamID;
  String teamName;
  String playerID;
  String playerName;
  Quarter quarter;
  ActionType actionType;

  Action({
    required this.timestamp,
    required this.teamID,
    required this.teamName,
    required this.playerID,
    required this.playerName,
    required this.quarter,
    required this.actionType,
  });

  Action.fromJson(Map<String, dynamic> json, this.id)
      :
        timestamp = json['timestamp'],
        teamID = json['teamID'],
        teamName = json['teamName'],
        playerID = json['playerID'],
        playerName = json['playerName'],
        quarter = Quarter.fromInt(json['quarter']),
        actionType = ActionType.fromString(json['actionType']);

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'teamID': teamID,
    'teamName': teamName,
    'playerID': playerID,
    'playerName': playerName,
    'quarter': quarter.value,
    'actionType': actionType.value,
  };
}

class ActionModel extends ChangeNotifier {
  /// Internal, private state of the list.
  final List<Action> items = [];

  // track which match we are managing actions for
  String? currentMatchId;

  bool loading = false;

  // Flag to prevent concurrent fetch operations
  bool _isFetching = false;

  ActionModel({this.currentMatchId});

  CollectionReference getActionsCollection(String matchId) {
    return FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .collection('actions');
  }

  Future add(Action item) async {
    if (currentMatchId == null) {
      throw Exception('No Match Found');
    }

    loading = true;
    update();

    await getActionsCollection(currentMatchId!).add(item.toJson());

    // refresh the db for this match
    await fetch();
  }

  Future updateItem(String actionId, Action item) async {
    if (currentMatchId == null) {
      throw Exception('No Match Found');
    }

    loading = true;
    update();

    await getActionsCollection(currentMatchId!).doc(actionId).set(item.toJson());

    //refresh the db for this match
    await fetch();
  }

  Future delete(String actionId) async {
    if (currentMatchId == null) {
      throw Exception('No Match Found');
    }

    loading = true;
    update();

    await getActionsCollection(currentMatchId!).doc(actionId).delete();

    // refresh the db for this match
    await fetch();
  }

  // This call tells the widgets that are listening to this model to rebuild.
  void update() {
    notifyListeners();
  }

  Future fetch() async {
    if (currentMatchId == null) {
      throw Exception('No Match Found');
    }
    await fetchActions(currentMatchId!);
  }

  Future fetchActions(String matchId) async {
    // Prevent concurrent fetch operations
    if (_isFetching) {
      return;
    }

    _isFetching = true;

    try {
      //clear any existing data we have gotten previously, to avoid duplicate data
      items.clear();

      // indicate that we are loading
      loading = true;
      notifyListeners();

      // get all actions for this match, ordered by timestamp
      var querySnapshot = await getActionsCollection(matchId)
          .orderBy('timestamp', descending: false)
          .get();

      // Create a new temporary list to ensure clean data
      List<Action> newActions = [];

      // iterate over the actions and add them to the temporary list
      for (var doc in querySnapshot.docs) {
        var action = Action.fromJson(doc.data()! as Map<String, dynamic>, doc.id);
        newActions.add(action);
      }

      // Clear items again and add all new actions at once
      items.clear();
      items.addAll(newActions);

      await Future.delayed(const Duration(microseconds: 5));

      loading = false;
      update();
    } finally {
      _isFetching = false;
    }
  }

  // set the current match and fetch its actions - enhanced to ensure clean state
  Future setCurrentMatch(String matchId) async {
    // If we're already fetching for this match, wait for it to complete
    if (_isFetching && currentMatchId == matchId) {
      while (_isFetching) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return;
    }

    // Clear items immediately when switching matches
    if (currentMatchId != matchId) {
      items.clear();
      notifyListeners();
    }

    currentMatchId = matchId;
    await fetchActions(matchId);
  }

  Action? get(String? id) {
    if (id == null) return null;
    try {
      return items.firstWhere((action) => action.id == id);
    } catch (e) {
      return null;
    }
  }

  // Enhanced combinable filter method - this is the main filtering function (Claude)
  List<Action> getActions({
    String? playerID,
    String? teamID,
    Quarter? quarter,
    ActionType? actionType,
  }) {
    // Create a copy of items to avoid any reference issues
    List<Action> filteredActions = List<Action>.from(items);

    if (playerID != null) {
      filteredActions = filteredActions.where((action) => action.playerID == playerID).toList();
    }

    if (teamID != null) {
      filteredActions = filteredActions.where((action) => action.teamID == teamID).toList();
    }

    if (quarter != null) {
      filteredActions = filteredActions.where((action) => action.quarter == quarter).toList();
    }

    if (actionType != null) {
      filteredActions = filteredActions.where((action) => action.actionType == actionType).toList();
    }

    return filteredActions;
  }
}