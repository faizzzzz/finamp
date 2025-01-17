import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';

import '../models/FinampModels.dart';
import '../services/FinampSettingsHelper.dart';
import '../services/AudioServiceHelper.dart';
import '../services/FinampUserHelper.dart';
import '../components/MusicScreen/MusicScreenTabView.dart';
import '../components/MusicScreen/MusicScreenDrawer.dart';
import '../components/MusicScreen/SortByMenuButton.dart';
import '../components/MusicScreen/SortOrderButton.dart';
import '../components/NowPlayingBar.dart';
import '../components/errorSnackbar.dart';
import '../services/JellyfinApiData.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({Key? key}) : super(key: key);

  static const routeName = "/music";

  @override
  _MusicScreenState createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen>
    with TickerProviderStateMixin {
  bool isSearching = false;
  bool _showShuffleFab = false;
  TextEditingController textEditingController = TextEditingController();
  String? searchQuery;
  final _musicScreenLogger = Logger("MusicScreen");

  TabController? _tabController;

  final _audioServiceHelper = GetIt.instance<AudioServiceHelper>();
  final _finampUserHelper = GetIt.instance<FinampUserHelper>();
  final _jellyfinApiData = GetIt.instance<JellyfinApiData>();

  void _stopSearching() {
    setState(() {
      textEditingController.clear();
      searchQuery = null;
      isSearching = false;
    });
  }

  void _tabIndexCallback() {
    var tabKey = FinampSettingsHelper.finampSettings.showTabs.entries
        .where((element) => element.value)
        .elementAt(_tabController!.index)
        .key;
    if (_tabController != null &&
        (tabKey == TabContentType.songs || tabKey == TabContentType.artists)) {
      setState(() {
        _showShuffleFab = true;
      });
    } else {
      if (_showShuffleFab) {
        setState(() {
          _showShuffleFab = false;
        });
      }
    }
  }

  void _buildTabController() {
    _tabController?.removeListener(_tabIndexCallback);

    _tabController = TabController(
      length: FinampSettingsHelper.finampSettings.showTabs.entries
          .where((element) => element.value)
          .length,
      vsync: this,
    );

    _tabController!.addListener(_tabIndexCallback);
  }

  @override
  void initState() {
    super.initState();
    _buildTabController();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<FinampUser>>(
      valueListenable: _finampUserHelper.finampUsersListenable,
      builder: (context, value, _) {
        return ValueListenableBuilder<Box<FinampSettings>>(
          valueListenable: FinampSettingsHelper.finampSettingsListener,
          builder: (context, value, _) {
            final finampSettings = value.get("FinampSettings");

            if (finampSettings!.showTabs.entries
                    .where((element) => element.value)
                    .length !=
                _tabController?.length) {
              _musicScreenLogger.info(
                  "Rebuilding MusicScreen tab controller (${finampSettings.showTabs.entries.where((element) => element.value).length} != ${_tabController?.length})");
              _buildTabController();
            }

            return WillPopScope(
              onWillPop: () async {
                if (isSearching) {
                  _stopSearching();
                  return false;
                } else {
                  return true;
                }
              },
              child: Scaffold(
                appBar: AppBar(
                  title: isSearching
                      ? TextField(
                          controller: textEditingController,
                          autofocus: true,
                          onChanged: (value) => setState(() {
                            searchQuery = value;
                          }),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "Search",
                          ),
                        )
                      : Text(_finampUserHelper.currentUser?.currentView?.name ??
                          "Music"),
                  bottom: TabBar(
                    controller: _tabController,
                    tabs: finampSettings.showTabs.entries
                        .where((element) => element.value)
                        .map((e) => Tab(text: e.key.toString().toUpperCase()))
                        .toList(),
                    isScrollable: true,
                  ),
                  leading: isSearching
                      ? BackButton(
                          onPressed: () => _stopSearching(),
                        )
                      : null,
                  actions: isSearching
                      ? [
                          IconButton(
                            icon: Icon(
                              Icons.cancel,
                              color: Theme.of(context).iconTheme.color,
                            ),
                            onPressed: () => setState(() {
                              textEditingController.clear();
                              searchQuery = null;
                            }),
                            tooltip: "Clear",
                          )
                        ]
                      : [
                          const SortOrderButton(),
                          const SortByMenuButton(),
                          IconButton(
                            icon: finampSettings.isFavourite
                                ? const Icon(Icons.star)
                                : const Icon(Icons.star_outline),
                            onPressed: finampSettings.isOffline
                                ? null
                                : () => FinampSettingsHelper.setIsFavourite(
                                    !finampSettings.isFavourite),
                            tooltip: "Favourites",
                          ),
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () => setState(() {
                              isSearching = true;
                            }),
                            tooltip: "Search",
                          ),
                        ],
                ),
                bottomNavigationBar: const NowPlayingBar(),
                drawer: const MusicScreenDrawer(),
                floatingActionButton: _tabController!.index ==
                    finampSettings.showTabs.entries
                        .where((element) => element.value)
                        .map((e) => e.key)
                        .toList()
                        .indexOf(TabContentType.songs)
                    ? FloatingActionButton(
                  child: const Icon(Icons.shuffle),
                  tooltip: "Shuffle all",
                  onPressed: () async {
                    try {
                      await _audioServiceHelper.shuffleAll(
                          FinampSettingsHelper
                              .finampSettings.isFavourite);
                    } catch (e) {
                      errorSnackbar(e, context);
                    }
                  },
                )
                    : _tabController!.index ==
                    finampSettings.showTabs.entries
                        .where((element) => element.value)
                        .map((e) => e.key)
                        .toList()
                        .indexOf(TabContentType.artists)
                    ? FloatingActionButton(
                    child: const Icon(Icons.explore),
                    tooltip: "Start Mix",
                    onPressed: () async {
                      try {
                        if (_jellyfinApiData.selectedMixArtistsIds.isEmpty){
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text("Long press on an artist to add or remove them from the mix builder before starting a mix")));
                        } else {
                          await _audioServiceHelper
                              .startInstantMixForArtists(
                              _jellyfinApiData.selectedMixArtistsIds);
                        }
                      } catch (e) {
                        errorSnackbar(e, context);
                      }
                    })
                    : null,
                body: TabBarView(
                  controller: _tabController,
                  children: finampSettings.showTabs.entries
                      .where((element) => element.value)
                      .map((e) => MusicScreenTabView(
                            tabContentType: e.key,
                            searchTerm: searchQuery,
                            isFavourite: finampSettings.isFavourite,
                            sortBy: finampSettings.sortBy,
                            sortOrder: finampSettings.sortOrder,
                            view: _finampUserHelper.currentUser?.currentView,
                          ))
                      .toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
