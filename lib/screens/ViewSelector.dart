import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../services/FinampUserHelper.dart';
import 'MusicScreen.dart';
import '../../services/JellyfinApiData.dart';
import '../../models/JellyfinModels.dart';
import '../../components/errorSnackbar.dart';

class ViewSelector extends StatefulWidget {
  const ViewSelector({Key? key}) : super(key: key);

  static const routeName = "/settings/views";

  @override
  _ViewSelectorState createState() => _ViewSelectorState();
}

class _ViewSelectorState extends State<ViewSelector> {
  final _jellyfinApiData = GetIt.instance<JellyfinApiData>();
  final _finampUserHelper = GetIt.instance<FinampUserHelper>();
  late Future<List<BaseItemDto>> viewListFuture;
  Map<BaseItemDto, bool> _views = {};

  @override
  void initState() {
    super.initState();
    viewListFuture = _jellyfinApiData.getViews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Music Libraries"),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.check),
        onPressed: _submitChoice,
      ),
      body: FutureBuilder<List<BaseItemDto>>(
        future: viewListFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data!.length == 0) {
              // If snapshot.data is empty, getMusicViews returned no music libraries. This means that the user doesn't have any music libraries.
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text("Could not find any libraries."),
                ),
              );
            } else {
              if (_views.isEmpty) {
                _views.addEntries(snapshot.data!
                    .where((element) => element.collectionType != "playlists")
                    .map((e) => MapEntry(e, e.collectionType == "music")));
              }

              // If only one music library is available and user doesn't have a
              // view saved (assuming setup is in progress), skip the selector.
              if (_views.values.where((element) => element == true).length ==
                      1 &&
                  _finampUserHelper.currentUser!.currentView == null)
                _submitChoice();

              return Scrollbar(
                child: ListView.builder(
                  itemCount: _views.length,
                  itemBuilder: (context, index) {
                    return CheckboxListTile(
                      value: _views.values.elementAt(index),
                      title: Text(
                          _views.keys.elementAt(index).name ?? "Unknown Name"),
                      onChanged: (value) {
                        setState(() {
                          _views[_views.keys.elementAt(index)] = value!;
                        });
                      },
                      // onTap: () async {
                      //   JellyfinApiData jellyfinApiData =
                      //       GetIt.instance<JellyfinApiData>();
                      //   try {
                      //     jellyfinApiData.saveView(snapshot.data![index],
                      //         jellyfinApiData.currentUser!.id);
                      //     Navigator.of(context)
                      //         .pushNamedAndRemoveUntil("/music", (route) => false);
                      //   } catch (e) {
                      //     errorSnackbar(e, context);
                      //   }
                      // },
                    );
                  },
                ),
              );
            }
          } else if (snapshot.hasError) {
            errorSnackbar(snapshot.error, context);
            // TODO: Let the user refresh the page
            return Text(
                "Something broke and I can't be bothered to make a refresh thing right now. The error was: ${snapshot.error}");
          } else {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
        },
      ),
    );
  }

  void _submitChoice() {
    if (_views.values.where((element) => element == true).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("A library is required.")));
    } else {
      try {
        _finampUserHelper.setCurrentUserViews(_views.entries
            .where((element) => element.value == true)
            .map((e) => e.key)
            .toList());
        // allow navigation to music screen while selector is being built
        Future.microtask(() => Navigator.of(context)
            .pushNamedAndRemoveUntil(MusicScreen.routeName, (route) => false));
      } catch (e) {
        errorSnackbar(e, context);
      }
    }
  }
}
